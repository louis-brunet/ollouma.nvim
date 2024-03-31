-- SplitUiItem

---@class OlloumaSplitUiItem
---@field display_name string
---@field split_kind OlloumaSplitKind
---@field buffer integer|nil
---@field window integer|nil
---@field buffer_commands OlloumaSplitUiBufferCommand[]
---@field buffer_keymaps OlloumaSplitUiBufferKeymap[]
local SplitUiItem = {}
SplitUiItem.__index = SplitUiItem

---@class OlloumaSplitUiItemConstructorOptions
---@field buffer_commands OlloumaSplitUiBufferCommand[]|nil
---@field buffer_keymaps OlloumaSplitUiBufferKeymap[]|nil

---@param display_name string
---@param split_kind OlloumaSplitKind
---@param opts OlloumaSplitUiItemConstructorOptions|nil
---@return OlloumaSplitUiItem
function SplitUiItem:new(display_name, split_kind, opts)
    opts = opts or {}
    vim.validate({
        display_name = { display_name, { 'string' } },
        split_kind = { split_kind, { 'string' } },
    })
    -- local util = require('ollouma.util')
    -- local OlloumaSplitKind = require('ollouma.util.ui').OlloumaSplitKind
    -- util.validate_enum(split_kind, vim.tbl_values(OlloumaSplitKind), 'split_kind')

    ---@type OlloumaSplitUiItem
    local split_ui_item = {
        display_name = display_name,
        split_kind = split_kind,
        buffer_commands = opts.buffer_commands or {},
        buffer_keymaps = opts.buffer_keymaps or {},
    }

    return setmetatable(split_ui_item, self)
end

function SplitUiItem:get_lines()
    if self.buffer == nil then
        return {}
    end

    return vim.api.nvim_buf_get_lines(self.buffer, 0, -1, false)
end

---@param new_text string
function SplitUiItem:write(new_text)
    if self.buffer == nil then
        return
    end
    require('ollouma.util').buf_append_string(self.buffer, new_text)
end

---@param lines string[]
function SplitUiItem:write_lines(lines)
    if self.buffer == nil then
        return
    end
    require('ollouma.util').buf_append_lines(self.buffer, lines)
end

---@param opts { set_current_window: boolean|nil }|nil
function SplitUiItem:open(opts)
    local log = require('ollouma.util.log')
    local OlloumaSplitKind = require('ollouma.util.ui').OlloumaSplitKind
    local current_window = vim.api.nvim_get_current_win()
    opts = opts or {}

    if self.buffer == nil or not vim.api.nvim_buf_is_valid(self.buffer) then
        self.buffer = vim.api.nvim_create_buf(false, true)

        -- SET NAME
        ---@type string
        local buf_name = self.display_name
        local index = 0
        ---@diagnostic disable-next-line: param-type-mismatch
        while vim.fn.bufexists(buf_name) ~= 0 do
            index = index + 1
            buf_name = self.display_name .. '_' .. index
        end
        vim.api.nvim_buf_set_name(self.buffer, buf_name)

        -- SET KEYMAPS
        for _, keymap in ipairs(self.buffer_keymaps) do
            local keymap_opts = vim.tbl_deep_extend('force', keymap.opts or {}, { buffer = self.buffer })
            vim.keymap.set('n', keymap.lhs, keymap.rhs, keymap_opts)
            log.debug('set keymap "' .. keymap.lhs .. '" with opts: ' .. vim.inspect(keymap_opts))
        end

        -- SET COMMANDS
        for _, command in ipairs(self.buffer_commands) do
            vim.api.nvim_buf_create_user_command(self.buffer, command.command_name, command.rhs, command.opts)
            log.debug('create user command "' .. command.command_name .. '" with opts: ' .. vim.inspect(command.opts))
        end
    end

    if self.window == nil or not vim.api.nvim_win_is_valid(self.window) or vim.api.nvim_win_get_buf(self.window) ~= self.buffer then
        if self.split_kind == OlloumaSplitKind.LEFT then
            vim.cmd 'vsplit'
        elseif self.split_kind == OlloumaSplitKind.RIGHT then
            vim.cmd 'vsplit +wincmd\\ x|wincmd\\ l'
        elseif self.split_kind == OlloumaSplitKind.TOP then
            vim.cmd 'split'
        elseif self.split_kind == OlloumaSplitKind.BOTTOM then
            vim.cmd 'split +wincmd\\ x|wincmd\\ j'
        else
            error('invalid prompt_split value: ' .. vim.inspect(self.split_kind))
        end

        self.window = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(self.window, self.buffer)

        -- if opts.winbar_items and #opts.winbar_items ~= 0 then
        --     local winbar_str = ''
        --     for _, winbar_item in ipairs(opts.winbar_items) do
        --         vim.validate({
        --             label = { winbar_item.label, 'string' },
        --             function_name = { winbar_item.function_name, 'string' },
        --             argument = { winbar_item.argument, { 'number', 'nil' } },
        --         })
        --         winbar_str = winbar_str .. '%' ..
        --             (winbar_item.argument or '') ..
        --             '@' .. winbar_item.function_name .. '@' .. winbar_item.label .. '%X '
        --     end
        --     vim.api.nvim_win_set_option(ui_item.window, 'winbar', winbar_str)
        -- end
        -- vim.api.nvim_create_autocmd('WinClosed', {
        --     group = vim.api.nvim_create_augroup('_OlloumaSplitUiWinClosedGroup_' .. ui_item.buffer, { clear = true }),
        --     buffer = ui_item.buffer,
        --     callback = function()
        --         ui_item.window = nil
        --     end
        -- })
    end

    -- for some reason this needs to be after the window initialization or
    -- ftplugin configs don't work
    vim.api.nvim_buf_set_option(self.buffer, 'ft', 'markdown')

    if opts.set_current_window then
        ---@type integer
        current_window = self.window
    end
    vim.api.nvim_set_current_win(current_window)
end

return SplitUiItem
