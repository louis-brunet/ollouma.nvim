--- https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values
---@class OlloumaGenerateRequestPayloadOptions
---@field temperature float The temperature of the model. Increasing the temperature will make the model answer more creatively. (Default: 0.8)
---@field num_predict integer Maximum number of tokens to predict when generating text. (Default: 128, -1 = infinite generation, -2 = fill context)
---@field seed integer Sets the random number seed to use for generation. Setting this to a specific number will make the model generate the same text for the same prompt. (Default: 0)

--- https://github.com/ollama/ollama/blob/main/docs/api.md#parameters
---@class OlloumaGenerateRequestPayload
---@field model string (required) the model name
---@field prompt string the prompt to generate a response for
---@field options OlloumaGenerateRequestPayloadOptions|nil additional model parameters listed in the documentation for the Modelfile such as temperature
---@field system string|nil system message to (overrides what is defined in the Modelfile)
---@field format 'json'|nil the format to return a response in. Currently the only accepted value is json
---@field template string|nil the prompt template to use (overrides what is defined in the Modelfile)
---@field stream boolean|nil if false the response will be returned as a single response object, rather than a stream of objects
---@field keep_alive string|nil controls how long the model will stay loaded into memory following the request (default: 5m)

---@class OlloumaGenerateOptions
---@field payload OlloumaGenerateRequestPayload
---@field api_url string
---@field on_response fun(partial_response: string): nil
---@field on_response_end fun(): nil only called when the response is finished, not when it is prematurely aborted by the user

---@class OlloumaGenerateModule
local M = {}

---@param opts OlloumaGenerateOptions
---@return fun():nil stop_generation function to call when generation should be halted
function M.start_generation(opts)
    vim.validate({
        payload = { opts.payload, { 'table' } },
        model = { opts.payload.model, 'string' },
        prompt = { opts.payload.prompt, { 'string' } },
        system = { opts.payload.system, { 'string', 'nil' } },
        api_url = { opts.api_url, 'string' },
        on_response = { opts.on_response, 'function' },
        on_response_end = { opts.on_response_end, 'function' },
    })

    local api = require('ollouma.util.api-client')
    -- local log = require('ollouma.util.log')
    -- local prompt = opts.prompt
    --
    -- if not prompt or #prompt == 0 then
    --     prompt = vim.fn.input({ prompt = 'Prompt [' .. opts.model .. ']: ', text = "n" })
    --
    --     if not prompt or #prompt == 0 then
    --         log.debug('empty prompt, aborting')
    --         return function() end
    --     end
    -- end

    local api_stop_generation = api.stream_response(
        opts.api_url,

        opts.payload,

        ---@param response OlloumaGenerateResponseChunkDto
        function(response)
            if response.done then
                if opts.on_response_end then
                    vim.schedule(opts.on_response_end)
                end

                -- TODO: any cleanup/final actions ? (note: should also be done in wrapper func around api_stop_generation)
                return
            end

            vim.schedule(function()
                opts.on_response(response.response)
            end)
        end
    )

    return api_stop_generation
    -- return function()
    --     api_stop_generation()
    -- end
end

return M
