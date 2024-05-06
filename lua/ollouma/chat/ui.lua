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
    local util = require('ollouma.util')
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

    ---@param prompt string[]
    ---@param resolve fun():nil
    local function send_chat_from_prompt(prompt, resolve)
        local output_item = split_ui:get_ui_item(chat_ui_item_ids.OUTPUT)
        local prompt_item = split_ui:get_ui_item(chat_ui_item_ids.PROMPT)

        local role_text = chat.OlloumaChatRole.USER .. ':\n'

        local function remove_gen_stop_command()
            if output_item.buffer then
                vim.api.nvim_buf_del_user_command(output_item.buffer, 'OlloumaGenStop')
            end
            if prompt_item.buffer then
                vim.api.nvim_buf_del_user_command(prompt_item.buffer, 'OlloumaGenStop')
            end
        end
        local function on_message_end_or_interrupt()
            require('ollouma.util.polyfill.options').buf_set_option(
                'modified',
                false,
                { buf = output_item.buffer }
            )

            remove_gen_stop_command()
            resolve()
        end

        ---@type string|nil
        local current_message = nil
        -- ---@type {}|nil TODO: type
        -- local current_message_header_extmark = nil

        ---@class OlloumaExtmarkPosition
        ---@field row integer
        ---@field col integer

        ---@type integer|nil
        local content_extmark_id = nil
        ---@type OlloumaExtmarkPosition|nil
        local content_extmark_start = nil
        ---@type OlloumaExtmarkPosition|nil
        local content_extmark_end = nil

        local function start_content_extmark()
            content_extmark_start = util.buf_end_row_col(output_item.buffer)
        end

        local function end_content_extmark()
            content_extmark_id = nil
            content_extmark_start = nil
            content_extmark_end = nil
        end

        local function update_content_extmark_to_buf_end()
            if not content_extmark_start then
                error('need to set content_extmark_start')
            end
            content_extmark_end = require('ollouma.util').buf_end_row_col(output_item.buffer)

            content_extmark_id = output_item:set_extmark(
                content_extmark_start.row,
                content_extmark_start.col,
                {
                    id = content_extmark_id,
                    hl_group = ui_utils.highlight_groups.chat_content,
                    end_row = content_extmark_end.row,
                    end_col = content_extmark_end.col,
                    hl_eol = true,
                    invalidate = true,
                }
            )

            log.trace('[update_content_extmark_to_buf_end] set highlight extmark for message content')
        end

        output_item:open({ set_current_window = false })
        output_item:write(role_text, {
            hl_eol = true,
            hl_group = ui_utils.highlight_groups.chat_role,
        })
        start_content_extmark()
        output_item:write_lines(prompt, { disable_first_newline = true })
        output_item:write('\n')
        -- output_item:lock()
        update_content_extmark_to_buf_end()
        end_content_extmark()

        table.insert(
            messages,
            {
                role = chat.OlloumaChatRole.USER,
                content = table.concat(prompt, '\n')
            }
        )

        output_item:show_loading_indicator()

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
                output_item:hide_loading_indicator()

                if api_error.reason == OlloumaApiErrorReason.CONNECTION_FAILED then
                    log.error('Could not connect to ollama server @ ' .. opts.api_url)
                else
                    log.error('API error: ' .. vim.inspect(api_error))
                end

                output_item:show_error(api_error)

                on_message_end_or_interrupt()
            end,
            on_message_start = function(message_chunk)
                current_message = ''
                output_item:hide_loading_indicator()

                -- output_item:unlock()
                output_item:write(
                    message_chunk.message.role .. ':\n',
                    {
                        hl_eol = true,
                        hl_group = ui_utils.highlight_groups.chat_role,
                    }
                )
                -- output_item:lock()
                start_content_extmark()
            end,
            on_message_chunk = function(message_chunk)
                current_message = current_message .. message_chunk.content
                -- output_item:unlock()
                output_item:write(message_chunk.content)
                -- output_item:lock()
                update_content_extmark_to_buf_end()
            end,
            on_message_end = function()
                table.insert(
                    messages,
                    {
                        role = chat.OlloumaChatRole.ASSISTANT,
                        content = current_message,
                    }
                )
                -- output_item:unlock()
                output_item:write_lines({
                    --     '<!-- message end -->',
                    ''
                })
                -- output_item:lock()

                update_content_extmark_to_buf_end()
                end_content_extmark()

                -- if not content_extmark_start then
                --     log.error('[on_message_end] content_extmark_start is nil')
                -- else
                --     content_extmark_end = require('ollouma.util').buf_end_row_col(output_item.buffer)
                --     output_item:set_extmark(
                --         content_extmark_start.row,
                --         content_extmark_start.col,
                --         {
                --             id = content_extmark_id,
                --             hl_group = ui_utils.highlight_groups.chat_content,
                --             end_row = content_extmark_end.row,
                --             end_col = content_extmark_end.col,
                --             hl_eol = true,
                --         }
                --     )
                --     log.trace('[on_message_end] set highlight extmark for message content')
                -- end

                on_message_end_or_interrupt()
            end,
        })

        local function stop()
            stop_generation()
            -- output_item:unlock()
            output_item:write_lines({ '<!---- INTERRUPTED --->', '' })
            -- output_item:lock()
            on_message_end_or_interrupt()
        end

        if output_item.buffer then
            vim.api.nvim_buf_create_user_command(output_item.buffer, 'OlloumaGenStop', stop, {})
        end
        if prompt_item.buffer then
            vim.api.nvim_buf_create_user_command(prompt_item.buffer, 'OlloumaGenStop', stop, {})
        end
    end

    local message_queue = require('ollouma.util.queue').OlloumaAsyncQueue:new()

    local ollouma_send_buffer_command = {
        command_name = 'OlloumaSend',
        rhs = function()
            local prompt_item = split_ui:get_ui_item(chat_ui_item_ids.PROMPT)
            local prompt = prompt_item:get_lines()

            message_queue:enqueue(
                function(resolve)
                    send_chat_from_prompt(prompt, resolve)
                end,
                {
                    on_wait_start = function ()
                        log.info('Added message to queue')
                    end
                }
            )
        end,
        opts = {},
    }

    local prompt_item = split_ui:create_ui_item(
        chat_ui_item_ids.PROMPT,
        ui_utils.OlloumaSplitKind.RIGHT,
        {
            display_name = 'PROMPT [' .. opts.title .. ']',
            -- split_size = 0.4,
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
                    -- FIXME: this function appends the loading/error/interrupted
                    -- indicators to messages, which is not consistent with how
                    -- the chat works when this function is never called.
                    callback = function(opts)
                        local namespace_id = ui_utils.namespace_id
                        local extmarks = vim.api.nvim_buf_get_extmarks(
                            opts.buf,
                            namespace_id,
                            0, -1,
                            { details = true }
                        )
                        ---@type vim.api.keyset.get_extmark_item[]
                        local filtered_extmarks = {}
                        for _, extmark in ipairs(extmarks) do
                            local extmark_details = extmark[4]
                            local extmark_is_valid = not extmark_details.invalid
                            local extmark_hl_group_is_role =
                                extmark_details.hl_group == ui_utils.highlight_groups.chat_role

                            if extmark_is_valid and extmark_hl_group_is_role then
                                table.insert(filtered_extmarks, extmark)
                            end
                        end

                        ---@type OlloumaChatMessageDto[]
                        local parsed_messages = {
                        }
                        for index = 1, #filtered_extmarks do
                            local extmark = filtered_extmarks[index]
                            local next_extmark = filtered_extmarks[index + 1]
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
                        end


                        -- FIXME: this removes any prepended system (or user or assistant) messages
                        messages = parsed_messages
                        require('ollouma.util.polyfill.options').buf_set_option(
                            'modified',
                            false,
                            { buf = opts.buf }
                        )
                        local num_messages = #messages
                        local plural = 's'
                        if num_messages == 1 then
                            plural = ''
                        end
                        log.info('updated chat history for ' .. #messages .. ' message' .. plural) --, vim.inspect(parsed_messages))
                    end
                }
            },
        }
    )

    prompt_item:open({ set_current_window = true })

    return split_ui
end

return M
