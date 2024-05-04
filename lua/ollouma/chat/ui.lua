---@class OlloumaChatUiStartOptions
---@field api_url string|nil
---@field model string|nil
---@field system_prompt string|nil
---@field title string|nil

local CHAT_OUTPUT_FILETYPE = 'markdown'
local CHAT_OUTPUT_SPLIT_SIZE = 0.8

---@class OlloumaChatUi
local M = {}

---@param opts OlloumaChatUiStartOptions|nil
---@return OlloumaSplitUi
function M.start_chat_ui(opts)
    local config = require('ollouma').config
    opts = opts or {}
    vim.validate({
        api_url = { opts.api_url, { 'string', 'nil' } },
        model = { opts.model, { 'string', 'nil' } },
        title = { opts.title, { 'string', 'nil' } },
    })
    opts.api_url = opts.api_url or config.api.chat_url
    opts.model = opts.model or config.model

    opts.title = opts.title or ('chat - ' .. opts.model)

    local chat = require('ollouma.chat')
    local log = require('ollouma.util.log')
    local session_store = require('ollouma.session-store')
    local ui_utils = require('ollouma.util.ui')
    local chat_ui_item_ids = {
        PROMPT = 'prompt',
        OUTPUT = 'output',
    }

    local split_ui = ui_utils.OlloumaSplitUi:new({
        custom_resume_session = function(split_ui)
            local prompt_item = split_ui:get_ui_item(chat_ui_item_ids.PROMPT)
            local output_item = split_ui:get_ui_item(chat_ui_item_ids.OUTPUT)

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

    ---@type OlloumaChatMessageDto[]
    local messages = {}

    if opts.system_prompt then
        table.insert(messages, {
            role = chat.OlloumaChatRole.SYSTEM,
            content = opts.system_prompt,
        })
    end

    local function send_chat_from_prompt()
        local output_item = split_ui:get_ui_item(chat_ui_item_ids.OUTPUT)
        local prompt_item = split_ui:get_ui_item(chat_ui_item_ids.PROMPT)

        local prompt = prompt_item:get_lines()
        -- local generate_request_payload = payload_generator(prompt)

        local function remove_gen_stop_command()
            if output_item.buffer then
                vim.api.nvim_buf_del_user_command(output_item.buffer, 'OlloumaGenStop')
            end
            if prompt_item.buffer then
                vim.api.nvim_buf_del_user_command(prompt_item.buffer, 'OlloumaGenStop')
            end
        end

        output_item:open({ set_current_window = false })

        local role_text = chat.OlloumaChatRole.USER .. ':\n'
        output_item:write(role_text, {
            hl_eol = true,
            hl_group = ui_utils.highlight_groups.chat.role,
        })

        -- local line_count = vim.api.nvim_buf_line_count(output_item.buffer)
        -- local extmark_line = line_count - 1
        -- local extmark_col = 0
        -- output_item:set_extmark(extmark_line, extmark_col, {
        --     end_col = string.len(role_text),
        --     -- end_row = extmark_line,
        --     hl_eol = true,
        --     hl_group = ui_utils.highlight_groups.chat.role,
        -- })

        output_item:write_lines(prompt_item:get_lines(), { disable_first_newline = true })
        output_item:write('\n')
        output_item:lock()

        table.insert(
            messages,
            {
                role = chat.OlloumaChatRole.USER,
                content = table.concat(prompt, '\n')
            }
        )

        ---@type string|nil
        local current_message = nil

        local stop_generation = chat.send_chat({
            api_url = opts.api_url,
            payload = {
                messages = messages,
                model = opts.model,
                options = {
                    -- temperature = 0.6,
                },
            },
            on_api_error = function(api_error)
                local OlloumaApiErrorReason = require('ollouma.util.api-client').OlloumaApiErrorReason

                if api_error.reason == OlloumaApiErrorReason.CONNECTION_FAILED then
                    log.error('Could not connect to ollama server @ ' .. opts.api_url)
                else
                    log.error('API error: ' .. vim.inspect(api_error))
                end
            end,
            on_message_start = function(message_chunk)
                current_message = ''
                output_item:unlock()
                output_item:write(
                    message_chunk.message.role .. ':\n',
                    {
                        hl_eol = true,
                        hl_group = ui_utils.highlight_groups.chat.role,
                    }
                )
                output_item:lock()
            end,
            on_message_chunk = function(message_chunk)
                current_message = current_message .. message_chunk.content
                output_item:unlock()
                output_item:write(message_chunk.content)
                output_item:lock()
            end,
            on_message_end = function()
                table.insert(
                    messages,
                    {
                        role = chat.OlloumaChatRole.ASSISTANT,
                        content = current_message,
                    }
                )
                remove_gen_stop_command()
                output_item:unlock()
                output_item:write_lines({
                    --     '<!-- message end -->',
                    ''
                })
                output_item:lock()
                require('ollouma.util.polyfill.options').buf_set_option(
                    'modified',
                    false,
                    { buf = output_item.buffer }
                )
            end,
        })

        local function stop()
            stop_generation()
            remove_gen_stop_command()
            output_item:unlock()
            output_item:write_lines({ '<!---- INTERRUPTED --->', '' })
            output_item:lock()
        end

        if output_item.buffer then
            vim.api.nvim_buf_create_user_command(output_item.buffer, 'OlloumaGenStop', stop, {})
        end
        if prompt_item.buffer then
            vim.api.nvim_buf_create_user_command(prompt_item.buffer, 'OlloumaGenStop', stop, {})
        end
    end

    local ollouma_send_buffer_command = {
        command_name = 'OlloumaSend',
        rhs = send_chat_from_prompt,
        opts = {},
    }

    local prompt_item = split_ui:create_ui_item(
        chat_ui_item_ids.PROMPT,
        ui_utils.OlloumaSplitKind.RIGHT,
        {
            display_name = 'PROMPT [' .. opts.title .. ']',
            split_size = 0.4,
            buffer_commands = {
                ollouma_send_buffer_command,
            },
            buffer_keymaps = {
                {
                    lhs = '<leader>os', rhs = ':OlloumaSend<CR>',
                },
            },
        }
    )
    local _ = split_ui:create_ui_item(
        chat_ui_item_ids.OUTPUT,
        ui_utils.OlloumaSplitKind.BOTTOM,
        {
            display_name = 'OUTPUT [' .. opts.title .. ']',
            split_size = CHAT_OUTPUT_SPLIT_SIZE,
            filetype = CHAT_OUTPUT_FILETYPE,
            buftype = 'acwrite',
            buffer_commands = { ollouma_send_buffer_command, },
            buffer_autocommands = {
                {
                    event = 'BufWriteCmd',
                    callback = function(opts)
                        local namespace_id = ui_utils.namespace_id
                        local extmarks = vim.api.nvim_buf_get_extmarks(
                            opts.buf,
                            namespace_id,
                            0, -1,
                            {}
                        )
                        ---@type OlloumaChatMessageDto[]
                        local parsed_messages = {
                        }
                        for index = 1, #extmarks do
                            local extmark = extmarks[index]
                            local next_extmark = extmarks[index + 1]
                            local extmark_row = extmark[2]
                            local message_start = extmark_row + 1
                            local message_end = -1
                            if next_extmark then
                                local next_extmark_row = next_extmark[2]
                                message_end = next_extmark_row
                            end

                            local lines = vim.api.nvim_buf_get_lines(
                                opts.buf,
                                message_start,
                                message_end,
                                false
                            )
                            local role_line = vim.api.nvim_buf_get_lines(
                                opts.buf,
                                extmark_row,
                                extmark_row + 1,
                                true
                            )[1]
                            -- remove trailing ":"
                            local display_role = string.sub(role_line, 0, #role_line - 1)
                            ---@type OlloumaChatMessageDto
                            local message = {
                                role = chat.OlloumaChatRole.from_display_role(display_role),
                                content = vim.fn.join(lines, '\n')
                            }
                            table.insert(parsed_messages, message)
                            -- log.info(message_start, message_end, 'TODO: line = ', vim.inspect(lines))
                        end


                        messages = parsed_messages
                        require('ollouma.util.polyfill.options').buf_set_option(
                            'modified',
                            false,
                            { buf = opts.buf }
                        )
                        log.info('updated chat history for ' .. #messages .. ' message(s)') --, vim.inspect(parsed_messages))
                    end
                }
            },
        }
    )

    prompt_item:open({ set_current_window = true })

    return split_ui
end

return M
