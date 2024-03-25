-- ---@class OlloumaGenerateUiItem
-- ---@field buffer integer|nil
-- ---@field window integer|nil
--
-- ---@class OlloumaGenerateUiState
-- ---@field prompt OlloumaGenerateUiItem
-- ---@field output OlloumaGenerateUiItem
--
-- ---@class OlloumaGenerateUiBufferCommand
-- ---@field rhs string|fun():nil right-hand side of a user command mapping, vim command or lua function
-- ---@field opts table
--
-- ---@alias OlloumaGenerateUiStartOptsCommands table<string, OlloumaGenerateUiBufferCommand>
--
---@class OlloumaGenerateWinbarItem
---@field label string
---@field function_name string
--
-- ---@class OlloumaGenerateUiStartOpts
-- ---@field commands OlloumaGenerateUiStartOptsCommands
-- ---@field winbar_items OlloumaGenerateWinbarItem[]
--TODO:---@field keymaps OlloumaGenerateUiStartOptsKeymaps

---@class OlloumaGenerateUi
-- ---@field state OlloumaGenerateUiState
local M = {
    -- state = {
    --     prompt = {},
    --     output = {},
    -- },
}

-- _G._ollouma_winbar_send = function()
--     vim.cmd('OlloumaSend')
-- end
--
-- _G._ollouma_winbar_reset = function()
--     M:empty_buffers()
-- end
--
-- _G._ollouma_winbar_close = function()
--     M:close()
-- end

---@param model string
---@param api_url string
---@param winbar_items OlloumaGenerateWinbarItem[]
function M.start_ui(model, api_url, winbar_items)
    vim.validate({
        model = { model, 'string' },
        api_url = { api_url, 'string' },
        winbar_items = { winbar_items, 'table' },
    })
    local generate = require('ollouma.generate')
    local ui_utils = require('ollouma.util.ui')

    ---@type OlloumaSplitUi
    local split_ui = ui_utils.SplitUi:new({
        prompt_split = ui_utils.OlloumaSplitKind.LEFT,
        output_split = ui_utils.OlloumaSplitKind.BOTTOM,
    })

    split_ui:open_prompt(model, {
        OlloumaSend = {
            rhs = function()
                split_ui:open_output(model)
                local prompt = split_ui:get_prompt_lines()

                ---@type OlloumaGenerateOptions
                local generate_opts = {
                    model = model,
                    prompt = vim.fn.join(prompt, '\n'),
                    api_url = api_url,
                    on_response = function(partial_response)
                        split_ui:ouput_write(partial_response)
                    end,
                    on_response_end = function()
                        vim.api.nvim_buf_del_user_command(split_ui.prompt.buffer, 'OlloumaGenStop')
                        vim.api.nvim_buf_del_user_command(split_ui.output.buffer, 'OlloumaGenStop')
                    end
                }

                local stop_generation = generate.start_generation(generate_opts)

                local function stop()
                    stop_generation()
                    generate_opts.on_response_end()
                end

                split_ui:create_user_command(
                    'OlloumaGenStop',
                    { rhs = stop, opts = {} },
                    { split_ui.prompt, split_ui.output }
                )
                -- error('todo: use split_ui utils')
                -- local prompt = M:get_prompt()
                --
                -- M:output_write_lines({ '', '<!------ Prompt ------' })
                -- M:output_write_lines(prompt)
                -- M:output_write_lines({ '--------------------->', '' })
                --
                -- ---@type OlloumaGenerateOptions
                -- local generate_opts = {
                --     model = model,
                --     prompt = vim.fn.join(prompt, '\n'),
                --     api_url = api_url,
                --     on_response = function(partial_response)
                --         M:output_write(partial_response)
                --
                --         if not M.state.output.window or not vim.api.nvim_win_is_valid(M.state.output.window) then
                --             return
                --         end
                --
                --         -- if cursor is on second to last line, then
                --         -- move it to the last line
                --         local output_cursor = vim.api.nvim_win_get_cursor(M.state.output.window)
                --         local last_line_idx = vim.api.nvim_buf_line_count(M.state.output.buffer)
                --
                --         if output_cursor[1] == last_line_idx - 1 then
                --             local last_line = vim.api.nvim_buf_get_lines(
                --                 M.state.output.buffer,
                --                 -2, -1, false
                --             )
                --             local last_column_idx = math.max(0, #last_line - 1)
                --
                --             vim.api.nvim_win_set_cursor(
                --                 M.state.output.window,
                --                 { last_line_idx, last_column_idx }
                --             )
                --         end
                --     end,
                --     on_response_end = function()
                --         vim.api.nvim_buf_del_user_command(M.state.prompt.buffer, 'OlloumaGenStop')
                --         vim.api.nvim_buf_del_user_command(M.state.output.buffer, 'OlloumaGenStop')
                --     end
                -- }
                -- local stop_generation = generate.start_generation(generate_opts)
                --
                -- local function stop()
                --     stop_generation()
                --     generate_opts.on_response_end()
                -- end
                --
                -- vim.api.nvim_buf_create_user_command(
                --     M.state.prompt.buffer,
                --     'OlloumaGenStop',
                --     stop,
                --     {}
                -- )
                -- vim.api.nvim_buf_create_user_command(
                --     M.state.output.buffer,
                --     'OlloumaGenStop',
                --     stop,
                --     {}
                -- )
            end,
            opts = {},
        },
    })


    -- M:start(model, {
    --     commands = {
    --         OlloumaSend = {
    --             rhs = function()
    --                 local prompt = M:get_prompt()
    --
    --                 M:output_write_lines({ '', '<!------ Prompt ------' })
    --                 M:output_write_lines(prompt)
    --                 M:output_write_lines({ '--------------------->', '' })
    --
    --                 ---@type OlloumaGenerateOptions
    --                 local generate_opts = {
    --                     model = model,
    --                     prompt = vim.fn.join(prompt, '\n'),
    --                     api_url = api_url,
    --                     on_response = function(partial_response)
    --                         M:output_write(partial_response)
    --
    --                         if not M.state.output.window or not vim.api.nvim_win_is_valid(M.state.output.window) then
    --                             return
    --                         end
    --
    --                         -- if cursor is on second to last line, then
    --                         -- move it to the last line
    --                         local output_cursor = vim.api.nvim_win_get_cursor(M.state.output.window)
    --                         local last_line_idx = vim.api.nvim_buf_line_count(M.state.output.buffer)
    --
    --                         if output_cursor[1] == last_line_idx - 1 then
    --                             local last_line = vim.api.nvim_buf_get_lines(
    --                                 M.state.output.buffer,
    --                                 -2, -1, false
    --                             )
    --                             local last_column_idx = math.max(0, #last_line - 1)
    --
    --                             vim.api.nvim_win_set_cursor(
    --                                 M.state.output.window,
    --                                 { last_line_idx, last_column_idx }
    --                             )
    --                         end
    --                     end,
    --                     on_response_end = function()
    --                         vim.api.nvim_buf_del_user_command(M.state.prompt.buffer, 'OlloumaGenStop')
    --                         vim.api.nvim_buf_del_user_command(M.state.output.buffer, 'OlloumaGenStop')
    --                     end
    --                 }
    --                 local stop_generation = generate.start_generation(generate_opts)
    --
    --                 local function stop()
    --                     stop_generation()
    --                     generate_opts.on_response_end()
    --                 end
    --
    --                 vim.api.nvim_buf_create_user_command(
    --                     M.state.prompt.buffer,
    --                     'OlloumaGenStop',
    --                     stop,
    --                     {}
    --                 )
    --                 vim.api.nvim_buf_create_user_command(
    --                     M.state.output.buffer,
    --                     'OlloumaGenStop',
    --                     stop,
    --                     {}
    --                 )
    --             end,
    --             opts = {},
    --         },
    --     },
    --
    --     winbar_items = winbar_items,
    -- })
end

--
-- -- TODO: more explicit name + move to ollouma.utils ?
-- ---@param model_name string
-- ---@param opts? OlloumaGenerateUiStartOpts
-- function M:start(model_name, opts)
--     opts = opts or {}
--
--     self.state.prompt.buffer = self.state.prompt.buffer or vim.api.nvim_create_buf(false, true)
--     self.state.output.buffer = self.state.output.buffer or vim.api.nvim_create_buf(false, true)
--
--     if opts.commands then
--         for command_name, cmd in pairs(opts.commands) do
--             vim.validate({
--                 command_name = { command_name, 'string' },
--                 rhs = { cmd.rhs, { 'string', 'function' } },
--                 opts = { cmd.opts, { 'table', 'nil' } },
--             })
--
--             vim.api.nvim_buf_create_user_command(
--                 self.state.prompt.buffer,
--                 command_name,
--                 cmd.rhs,
--                 cmd.opts or {}
--             )
--         end
--     end
--
--     vim.api.nvim_buf_set_name(self.state.prompt.buffer, 'PROMPT [' .. model_name .. ']')
--     vim.api.nvim_buf_set_name(self.state.output.buffer, 'OUTPUT [' .. model_name .. ']')
--
--     self:open_windows()
--
--     vim.api.nvim_buf_set_option(self.state.prompt.buffer, 'ft', 'markdown')
--     vim.api.nvim_buf_set_option(self.state.output.buffer, 'ft', 'markdown')
--
--     if opts.winbar_items and #opts.winbar_items ~= 0 then
--         local winbar_str = ''
--         for _, winbar_item in ipairs(opts.winbar_items) do
--             vim.validate({
--                 label = { winbar_item.label, 'string' },
--                 function_name = { winbar_item.function_name, 'string' },
--             })
--             winbar_str = winbar_str .. '%@' .. winbar_item.function_name .. '@' .. winbar_item.label .. '%X '
--         end
--         vim.api.nvim_win_set_option(self.state.prompt.window, 'winbar', winbar_str)
--     end
-- end
--
-- function M:are_buffers_valid()
--     if not self.state.prompt.buffer or not vim.api.nvim_buf_is_valid(self.state.prompt.buffer) then
--         return false
--     end
--     if not self.state.output.buffer or not vim.api.nvim_buf_is_valid(self.state.output.buffer) then
--         return false
--     end
--     return true
-- end
--
-- function M:open_windows()
--     if not M:are_buffers_valid() then
--         require('ollouma.util.log').error('cannot open windows, buffer is invalid')
--         -- error()
--         return
--     end
--
--     if not self.state.output.window or not vim.api.nvim_win_is_valid(self.state.output.window) then
--         vim.cmd.vsplit()
--         self.state.output.window = vim.api.nvim_get_current_win()
--     end
--
--     if not self.state.prompt.window or not vim.api.nvim_win_is_valid(self.state.prompt.window) then
--         vim.api.nvim_set_current_win(self.state.output.window)
--         vim.cmd.split()
--         self.state.prompt.window = vim.api.nvim_get_current_win()
--     end
--
--     vim.api.nvim_win_set_buf(self.state.prompt.window, self.state.prompt.buffer)
--     vim.api.nvim_win_set_buf(self.state.output.window, self.state.output.buffer)
--
--     vim.api.nvim_set_current_win(self.state.prompt.window)
-- end
--
-- function M:empty_buffers()
--     local emptied_any = false
--
--     if self.state.output.buffer and vim.api.nvim_buf_is_loaded(self.state.output.buffer) then
--         emptied_any = true
--         vim.api.nvim_buf_set_lines(self.state.output.buffer, 0, -1, false, { '' })
--     end
--
--     if self.state.prompt.buffer and vim.api.nvim_buf_is_loaded(self.state.prompt.buffer) then
--         emptied_any = true
--         vim.api.nvim_buf_set_lines(self.state.prompt.buffer, 0, -1, false, { '' })
--     end
--
--
--     if not emptied_any then
--         require('ollouma.util.log').warn('no buffers to empty')
--     end
-- end
--
-- function M:output_write_lines(lines)
--     local util = require('ollouma.util')
--
--     util.buf_append_lines(self.state.output.buffer, lines)
-- end
--
-- function M:output_write(lines)
--     local util = require('ollouma.util')
--
--     util.buf_append_string(self.state.output.buffer, lines)
-- end
--
-- ---@return string[] prompt_lines the lines currently in the prompt buffer
-- function M:get_prompt()
--     return vim.api.nvim_buf_get_lines(self.state.prompt.buffer, 0, -1, false)
-- end
--
-- --- Close any open windows
-- function M:close()
--     if self.state.prompt.window and vim.api.nvim_win_is_valid(self.state.prompt.window) then
--         vim.api.nvim_win_close(self.state.prompt.window, false)
--     end
--     if self.state.output.window and vim.api.nvim_win_is_valid(self.state.output.window) then
--         vim.api.nvim_win_close(self.state.output.window, false)
--     end
--
--     self.state.prompt.window = nil
--     self.state.output.window = nil
-- end

return M
