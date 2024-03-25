---@class OlloumaChatMessageDto
---@field role string
---@field content string
---@field images? string

---@class OlloumaResponseChunkDto
---@field model string
---@field created_at string
---@field done boolean

---@class OlloumaGenerateResponseChunkDto: OlloumaResponseChunkDto
---@field response? string

---@class OlloumaChatResponseChunkDto: OlloumaResponseChunkDto
---@field message? OlloumaChatMessageDto


---@class OlloumaApiCallbacks
---@field on_response_chunk? fun(response: OlloumaResponseChunkDto): nil
-- ---@field on_exit? fun(completed: vim.SystemCompleted): nil

---@alias NullableJsonData (JsonData|nil)
---@alias JsonData string|integer|float|boolean|(NullableJsonData)[]|table<string, NullableJsonData>


-- vim.system added in neovim 0.10 (nightly as of writing this)
local system = vim.system or require('ollouma.util.system')

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
    -- {
    --     model = response_body.model,
    --     created_at = response_body.created_at,
    --     done = response_body.done,
    -- }
end


---@class OlloumaApiClient
local M = {}

-- ---@param reason string
-- local function invalid(reason)
--     ---@type JsonValidatorInvalidResult
--     return { valid = false, error = reason }
-- end


---@return boolean
function M.healthcheck(url)
    local child = system.run({ 'curl', url })
    return child:wait().code == 0
end

---@param url string
---@param json_body JsonData
---@param on_response_chunk? fun(response: OlloumaResponseChunkDto): nil
function M.stream_response(url, json_body, on_response_chunk)
    vim.validate({
        on_response_chunk = { on_response_chunk, 'function' },
        url = { url, 'string' },
    })

    local child = M.post_stream(
        url,
        json_body,
        function(_, stdout_data)
            if not stdout_data or not on_response_chunk then
                return
            end

            ---@type JsonData|nil
            local decoded_json = vim.json.decode(stdout_data)

            -- print('STDOUT: ' .. ((decoded_json or {}).response or "")) -- vim.inspect(decoded_json))
            if not decoded_json then
                error("could not decode JSON output: ''" .. stdout_data .. "'")
                -- TODO: handle json decode error (vim.json.decode
                --       can probably throw an error, need pcall?)
                return
            end

            local validated = validate_response_dto(decoded_json)

            on_response_chunk(validated)
        end,
        function(completed)
            -- TODO: cleanup here ?

            if completed.code ~= 0 then
                error('command execution failed: ' .. completed.stderr)
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

    if not models_result then
        error("no models result")
    end
    if #models_result == 0 then
        error("models result is an empty string")
    end

    local decoded_json = vim.json.decode(models_result)

    -- TODO: validate

    ---@cast decoded_json { models: {model:string}[]}

    ---@type string[]
    local models = {}
    for i, model in ipairs(decoded_json.models) do
        models[i] = model.model
    end

    return models
end

---@return string?
function M.get_sync(url)
    -- local stdout_buf = ""
    local child = M.get_stream(url, nil, function(completed)
        if completed.code ~= 0 then
            error('command execution failed: ' .. completed.stderr)
        end
    end)
    local completed = child:wait()
    return completed.stdout
end

---@private
---@param url string
---@param on_stdout false|nil|fun(err?: string, data?: string): nil
---@param on_exit? fun(out: vim.SystemCompleted): nil
function M.get_stream(url, on_stdout, on_exit)
    return system.run(
        { 'curl', '--no-buffer', '-X', 'GET', url },
        { text = true, stdout = on_stdout },
        on_exit
    )
end

---@private
---@param url string
---@param json_body JsonData
---@param on_stdout false|nil|fun(err?: string, data?: string): nil
---@param on_exit fun(out: vim.SystemCompleted): nil
function M.post_stream(url, json_body, on_stdout, on_exit)
    return system.run(
        {
            'curl',
            '--no-buffer',
            '-X',
            'POST',
            '--data-raw',
            vim.json.encode(json_body),
            url,
        },
        { text = true, stdout = on_stdout },
        on_exit
    )
end

return M
