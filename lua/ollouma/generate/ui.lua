---@class OlloumaGenerateUiOptions
---@field api_url string|nil
---@field initial_prompt string|nil
---@field prompt_prefix string|nil
---@field format 'json'|nil
---@field show_prompt_in_output boolean|nil
---@field show_prompt_prefix_in_output boolean|nil

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
end

---@param model string
---@param opts OlloumaGenerateUiOptions|nil
---@return OlloumaSplitUi split_ui
function M.start_ui(model, opts)
    local config = require('ollouma').config
    local generate = require('ollouma.generate')
    opts = opts or {}

    vim.validate({
        model = { model, 'string' },
        api_url = { opts.api_url, { 'string', 'nil' } },
        initial_prompt = { opts.initial_prompt, { 'string', 'nil' } },
        prompt_prefix = { opts.prompt_prefix, { 'string', 'nil' } },
        show_prompt_in_output = { opts.show_prompt_in_output, { 'boolean', 'nil' } },
        show_prompt_prefix_in_output = { opts.show_prompt_prefix_in_output, { 'boolean', 'nil' } },
    })
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

    local prompt_commands = {
        OlloumaSend = {
            rhs = function()
                split_ui:open_output()
                local prompt = split_ui:get_prompt_lines()

                -- M.send_prompt(
                --     {
                --         model = model,
                --         prompt = vim.fn.join(prompt, '\n'),
                --         system = opts.prompt_prefix,
                --         format = opts.format,
                --     },
                --     split_ui.output,
                --     split_ui
                -- )

                if opts.show_prompt_in_output then
                    split_ui:output_write_lines({ '<!------ Prompt ------>' })
                    if opts.show_prompt_prefix_in_output and opts.prompt_prefix then
                        split_ui:ouput_write('\n' .. opts.prompt_prefix)
                    end
                    split_ui:output_write_lines(prompt)
                    split_ui:output_write_lines({ '<!------ Output ------>', '' })
                end

                ---@type OlloumaGenerateOptions
                local generate_opts = {
                    payload = {
                        model = model,
                        prompt = vim.fn.join(prompt, '\n'),
                        system = opts.prompt_prefix,
                        format = opts.format,
                    },
                    api_url = (opts.api_url or config.api.generate_url),
                    on_response = function(partial_response)
                        split_ui:ouput_write(partial_response)
                    end,
                    on_response_end = function()
                        vim.api.nvim_buf_del_user_command(split_ui.prompt.buffer, 'OlloumaGenStop')
                        vim.api.nvim_buf_del_user_command(split_ui.output.buffer, 'OlloumaGenStop')
                        split_ui:output_write_lines({ '<!-------------------->', '' })
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

    --- TODO: configurable buffer keymaps

    ---@type OlloumaSplitUiBufferKeymap[]
    local prompt_keymaps = {
        {
            lhs = '<leader>os',
            rhs = ':OlloumaSend<CR>', -- TODO: this rhs should be requireable in lua
            opts = {},
        },
    }

    split_ui:open_prompt(prompt_commands, prompt_keymaps, opts.initial_prompt)

    return split_ui
end

-- TODO: finish refactor ?
-- ---@param payload OlloumaGenerateRequestPayload
-- ---@param output_ui_item OlloumaSplitUiItem
-- ---@param split_ui OlloumaSplitUi
-- function M.send_prompt(payload, output_ui_item)
--     local config = require('ollouma').config
--     local generate = require('ollouma.generate')
--
--     if opts.show_prompt_in_output then
--         split_ui:output_write_lines({ '<!------ Prompt ------>' })
--         if opts.show_prompt_prefix_in_output and opts.prompt_prefix then
--             split_ui:ouput_write('\n' .. opts.prompt_prefix)
--         end
--         split_ui:output_write_lines(prompt)
--         split_ui:output_write_lines({ '<!------ Output ------>', '' })
--     end
--
--     ---@type OlloumaGenerateOptions
--     local generate_opts = {
--         payload = payload,
--         api_url = (opts.api_url or config.api.generate_url),
--         on_response = function(partial_response)
--             split_ui:ouput_write(partial_response)
--         end,
--         on_response_end = function()
--             vim.api.nvim_buf_del_user_command(split_ui.prompt.buffer, 'OlloumaGenStop')
--             vim.api.nvim_buf_del_user_command(split_ui.output.buffer, 'OlloumaGenStop')
--             split_ui:output_write_lines({ '<!-------------------->', '' })
--         end
--     }
--
--     local stop_generation = generate.start_generation(generate_opts)
--
--     local function stop()
--         stop_generation()
--         generate_opts.on_response_end()
--     end
--
--     split_ui:create_user_command(
--         'OlloumaGenStop',
--         { rhs = stop, opts = {} },
--         { split_ui.prompt, split_ui.output }
--     )
-- end

return M
