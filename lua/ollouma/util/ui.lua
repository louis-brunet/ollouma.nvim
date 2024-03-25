-- ---@enum OlloumaVerticalPosition
-- local OlloumaVerticalPosition = {
--     TOP = 'top',
--     BOTTOM = 'bottom',
-- }

---@class OlloumaSplitUiBufferCommand
---@field rhs string|fun():nil right-hand side of a user command mapping, vim command or lua function
---@field opts table

---@enum OlloumaSplitKind
local OlloumaSplitKind = {
    -- VERTICAL = 'vertical',
    -- HORIZONTAL = 'horizontal',
    TOP = 'top',
    BOTTOM = 'bottom',
    LEFT = 'left',
    RIGHT = 'right',
}

---@class OlloumaSplitUiConfig
---@field prompt_split OlloumaSplitKind
---@field output_split OlloumaSplitKind

---@class OlloumaSplitUiItem
---@field buffer integer|nil
---@field window integer|nil

---@class OlloumaSplitUi
---@field config OlloumaSplitUiConfig
---@field prompt OlloumaSplitUiItem
---@field output OlloumaSplitUiItem
---TODO: generic ui_items ?
local SplitUi = {}
SplitUi.__index = SplitUi

---@param config OlloumaSplitUiConfig
---@return OlloumaSplitUi
function SplitUi:new(config)
    ---@type OlloumaSplitUi
    local split_ui = {
        config = config or {},
        prompt = {
            buffer = nil,
            window = nil,
        },
        output = {
            buffer = nil,
            window = nil,
        },
    }

    return setmetatable(split_ui, self)
end

---@param model_name string
---@param commands table<string, OlloumaSplitUiBufferCommand>|nil
function SplitUi:open_prompt(model_name, commands)
    self.prompt = self.prompt or {}

    self:open_split(self.prompt, self.config.prompt_split, {
        set_current_window = true,
        commands = commands or {},
        buffer_name = 'PROMPT [' .. model_name .. ']',
    })
end

---@param model_name string
---@param commands table<string, OlloumaSplitUiBufferCommand>|nil
function SplitUi:open_output(model_name, commands)
    self.output = self.output or {}

    self:open_split(self.output, self.config.output_split, {
        set_current_window = false,
        commands = commands or {},
        buffer_name = 'OUTPUT [' .. model_name .. ']',
    })
end

---@param str string
function SplitUi:ouput_write(str)
    local util = require('ollouma.util')

    util.buf_append_string(self.output.buffer, str)

    if not self.output.window or not vim.api.nvim_win_is_valid(self.output.window) then
        return
    end

    -- if cursor is on second to last line, then
    -- move it to the last line
    local output_cursor = vim.api.nvim_win_get_cursor(self.output.window)
    local last_line_idx = vim.api.nvim_buf_line_count(self.output.buffer)

    if output_cursor[1] == last_line_idx - 1 then
        local last_line = vim.api.nvim_buf_get_lines(
            self.output.buffer,
            -2, -1, false
        )
        local last_column_idx = math.max(0, #last_line - 1)

        vim.api.nvim_win_set_cursor(
            self.output.window,
            { last_line_idx, last_column_idx }
        )
    end
end

function SplitUi:get_prompt_lines()
    return vim.api.nvim_buf_get_lines(self.prompt.buffer, 0, -1, false)
end

-- TODO: ---@private ?
--
---@param command_name string
---@param cmd OlloumaSplitUiBufferCommand
---@param ui_items OlloumaSplitUiItem[]
function SplitUi:create_user_command(command_name, cmd, ui_items)
    vim.validate({
        command_name = { command_name, { 'string' } },
        cmd_rhs = { cmd.rhs, { 'string', 'function' } },
        cmd_opts = { cmd.opts, { 'table', 'nil' } },
        ui_items = { ui_items, { 'table' } },
    })

    if #ui_items == 0 then
        error('expected at least 1 UI item, got 0')
    end

    for _, ui_item in ipairs(ui_items) do
        vim.validate({
            ui_item = { ui_item, { 'table' } },
            ui_item_buffer = { ui_item.buffer, { 'number' } },
        })

        vim.api.nvim_buf_create_user_command(
            ui_item.buffer,
            command_name,
            cmd.rhs,
            cmd.opts
        )
    end
end

---@private
---@class OlloumaSplitUiOpenOptions
---@field set_current_window boolean|nil
---@field commands table<string, OlloumaSplitUiBufferCommand>|nil
---@field buffer_name string|nil

---@private
---@param ui_item OlloumaSplitUiItem
---@param split_kind OlloumaSplitKind
---@param opts OlloumaSplitUiOpenOptions|nil
function SplitUi:open_split(ui_item, split_kind, opts)
    local log = require('ollouma.util.log')
    opts = opts or {}
    local current_window = vim.api.nvim_get_current_win()

    if ui_item.buffer == nil then
        ui_item.buffer = vim.api.nvim_create_buf(false, true)

        if opts.buffer_name then
            vim.validate({ buffer_name = { opts.buffer_name, 'string' } })

            ---@type string
            local buf_name = opts.buffer_name
            local index = 0

            ---@diagnostic disable-next-line: param-type-mismatch
            while vim.fn.bufexists(buf_name) ~= 0 do
                index = index + 1
                buf_name = opts.buffer_name .. '_' .. index
            end

            vim.api.nvim_buf_set_name(ui_item.buffer, buf_name)
        end
    end

    if ui_item.window == nil or not vim.api.nvim_win_is_valid(ui_item.window) then
        if split_kind == OlloumaSplitKind.LEFT then
            vim.cmd 'vsplit'
        elseif split_kind == OlloumaSplitKind.RIGHT then
            vim.cmd 'vsplit +wincmd\\ x|wincmd\\ l'
        elseif split_kind == OlloumaSplitKind.TOP then
            vim.cmd 'split'
        elseif split_kind == OlloumaSplitKind.BOTTOM then
            vim.cmd 'split +wincmd\\ x|wincmd\\ j'
        else
            error('invalid prompt_split value: ' .. vim.inspect(split_kind))
        end

        ui_item.window = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(ui_item.window, ui_item.buffer)
    end

    -- for some reason this needs to be after the window initialization or
    -- ftplugin configs don't work
    vim.api.nvim_buf_set_option(ui_item.buffer, 'ft', 'markdown')

    if opts.commands then
        for command_name, cmd in pairs(opts.commands) do
            log.trace("creating user command '" .. command_name .. "' for ui item: " .. vim.inspect(ui_item))
            self:create_user_command(command_name, cmd, { ui_item })
        end
    end

    if opts.set_current_window then
        ---@type integer
        current_window = ui_item.window
    end
    vim.api.nvim_set_current_win(current_window)
end

return { SplitUi = SplitUi, OlloumaSplitKind = OlloumaSplitKind }




--TODO:
--[[
WIP: TO DELETE? started to refactor (too early?) ui_items



-- ---@class OlloumaSplitUiConfig
-- ---@field prompt_split OlloumaSplitKind
-- ---@field output_split OlloumaSplitKind

---@class OlloumaSplitUiItem
---@field buffer integer|nil
---@field window integer|nil
---@field split_kind OlloumaSplitKind

---@class OlloumaSplitUi
-- ---@field config OlloumaSplitUiConfig
-- ---@field prompt OlloumaSplitUiItem
-- ---@field output OlloumaSplitUiItem
---@field ui_items table<string, OlloumaSplitUiItem>
local SplitUi = {}
SplitUi.__index = SplitUi

-- ---@param config OlloumaSplitUiConfig
---@param ui_item_split_kinds table<string, OlloumaSplitKind>
---@return OlloumaSplitUi
function SplitUi:new(ui_item_split_kinds)
-- function SplitUi:new(config, ui_item_names)
    ---@type OlloumaSplitUi
    local split_ui = {
        -- config = config or {},
        ui_items = {},
        -- prompt = {
        --     buffer = nil,
        --     window = nil,
        -- },
        -- output = {
        --     buffer = nil,
        --     window = nil,
        -- },
    }

    for ui_item_name, ui_item_kind in pairs(ui_item_split_kinds) do
        split_ui.ui_items[ui_item_name] = {
            buffer = nil,
            window = nil,
            split_kind = ui_item_kind,
        }
    end

    return setmetatable(split_ui, self)
end

function SplitUi:open_ui_item(ui_item_name)
    local ui_item = self.ui_items[ui_item_name]
    if not ui_item then
        error('unrecognized ui item name: ' .. ui_item_name)
    end

    self:open_split(ui_item, self.config.prompt_split, {
        set_current_window = true,
        commands = commands or {},
        buffer_name = 'PROMPT [' .. model_name .. ']',
    })
    -- self.ui_items[ui_item_name] = self.ui_items[ui_item_name] or {}
end

]]
