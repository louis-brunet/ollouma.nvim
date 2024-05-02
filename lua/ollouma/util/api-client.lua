-- ---@class OlloumaChatMessageDto
-- ---@field role string
-- ---@field content string
-- ---@field images? string

--- Full list: https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values
--- (permalink as of writing this: https://github.com/ollama/ollama/blob/e1f1c374ea3033d55e4975fbb60a5873f716b8ba/docs/modelfile.md#valid-parameters-and-values)
---@class OlloumaRequestOptionsDto
---@field num_ctx integer|nil Sets the size of the context window used to generate the next token. (Default: 2048)
---@field num_predict integer|nil Maximum number of tokens to predict when generating text. (Default: 128, -1 = infinite generation, -2 = fill context)
---@field repeat_penalty float|nil Sets how strongly to penalize repetitions. A higher value (e.g., 1.5) will penalize repetitions more strongly, while a lower value (e.g., 0.9) will be more lenient. (Default: 1.1)
---@field seed integer|nil Sets the random number seed to use for generation. Setting this to a specific number will make the model generate the same text for the same prompt. (Default: 0)
---@field temperature float|nil The temperature of the model. Increasing the temperature will make the model answer more creatively. (Default: 0.8)
---@field tfs_z float|nil Tail free sampling is used to reduce the impact of less probable tokens from the output. A higher value (e.g., 2.0) will reduce the impact more, while a value of 1.0 disables this setting. (default: 1)
---@field top_k int|nil Reduces the probability of generating nonsense. A higher value (e.g. 100) will give more diverse answers, while a lower value (e.g. 10) will be more conservative. (Default: 40)
---@field top_p float|nil Works together with top-k. A higher value (e.g., 0.95) will lead to more diverse text, while a lower value (e.g., 0.5) will generate more focused and conservative text. (Default: 0.9)


---@class OlloumaResponseChunkDto
---@field model string
---@field created_at string
---@field done boolean

---@class OlloumaGenerateResponseChunkDto: OlloumaResponseChunkDto
---@field response? string

---@class OlloumaChatResponseChunkDto: OlloumaResponseChunkDto
---@field message? OlloumaChatMessageDto

---@enum OlloumaApiErrorReason
local OlloumaApiErrorReason = {
    -- cURL errors
    UNSUPPORTED_PROTOCOL = 'protocol',
    URL_MALFORMED = 'url',
    RESOLVE_PROXY = 'resolve_proxy',
    RESOLVE_HOST = 'resolve_host',
    CONNECTION_FAILED = 'connection',
    PARSE_HTTP = 'parse_http',

    -- App errors
    -- PARSE_JSON = 'parse_json',

    UNKNOWN_ERROR = 'unknown'
}

local curl_status_codes = {
    [1] = OlloumaApiErrorReason.UNSUPPORTED_PROTOCOL,
    [3] = OlloumaApiErrorReason.URL_MALFORMED,
    [5] = OlloumaApiErrorReason.RESOLVE_PROXY,
    [6] = OlloumaApiErrorReason.RESOLVE_HOST,
    [7] = OlloumaApiErrorReason.CONNECTION_FAILED,
    [8] = OlloumaApiErrorReason.PARSE_HTTP,
}

---@param status_code integer
---@param stderr string|nil
---@return OlloumaApiError|nil
local function curl_status_code_to_api_error(status_code, stderr)
    if status_code == 0 or status_code == nil then
        return nil
    end

    ---@type OlloumaApiErrorReason|nil
    local reason = curl_status_codes[status_code]

    if reason == nil then
        reason = OlloumaApiErrorReason.UNKNOWN_ERROR
    end

    ---@type OlloumaApiError
    return {
        reason = reason,
        stderr = stderr
    }
end

---@class OlloumaApiError
---@field reason OlloumaApiErrorReason
---@field stderr string|nil

---@class OlloumaApiStreamCallbacks
---@field on_response_chunk nil|fun(response: OlloumaResponseChunkDto): nil
---@field on_error nil|fun(error: OlloumaApiError): nil
-- ---@field on_exit? fun(completed: vim.SystemCompleted): nil

---@alias NullableJsonData (JsonData|nil)
---@alias JsonData string|integer|float|boolean|(NullableJsonData)[]|table<string, NullableJsonData>



-- vim.system added in neovim 0.10 (nightly as of writing this)
local system = vim.system or require('ollouma.util.polyfill.system').run

---@param response_body JsonData
---@return OlloumaResponseChunkDto
local function validate_response_dto(response_body)
    vim.validate({
        model = { response_body.model, 'string' },
        created_at = { response_body.created_at, 'string' },
        done = { response_body.done, 'boolean' },
    })
    ---@type OlloumaResponseChunkDto
    return response_body
end


---@class OlloumaApiClient
local M = {}

---@param url string
---@param json_body JsonData
---@param callbacks OlloumaApiStreamCallbacks|nil
function M.stream_response(url, json_body, callbacks)
    callbacks = callbacks or {}
    vim.validate({
        on_response_chunk = { callbacks.on_response_chunk, { 'function' } },
        on_error = { callbacks.on_error, { 'function', 'nil' } },
        url = { url, 'string' },
    })

    local child = M.post_stream(
        url,
        json_body,
        function(_, stdout_data)
            if not stdout_data or not callbacks.on_response_chunk then
                return
            end

            ---@type boolean, JsonData|nil
            local ok, decoded_json = pcall(vim.json.decode, stdout_data)

            -- print('STDOUT: ' .. ((decoded_json or {}).response or "")) -- vim.inspect(decoded_json))
            if not ok or not decoded_json then
                error("could not decode JSON output: ''" .. stdout_data .. "'")
                return
            end

            local validated = validate_response_dto(decoded_json)

            vim.schedule(function() callbacks.on_response_chunk(validated) end)
        end,
        function(completed)
            -- TODO: cleanup here ?

            if completed.code ~= 0 then
                local api_error = curl_status_code_to_api_error(completed.code, completed.stderr)
                if api_error and callbacks.on_error then
                    vim.schedule(function() callbacks.on_error(api_error) end)
                else
                    local e = vim.fn.printf('command execution failed (%s): %s', (api_error or {}).reason or '', completed.stderr)
                    error(e)
                end
            end
        end
    )

    return function()
        child:kill(9)
    end
end

---@param url string
function M.find_all_models(url)
    local models_result = M.get_sync(url)

    vim.validate({ models_result = { models_result, 'string' } })

    ---@type string[]
    local models = {}

    if not models_result then
        return models
    end
    if #models_result == 0 then
        return models
    end

    local decoded_json = vim.json.decode(models_result)

    -- TODO: validate

    ---@cast decoded_json { models: {model:string}[]}

    for i, model in ipairs(decoded_json.models) do
        models[i] = model.model
    end

    return models
end

---@private
---@return string|nil
function M.get_sync(url)
    local child = M.get_stream(url)
    local completed = child:wait()

    if completed.code ~= 0 then
        local error_msg = 'command exited with status code ' .. completed.code .. ':\n' .. completed.stderr
        require('ollouma.util.log').error(error_msg)
        -- error(error_msg)
    end

    return completed.stdout
end

---@private
---@param url string
---@param on_stdout false|nil|fun(err?: string, data?: string): nil
---@param on_exit? fun(out: vim.SystemCompleted): nil
function M.get_stream(url, on_stdout, on_exit)
    local ok, res = pcall(
        system,
        { 'curl', '--no-buffer', '-X', 'GET', url },
        { text = true, stdout = on_stdout },
        on_exit
    )

    if not ok then
        error('could not run cURL command: ' .. res)
    end

    return res
end

---@private
---@param url string
---@param json_body JsonData
---@param on_stdout false|nil|fun(err?: string, data?: string): nil
---@param on_exit fun(out: vim.SystemCompleted): nil
function M.post_stream(url, json_body, on_stdout, on_exit)
    local log = require('ollouma.util.log')
    local json_encoded_body = vim.json.encode(json_body)
    log.trace('POST ' .. url .. '\n' .. json_encoded_body)

    local ok, res = pcall(
        system,
        {
            'curl',
            '--no-buffer',
            '-X',
            'POST',
            '--data-raw',
            json_encoded_body,
            url,
        },
        { text = true, stdout = on_stdout },
        on_exit
    )

    if not ok then
        error('could not run cURL command: ' .. res)
    end

    return res
end

return M
