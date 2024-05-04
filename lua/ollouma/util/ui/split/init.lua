---@class OlloumaSplitUiBufferAutocommand
---@field event string[]|string
---@field callback string|fun(opts: { id: number, event: string, buf: integer, file: string }):nil
---@field nested boolean|nil
---@field once boolean|nil

---@class OlloumaSplitUiBufferCommand
---@field command_name string
---@field rhs string|fun():nil
---@field opts table|nil

---@class OlloumaSplitUiBufferKeymap
---@field lhs string
---@field rhs string|fun():nil
---@field opts table|nil

-- SplitUi

---@class OlloumaSplitUi
---@field on_exit nil|fun(split_ui: OlloumaSplitUi):nil
---@field custom_resume_session nil|fun(split_ui: OlloumaSplitUi):nil
---@field private ui_items { [string]: OlloumaSplitUiItem }
local SplitUi = {}
SplitUi.__index = SplitUi

---@class OlloumaSplitUiConstructorOptions
---@field on_exit nil|fun(split_ui: OlloumaSplitUi):nil
---@field custom_resume_session nil|fun(split_ui: OlloumaSplitUi):nil

---@param opts OlloumaSplitUiConstructorOptions|nil
---@return OlloumaSplitUi
function SplitUi:new(opts)
    opts = opts or {}

    vim.validate({
        on_exit = { opts.on_exit, { 'function', 'nil' } },
        custom_resume_session = { opts.custom_resume_session, { 'function', 'nil' } },
    })

    ---@type OlloumaSplitUi
    local split_ui = {
        ui_items = {
        },
        on_exit = opts.on_exit,
        custom_resume_session = opts.custom_resume_session,
    }

    return setmetatable(split_ui, self)
end

---@class OlloumaSplitUiCreateItemOptions
---@field display_name string|nil
---@field filetype string|nil
---@field buffer_autocommands OlloumaSplitUiBufferAutocommand[]|nil
---@field buffer_commands OlloumaSplitUiBufferCommand[]|nil
---@field buffer_keymaps OlloumaSplitUiBufferKeymap[]|nil
---@field split_size float|nil
---@field buftype string|nil

---@param item_id string
---@param split_kind OlloumaSplitKind
---@param opts OlloumaSplitUiCreateItemOptions|nil
---@return OlloumaSplitUiItem ui_item
function SplitUi:create_ui_item(item_id, split_kind, opts)
    opts = opts or {}
    local SplitUiItem = require('ollouma.util.ui.split.split-ui-item')

    if self.ui_items[item_id] then
        require('ollouma.util.log').error('duplicate UI item id: ' .. item_id)
        error()
    end

    vim.validate({
        item_id = { item_id, { 'string' } },
        display_name = { opts.display_name, { 'string', 'nil' } },
    })

    local ui_item = SplitUiItem:new(
        opts.display_name or item_id,
        split_kind,
        {
            buffer_autocommands = opts.buffer_autocommands,
            buffer_commands = opts.buffer_commands,
            buffer_keymaps = opts.buffer_keymaps,
            filetype = opts.filetype,
            split_size = opts.split_size,
            buftype = opts.buftype,
        }
    )
    self.ui_items[item_id] = ui_item
    return ui_item
end

---@param item_id string
---@return OlloumaSplitUiItem
function SplitUi:get_ui_item(item_id)
    local ui_item = self.ui_items[item_id]

    if not ui_item then
        require('ollouma.util.log').error('could not find ui item with id "' .. item_id .. '"')
        error()
    end

    return ui_item
end

function SplitUi:resume_session()
    if self.custom_resume_session then
        self:custom_resume_session()
        return
    end

    for _, ui_item in pairs(self.ui_items) do
        if not ui_item:is_window_valid() then
            ui_item.window = nil
            ui_item:open()
        end
    end
end

function SplitUi:close_windows()
    local log = require('ollouma.util.log')

    for item_id, ui_item in pairs(self.ui_items) do
        local ok, err = pcall(ui_item.close_window, ui_item)

        if not ok then
            log.error('could not close window for ui item with id "' .. item_id .. '": ' .. err)
        end
    end
end

function SplitUi:destroy_buffers()
    local log = require('ollouma.util.log')

    for item_id, ui_item in pairs(self.ui_items) do
        if ui_item.buffer and vim.api.nvim_buf_is_valid(ui_item.buffer) then
            local ok, err = pcall(vim.api.nvim_buf_delete, ui_item.buffer, {})

            if ok then
                ui_item.buffer = nil
            else
                log.error('could not delete buffer for ui item with id "' .. item_id .. '": ' .. err)
            end
        end
    end
end

function SplitUi:exit()
    if self.on_exit then
        self:on_exit()
    end

    self:close_windows()
    self:destroy_buffers()
end

return SplitUi
