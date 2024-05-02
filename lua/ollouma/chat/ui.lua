---@class OlloumaChatOpenedUiMetadata
---@field title string
---@field created_at integer

---@class OlloumaChatUiStartOptions
---@field api_url string|nil
---@field model string|nil
---@field title string


---@type table<OlloumaSplitUi,  OlloumaChatOpenedUiMetadata>
local opened_split_uis = {}


---@class OlloumaChatUi
---@field split_ui OlloumaSplitUi
local M = {
}
M.__index = M

---@class OlloumaChatUiConstructorOptions
---@field api_url string|nil
---@field model string|nil
---@field title string

-- ---@param opts OlloumaChatUiConstructorOptions|nil
-- ---@return OlloumaChatUi
-- function M:new(opts)
--     local config = require('ollouma').config
--     opts = opts or {}
--     vim.validate({
--         api_url = { opts.api_url, { 'string', 'nil' } },
--         model = { opts.model, { 'string', 'nil' } },
--         title = { opts.title, { 'string' } },
--     })
--     opts.api_url = opts.api_url or config.api.chat_url
--     opts.model = opts.model or config.model
--
--
--     local OlloumaSplitUi = require('ollouma.util.ui').OlloumaSplitUi
--     local chat_ui_item_ids = {
--         PROMPT = 'prompt',
--         OUTPUT = 'output',
--     }
--
--     ---@type OlloumaChatUi
--     local chat_ui = {
--         split_ui = OlloumaSplitUi:new({
--             custom_resume_session = function(split_ui)
--                 local prompt_item = split_ui:get_ui_item(chat_ui_item_ids.PROMPT)
--                 local output_item = split_ui:get_ui_item(chat_ui_item_ids.OUTPUT)
--
--                 prompt_item:open({ set_current_window = true })
--                 output_item:open()
--             end,
--
--             on_exit = function(split_ui)
--                 opened_split_uis[split_ui] = nil
--             end,
--         })
--     }
--     opened_split_uis[chat_ui.split_ui] = {
--         title = opts.title,
--         created_at = os.time()
--     }
--
--     return setmetatable(chat_ui, self)
-- end

---@param opts OlloumaChatUiStartOptions|nil
---@return any TODO: return type
function M.start_chat_ui(opts)
    local config = require('ollouma').config
    opts = opts or {}
    vim.validate({
        api_url = { opts.api_url, { 'string', 'nil' } },
        model = { opts.model, { 'string', 'nil' } },
        title = { opts.title, { 'string' } },
    })
    opts.api_url = opts.api_url or config.api.chat_url
    opts.model = opts.model or config.model

    local chat = require('ollouma.chat')
    local log = require('ollouma.util.log')
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
            opened_split_uis[split_ui] = nil
        end,
    })
    opened_split_uis[split_ui] = {
        title = opts.title,
        created_at = os.time()
    }
    ---@type OlloumaChatMessageDto[]
    local messages = {
    }


    local prompt_item = split_ui:create_ui_item(
        chat_ui_item_ids.PROMPT,
        ui_utils.OlloumaSplitKind.LEFT,
        {
            display_name = 'PROMPT [' .. opts.title .. ']',
            buffer_commands = {
                {
                    command_name = 'OlloumaSend',
                    rhs = function()
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
                        output_item:write(chat.OlloumaChatRole.USER .. ':')
                        output_item:write_lines(prompt_item:get_lines())
                        output_item:write('\n')

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
                                -- options = {
                                --     -- temperature = 0.7,
                                -- },
                            },
                            on_api_error = function(api_error)
                                log.error('TODO: handle api error ', vim.inspect(api_error))
                            end,
                            on_message_start = function(message_chunk)
                                current_message = ''
                                output_item:write(message_chunk.message.role .. ':\n')
                            end,
                            on_message_chunk = function(message_chunk)
                                current_message = current_message .. message_chunk.content
                                output_item:write(message_chunk.content)
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
                                output_item:write_lines({
                                    '<!-- message end -->',
                                    ''
                                })
                            end,
                        })

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
        chat_ui_item_ids.OUTPUT,
        ui_utils.OlloumaSplitKind.BOTTOM,
        { display_name = 'OUTPUT [' .. opts.title .. ']' }
    )

    prompt_item:open({ set_current_window = true })

    return split_ui
end

return M
