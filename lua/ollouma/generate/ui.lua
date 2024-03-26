---@class OlloumaGenerateOpenedUiMetadata
---@field model string
---@field created_at integer

---@class OlloumaGenerateOpenedUi
---@field ui OlloumaSplitUi
---@field metadata OlloumaGenerateOpenedUiMetadata

---@class OlloumaGenerateUi
---@field opened_uis table<OlloumaSplitUi,  OlloumaGenerateOpenedUiMetadata>
local M = {
    opened_uis = {}
}

-- function M.test(arg)
--     -- vim.cmd('echo "hi"')
--     vim.notify('notified? arg=' .. vim.inspect(arg))
--     -- print('test from ollouma.generate.test()')
-- end

-- vim.g._ollouma_winbar_send = function()
--     vim.cmd('OlloumaSend')
-- end

-- vim.g._ollouma_winbar_empty = function()
--     M:empty_buffers()
-- end
--
-- vim.g._ollouma_winbar_close = function()
--     M:close()
-- end


---@return OlloumaGenerateOpenedUi[]
function M.list_opened_uis()
    ---@type OlloumaGenerateOpenedUi[]
    local opened_list = {}
    for split_ui, metadata in pairs(M.opened_uis) do
        table.insert(
            opened_list,
            {
                ui = split_ui,
                metadata = metadata
            }
        )
    end
    return opened_list
    -- return vim.deepcopy(M.opened_uis)
end

---@param model string
---@param api_url string
-- ---@param winbar_items OlloumaSplitUiWinbarItem[]
---@return OlloumaSplitUi split_ui
function M.start_ui(model, api_url)
    vim.validate({
        model = { model, 'string' },
        api_url = { api_url, 'string' },
        -- winbar_items = { winbar_items, 'table' },
    })
    local generate = require('ollouma.generate')
    local ui_utils = require('ollouma.util.ui')

    ---@type OlloumaSplitUi
    local split_ui = ui_utils.SplitUi:new({
        prompt_split = ui_utils.OlloumaSplitKind.LEFT,
        output_split = ui_utils.OlloumaSplitKind.BOTTOM,
        model_name = model,
        on_exit = function(split_ui)
            M.opened_uis[split_ui] = nil
        end
    })

    M.opened_uis[split_ui] = {
        model = model,
        created_at = os.time()
    }
    -- table.insert(
    --     M.opened_uis,
    --     ---@type OlloumaGenerateOpenedUi
    --     {
    --         ui = split_ui,
    --         model = model,
    --         created_at = os.time()
    --     }
    -- )

    local prompt_commands = {
        OlloumaSend = {
            rhs = function()
                split_ui:open_output()
                local prompt = split_ui:get_prompt_lines()

                split_ui:output_write_lines({ '<!------ Prompt ------>' })
                split_ui:output_write_lines(prompt)
                split_ui:output_write_lines({ '<!------ Output ------>', '' })

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
                        split_ui:output_write_lines({ '' })
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
            end,
            opts = {},
        },
    }

    split_ui:open_prompt(prompt_commands)

    return split_ui
end

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
return M
