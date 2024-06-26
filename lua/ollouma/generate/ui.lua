---@type OlloumaSplitKind
local DEFAULT_PROMPT_SPLIT = require('ollouma.util.ui').OlloumaSplitKind.RIGHT

---@class OlloumaGenerateUi
local M = {}

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

    local session_store = require('ollouma.session-store')
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
            session_store.remove_session(split_ui)
        end,
    })
    session_store.add_session(split_ui, {
        title = opts.title,
        created_at = os.time()
    })

    local prompt_item = split_ui:create_ui_item(
        interactive_ui_item_ids.PROMPT,
        DEFAULT_PROMPT_SPLIT,
        {
            display_name = 'PROMPT [' .. opts.title .. ']',
            buffer_commands = {
                {
                    command_name = 'OlloumaSend',
                    rhs = function()
                        local output_item = split_ui:get_ui_item(interactive_ui_item_ids.OUTPUT)
                        local prompt_item = split_ui:get_ui_item(interactive_ui_item_ids.PROMPT)

                        local prompt = prompt_item:get_lines()
                        local generate_request_payload = payload_generator(prompt)

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
                                show_loading_indicator = true,
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

    local session_store = require('ollouma.session-store')
    local ui_utils = require('ollouma.util.ui')
    local output_only_ui_item_ids = { OUTPUT = 'output' }
    local split_ui = ui_utils.OlloumaSplitUi:new({
        on_exit = function(split_ui)
            session_store.remove_session(split_ui)
        end,
    })
    session_store.add_session(split_ui, {
        title = title,
        created_at = os.time()
    })


    local output_item = split_ui:create_ui_item(
        output_only_ui_item_ids.OUTPUT,
        DEFAULT_PROMPT_SPLIT,
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
            show_loading_indicator = true,
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
---@field show_loading_indicator boolean|nil

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

    if opts.show_loading_indicator then
        output_item:write_lines({ '<!-- LOADING -->' })
    end
    local function remove_loading_indicator()
        if opts.show_loading_indicator then
            output_item:delete_lines_from_end(1)
        end
    end

    local api_url = config.api.generate_url

    ---@type OlloumaGenerateOptions
    local generate_opts = {
        payload = payload,
        api_url = api_url,
        on_response_start = function()
            remove_loading_indicator()
        end,
        on_response = function(partial_response)
            output_item:write(partial_response)
        end,
        on_response_end = opts.on_response_end,
        on_api_error = function(api_error)
            remove_loading_indicator()

            local OlloumaApiErrorReason = require('ollouma.util.api-client').OlloumaApiErrorReason
            if api_error.reason == OlloumaApiErrorReason.CONNECTION_FAILED then
                local log = require('ollouma.util.log')
                log.error('Could not connect to ollama server @ ' .. api_url)
            end

            output_item:write_lines({ '<!-- ERROR: ' .. api_error.reason .. ' -->' })
            if api_error.stderr then
                output_item:write_lines({ '<!-- STDERR -->', '' })
                output_item:write(api_error.stderr)
            end
        end
    }

    local stop_generation = generate.start_generation(generate_opts)
    return stop_generation
end

return M
