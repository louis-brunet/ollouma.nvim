---@class OlloumaChatMessageDto
---@field role OlloumaChatRole
---@field content string
---@field images nil

---@class OlloumaChatRequestDto
---@field model string
---@field messages OlloumaChatMessageDto[]
---@field format 'json'|nil
---@field keep_alive string|nil default is 5m
---@field options OlloumaRequestOptionsDto|nil
---@field stream boolean|nil

---@class OlloumaChatSendOptions
---@field payload OlloumaChatRequestDto
---@field api_url string|nil
---@field on_api_error nil|fun(api_error: OlloumaApiError): nil
---@field on_message_chunk nil|fun(message_chunk: OlloumaChatMessageDto): nil
---@field on_message_end nil|fun(response: OlloumaChatResponseChunkDto): nil
---@field on_message_start nil|fun(response: OlloumaChatResponseChunkDto): nil


---@class OlloumaChatModule
local M = {
    ---@enum OlloumaChatRole
    OlloumaChatRole = {
        SYSTEM = 'system',
        USER = 'user',
        ASSISTANT = 'assistant',
    }
}

---@param display_role string
---@return OlloumaChatRole
function M.OlloumaChatRole.from_display_role(display_role)
    return display_role
end

-- ---@param role OlloumaChatRole
-- ---@return string
-- function M.OlloumaChatRole.to_display_role(role)
--     return role
-- end

---@param opts OlloumaChatSendOptions
---@return function api_stop_generation
function M.send_chat(opts)
    local api = require('ollouma.util.api-client')
    local config = require('ollouma').config
    local log = require('ollouma.util.log')
    opts = opts or {}

    vim.validate({
        payload = { opts.payload, { 'table' } },
        model = { opts.payload.model, 'string' },
        messages = { opts.payload.messages, { 'table' } },
        api_url = { opts.api_url, { 'string', 'nil' } },
        on_api_error = { opts.on_api_error, { 'function', 'nil' } },
        on_message_chunk = { opts.on_message_chunk, { 'function', 'nil' } },
        on_message_end = { opts.on_message_end, { 'function', 'nil' } },
        on_message_start = { opts.on_message_start, { 'function', 'nil' } },
    })

    if opts.payload.options ~= nil and #vim.tbl_keys(opts.payload.options) == 0 then
        opts.payload.options = nil
    end

    local is_first_response_chunk = true
    local api_stop_generation = api.stream_response(
        opts.api_url or config.api.chat_url,

        opts.payload,

        {
            ---@param response OlloumaChatResponseChunkDto
            on_response_chunk = function(response)
                if is_first_response_chunk then
                    if opts.on_message_start then
                        opts.on_message_start(response)
                    end
                    is_first_response_chunk = false
                end

                -- TODO: validation

                -- vim.validate({
                --     response = { response.response, { 'string' } }
                -- })

                if opts.on_message_chunk then
                    opts.on_message_chunk(response.message)
                end

                if response.done then
                    if opts.on_message_end then
                        opts.on_message_end(response)
                    end
                end
            end,

            on_error = function(api_error)
                log.debug('[ollouma.chat.send_chat] api error ', vim.inspect(api_error))

                if opts.on_api_error then
                    opts.on_api_error(api_error)
                end
            end
        }
    )

    return api_stop_generation
end

return M
