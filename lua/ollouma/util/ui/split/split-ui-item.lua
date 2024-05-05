---@class OlloumaSplitUiItem
---@field display_name string
---@field split_kind OlloumaSplitKind
---@field split_size float
---@field buffer integer|nil
---@field window integer|nil
---@field buffer_autocommands OlloumaSplitUiBufferAutocommand[]
---@field buffer_commands OlloumaSplitUiBufferCommand[]
---@field buffer_keymaps OlloumaSplitUiBufferKeymap[]
---@field filetype string
---@field buftype string
local SplitUiItem = {}
SplitUiItem.__index = SplitUiItem

---@class OlloumaSplitUiItemConstructorOptions
---@field buffer_autocommands OlloumaSplitUiBufferAutocommand[]|nil
---@field buffer_commands OlloumaSplitUiBufferCommand[]|nil
---@field buffer_keymaps OlloumaSplitUiBufferKeymap[]|nil
---@field filetype string|nil
---@field buftype string|nil
---@field split_size float|nil

---@param display_name string
---@param split_kind OlloumaSplitKind
---@param opts OlloumaSplitUiItemConstructorOptions|nil
---@return OlloumaSplitUiItem
function SplitUiItem:new(display_name, split_kind, opts)
    opts = opts or {}
    vim.validate({
        display_name = { display_name, { 'string' } },
        split_kind = { split_kind, { 'string' } },
        filetype = { opts.filetype, { 'string', 'nil' } },
        buffer_autocommands = { opts.buffer_autocommands, { 'table', 'nil' } },
        buffer_commands = { opts.buffer_commands, { 'table', 'nil' } },
        buffer_keymaps = { opts.buffer_keymaps, { 'table', 'nil' } },
        split_size = { opts.split_size, { 'number', 'nil' } },
        buftype = { opts.buftype, { 'string', 'nil' } },
    })

    local log = require('ollouma.util.log')
    if opts.split_size ~= nil and (opts.split_size <= 0 or opts.split_size >= 1) then
        log.error('[SplitUiItem:new] opts.split_size should be between 0.0 and 1.0 exclusive')
        error('invalid split_size')
    end
    -- local util = require('ollouma.util')
    -- local OlloumaSplitKind = require('ollouma.util.ui').OlloumaSplitKind
    -- util.validate_enum(split_kind, vim.tbl_values(OlloumaSplitKind), 'split_kind')

    ---@type OlloumaSplitUiItem
    local split_ui_item = {
        display_name = display_name,
        split_kind = split_kind,
        buffer_autocommands = opts.buffer_autocommands or {},
        buffer_commands = opts.buffer_commands or {},
        buffer_keymaps = opts.buffer_keymaps or {},
        filetype = opts.filetype or 'markdown',
        split_size = opts.split_size or 0.5,
        buftype = opts.buftype or 'nofile',
    }

    return setmetatable(split_ui_item, self)
end

function SplitUiItem:is_window_valid()
    return self.window ~= nil and
        vim.api.nvim_win_is_valid(self.window) and
        self.buffer == vim.api.nvim_win_get_buf(self.window)
end

function SplitUiItem:get_lines()
    if self.buffer == nil then
        return {}
    end

    return vim.api.nvim_buf_get_lines(self.buffer, 0, -1, false)
end

---@class OlloumaSplitUiItemWriteOptions
---@field hl_group string|number|nil
---@field hl_eol boolean|nil
---@field keep_cursor_on_last_line boolean|nil move cursor to after written text if it was already on the last line. defaults to true

---@param new_text string
---@param opts OlloumaSplitUiItemWriteOptions|nil
function SplitUiItem:write(new_text, opts)
    local function write_function()
        require('ollouma.util').buf_append_string(self.buffer, new_text)
    end
    return self:_wrap_write_keep_cursor_on_last_line(write_function, opts)
end


---@class OlloumaSplitUiItemWriteLinesOptions: OlloumaSplitUiItemWriteOptions
---@field disable_first_newline boolean|nil

---@param lines string[]
---@param opts OlloumaSplitUiItemWriteLinesOptions|nil
function SplitUiItem:write_lines(lines, opts)
    local function write_function()
        opts = opts or {}
        local util = require('ollouma.util')

        if opts.disable_first_newline and lines[1] then
            util.buf_append_string(self.buffer, lines[1])
            table.remove(lines, 1)
        end

        util.buf_append_lines(self.buffer, lines)
    end

    return self:_wrap_write_keep_cursor_on_last_line(write_function, opts)
end

---@param start integer inclusive, 0-based, negative is from end, :h api-indexing
---@param end integer exclusive, 0-based, negative is from end, :h api-indexing
function SplitUiItem:delete_line_range(range_start, range_end)
    vim.validate({
        range_start = { range_start, { 'number' } },
        range_end = { range_end, { 'number' } },
    })
    if self.buffer == nil then
        return
    end

    vim.api.nvim_buf_set_lines(self.buffer, range_start, range_end, false, {})
end

---@param num_lines_to_delete integer
function SplitUiItem:delete_lines_from_end(num_lines_to_delete)
    vim.validate({
        count = { num_lines_to_delete, { 'number' } },
    })
    if self.buffer == nil or num_lines_to_delete < 1 then
        return
    end
    vim.api.nvim_buf_set_lines(self.buffer, -1 - num_lines_to_delete, -1, false, {})
end

---@param opts { set_current_window: boolean|nil, on_write: nil|fun():nil }|nil
function SplitUiItem:open(opts)
    local log = require('ollouma.util.log')
    local ui_utils = require('ollouma.util.ui')
    local option_polyfills = require('ollouma.util.polyfill.options')
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

        -- SET AUTOCOMMANDS
        for _, autocommand in ipairs(self.buffer_autocommands) do
            local autocommand_opts = {
                buffer = self.buffer,
                callback = autocommand.callback,
                once = autocommand.once,
                nested = autocommand.nested,
            }

            vim.api.nvim_create_autocmd(
                autocommand.event,
                autocommand_opts
            )
            log.debug('create buffer autocommand "' ..
                vim.inspect(autocommand.event) .. '" with opts: ' .. vim.inspect(autocommand_opts))
        end
    end

    if not self:is_window_valid() then
        local container_width = vim.api.nvim_win_get_width(0)
        local container_height = vim.api.nvim_win_get_height(0)

        if self.split_kind == OlloumaSplitKind.LEFT then
            vim.cmd 'vsplit'
            vim.api.nvim_win_set_width(0, math.ceil(container_width * self.split_size))
        elseif self.split_kind == OlloumaSplitKind.RIGHT then
            vim.cmd 'vsplit +wincmd\\ x|wincmd\\ l'
            vim.api.nvim_win_set_width(0, math.ceil(container_width * self.split_size))
        elseif self.split_kind == OlloumaSplitKind.TOP then
            vim.cmd 'split'
            vim.api.nvim_win_set_height(0, math.ceil(container_height * self.split_size))
        elseif self.split_kind == OlloumaSplitKind.BOTTOM then
            vim.cmd 'split +wincmd\\ x|wincmd\\ j'
            vim.api.nvim_win_set_height(0, math.ceil(container_height * self.split_size))
        else
            error('invalid prompt_split value: ' .. vim.inspect(self.split_kind))
        end

        self.window = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(self.window, self.buffer)
        vim.api.nvim_win_set_hl_ns(self.window, ui_utils.namespace_id)

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

    -- for some reason the filetype options needs to be set after the window
    -- initialization or ftplugin configs don't work
    option_polyfills.buf_set_option('bufhidden', 'hide', { buf = self.buffer })
    option_polyfills.buf_set_option('buftype', self.buftype, { buf = self.buffer })
    option_polyfills.buf_set_option('filetype', self.filetype, { buf = self.buffer })
    option_polyfills.win_set_option('wrap', true, { win = self.window })

    if opts.set_current_window then
        ---@type integer
        current_window = self.window
    end
    vim.api.nvim_set_current_win(current_window)
end

---@param force boolean|nil
function SplitUiItem:close_window(force)
    if self:is_window_valid() then
        vim.api.nvim_win_close(self.window, force or false)
    end

    self.window = nil
end

---@class OlloumaSplitUiItemSetExtmarkOptions
---@field id integer|nil id of the extmark to edit
---@field hl_group string|number|nil
---@field end_row integer|nil ending line of the mark, 0-based inclusive.
---@field end_col integer|nil ending col of the mark, 0-based inclusive.
---@field hl_eol boolean|nil
---@field invalidate boolean|nil

---@param line integer Line where to place the mark, 0-based. :h api-indexing
---@param col integer Column where to place the mark, 0-based. :h api-indexing
---@param opts OlloumaSplitUiItemSetExtmarkOptions|nil
---@return integer extmark_id id of the created/updated extmark
function SplitUiItem:set_extmark(line, col, opts)
    opts = opts or {}

    local namespace_id = require('ollouma.util.ui').namespace_id

    ---@type vim.api.keyset.set_extmark
    local vim_set_extmark_opts = {
        end_col = opts.end_col,
        end_row = opts.end_row,
        hl_group = opts.hl_group,
        hl_eol = opts.hl_eol,
        id = opts.id,
        invalidate = opts.invalidate,
    }

    return vim.api.nvim_buf_set_extmark(
        self.buffer,
        namespace_id,
        line,
        col,
        vim_set_extmark_opts
    )
end

function SplitUiItem:show_loading_indicator()
    local ui_utils = require('ollouma.util.ui')
    local highlight_group = ui_utils.highlight_groups.loading_indicator

    self:write('LOADING...\n', { hl_group = highlight_group, })
end

--- Assumes nothing was appended after loading indicator since it was shown
function SplitUiItem:hide_loading_indicator()
    self:delete_line_range(-3,-2)
end

-- function SplitUiItem:lock()
--     local log = require('ollouma.util.log')
--     if not self.buffer then
--         log.error('no buffer, cannot lock')
--         return
--     end
--     local set_option = require('ollouma.util.polyfill.options').buf_set_option
--
--     set_option(
--         'modifiable',
--         false,
--         { buf = self.buffer }
--     )
--     set_option(
--         'readonly',
--         true,
--         { buf = self.buffer }
--     )
-- end

-- function SplitUiItem:unlock()
--     local log = require('ollouma.util.log')
--     if not self.buffer then
--         log.error('no buffer, cannot unlock')
--         return
--     end
--     local set_option = require('ollouma.util.polyfill.options').buf_set_option
--
--     set_option(
--         'modifiable',
--         true,
--         { buf = self.buffer }
--     )
--     set_option(
--         'readonly',
--         false,
--         { buf = self.buffer }
--     )
-- end


---@private
---@param write_function fun():nil
---@param opts OlloumaSplitUiItemWriteOptions|nil
function SplitUiItem:_wrap_write_keep_cursor_on_last_line(write_function, opts)
    if self.buffer == nil then
        return
    end
    opts = opts or {}
    local util = require('ollouma.util')

    local last_line_idx_before = vim.api.nvim_buf_line_count(self.buffer) - 1
    local is_highlight_group = not not opts.hl_group
    local is_window_valid = self.window and vim.api.nvim_win_is_valid(self.window)
    local keep_cursor_on_last_line =
        opts.keep_cursor_on_last_line ~= false and is_window_valid and
        vim.api.nvim_win_get_cursor(self.window)[1] - 1 == last_line_idx_before
    local extmark_line = last_line_idx_before
    local extmark_col

    if is_highlight_group then
        extmark_col = util.buf_last_line_end_index(self.buffer)
    end

    write_function()

    local end_pos = util.buf_end_row_col(self.buffer)
    -- local end_col_idx = util.buf_last_line_end_index(self.buffer)
    -- local end_row_idx = vim.api.nvim_buf_line_count(self.buffer) - 1

    if is_highlight_group then
        self:set_extmark(extmark_line, extmark_col, {
            end_col = end_pos.col,
            end_row = end_pos.row,
            hl_eol = opts.hl_eol,
            hl_group = opts.hl_group,
            invalidate = true,
        })
    end

    if keep_cursor_on_last_line then
        vim.api.nvim_win_set_cursor(
            self.window,
            { end_pos.row + 1, end_pos.col }
        )
    end
end


return SplitUiItem
