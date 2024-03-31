---@class OlloumaGenerateOpenedUiMetadata
---@field title string
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

---@class OlloumaGenerateInteractiveUiOptions
---@field title string
---@field initial_prompt string|nil
---@field show_prompt_in_output boolean|nil

---@param payload_generator fun(prompt: string[]): OlloumaGenerateRequestPayload
---@param opts OlloumaGenerateInteractiveUiOptions
---@return OlloumaSplitUi
function M.start_interactive_ui(payload_generator, opts)
    vim.validate({
        opts = { opts, { 'table' } },
        title = { opts.title, { 'string' } },
        initial_prompt = { opts.initial_prompt, { 'string', 'nil' } },
    })

    local ui_utils = require('ollouma.util.ui')
    local util = require('ollouma.util')
    local interactive_ui_item_ids = {
        PROMPT = 'prompt',
        OUTPUT = 'output',
    }
    local split_ui = ui_utils.OlloumaSplitUi:new({
        custom_resume_session = function(split_ui)
            local prompt_item = split_ui:get_ui_item(interactive_ui_item_ids.PROMPT)
            local output_item = split_ui:get_ui_item(interactive_ui_item_ids.OUTPUT)

            prompt_item:open({ set_current_window = true })
            output_item:open()
        end,
        on_exit = function(split_ui)
            M.opened_uis[split_ui] = nil
        end,
    })
    M.opened_uis[split_ui] = {
        title = opts.title,
        created_at = os.time()
    }
    local prompt_item = split_ui:create_ui_item(
        interactive_ui_item_ids.PROMPT,
        ui_utils.OlloumaSplitKind.LEFT,
        {
            display_name = 'PROMPT [' .. opts.title .. ']',
            buffer_commands = {
                {
                    command_name = 'OlloumaSend',
                    rhs = function()
                        local config = require('ollouma').config
                        local generate = require('ollouma.generate')

                        local output_item = split_ui:get_ui_item(interactive_ui_item_ids.OUTPUT)
                        local prompt_item = split_ui:get_ui_item(interactive_ui_item_ids.PROMPT)

                        local prompt = prompt_item:get_lines()
                        local generate_request_payload = payload_generator(prompt)
                        if generate_request_payload.options ~= nil and #vim.tbl_keys(generate_request_payload.options) == 0 then
                            generate_request_payload.options = nil
                        end

                        output_item:open({ set_current_window = false })

                        local function remove_gen_stop_command()
                            if output_item.buffer then
                                vim.api.nvim_buf_del_user_command(output_item.buffer, 'OlloumaGenStop')
                            end
                            if prompt_item.buffer then
                                vim.api.nvim_buf_del_user_command(prompt_item.buffer, 'OlloumaGenStop')
                            end
                        end

                        local stop_generation = M.generate_to_ui_item(
                            output_item,
                            generate_request_payload,
                            {
                                show_prompt_in_output = opts.show_prompt_in_output,
                                on_response_end = function()
                                    remove_gen_stop_command()
                                    output_item:write_lines({ '<!-------------------->', '' })
                                end
                            }
                        )

                        local function stop()
                            stop_generation()
                            remove_gen_stop_command()
                            output_item:write_lines({ '<!---- INTERRUPTED --->', '' })
                        end

                        if output_item.buffer then
                            vim.api.nvim_buf_create_user_command(output_item.buffer, 'OlloumaGenStop', stop, {})
                        end
                        if prompt_item.buffer then
                            vim.api.nvim_buf_create_user_command(prompt_item.buffer, 'OlloumaGenStop', stop, {})
                        end
                    end,
                    opts = {}
                },
            },
            buffer_keymaps = {
                {
                    lhs = '<leader>os', rhs = ':OlloumaSend<CR>'
                },
            },
        }
    )
    local _ = split_ui:create_ui_item(
        interactive_ui_item_ids.OUTPUT,
        ui_utils.OlloumaSplitKind.BOTTOM,
        { display_name = 'OUTPUT [' .. opts.title .. ']' }
    )

    prompt_item:open({ set_current_window = true })
    if opts.initial_prompt then
        util.buf_append_string(prompt_item.buffer, opts.initial_prompt)
    end

    return split_ui
end

---@class OlloumaGenerateOutputOnlyUiOptions
---@field show_prompt_in_output boolean|nil

---@param payload OlloumaGenerateRequestPayload
---@param title string
---@param opts OlloumaGenerateOutputOnlyUiOptions|nil
function M.start_output_only_ui(payload, title, opts)
    opts = opts or {}
    vim.validate({
        payload = { payload, { 'table' } },
        title = { title, { 'string' } },
    })

    local ui_utils = require('ollouma.util.ui')
    local output_only_ui_item_ids = { OUTPUT = 'output' }
    local split_ui = ui_utils.OlloumaSplitUi:new({
        on_exit = function(split_ui)
            M.opened_uis[split_ui] = nil
        end,
    })
    M.opened_uis[split_ui] = { title = title, created_at = os.time() }
    local output_item = split_ui:create_ui_item(
        output_only_ui_item_ids.OUTPUT,
        ui_utils.OlloumaSplitKind.LEFT,
        { display_name = 'OUTPUT [' .. title .. ']' }
    )
    output_item:open()

    local function remove_gen_stop_command()
        if output_item.buffer then
            vim.api.nvim_buf_del_user_command(output_item.buffer, 'OlloumaGenStop')
        end
    end

    local stop_generation = M.generate_to_ui_item(
        output_item,
        payload,
        {
            show_prompt_in_output = opts.show_prompt_in_output,
            on_response_end = function()
                remove_gen_stop_command()
            end
        }
    )

    local function stop()
        stop_generation()
        remove_gen_stop_command()
        output_item:write_lines({ '<!---- INTERRUPTED --->', '' })
    end

    if output_item.buffer then
        vim.api.nvim_buf_create_user_command(output_item.buffer, 'OlloumaGenStop', stop, {})
    end
end

---@private
---@class OlloumaGenerateToUiItemOptions
---@field on_response_end nil|fun():nil
---@field show_prompt_in_output boolean|nil

---@private
---@param output_item OlloumaSplitUiItem
---@param payload OlloumaGenerateRequestPayload
---@param opts OlloumaGenerateToUiItemOptions|nil
---@return fun():nil stop_generation
function M.generate_to_ui_item(output_item, payload, opts)
    local config = require('ollouma').config
    local generate = require('ollouma.generate')
    opts = opts or {}

    if opts.show_prompt_in_output then
        output_item:write_lines({ '<!------ Prompt ------>', '' })
        output_item:write(payload.prompt)
        output_item:write_lines({ '<!------ Output ------>', '' })
    end

    ---@type OlloumaGenerateOptions
    local generate_opts = {
        payload = payload,
        api_url = config.api.generate_url,
        on_response = function(partial_response)
            output_item:write(partial_response)
        end,
        on_response_end = opts.on_response_end,
    }

    local stop_generation = generate.start_generation(generate_opts)
    return stop_generation
end

return M
