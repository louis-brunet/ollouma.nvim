---@class OlloumaGenerateOptions
---@field model string
---@field prompt string|nil
---@field api_url string
---@field on_response fun(partial_response: string): nil
---@field on_response_end fun(): nil only called when the response is finished, not when it is prematurely aborted by the user

---@class OlloumaGenerateUiOptions
---@field api_url string|nil
---@field initial_prompt string|nil

---@class OlloumaGenerateModule
local M = {}

---@param opts OlloumaGenerateOptions
---@return fun():nil stop_generation function to call when generation should be halted
function M.start_generation(opts)
    vim.validate({
        model = { opts.model, 'string' },
        prompt = { opts.prompt, { 'string', 'nil' } },
        api_url = { opts.api_url, 'string' },
        on_response = { opts.on_response, 'function' },
        on_response_end = { opts.on_response_end, 'function' },
    })

    local api = require('ollouma.util.api-client')
    local log = require('ollouma.util.log')
    local prompt = opts.prompt

    if not prompt or #prompt == 0 then
        prompt = vim.fn.input({ prompt = 'Prompt [' .. opts.model .. ']: ', text = "n" })

        if not prompt or #prompt == 0 then
            log.warn('empty prompt, aborting')
            return function() end
        end
    end

    local api_stop_generation = api.stream_response(
        opts.api_url,

        { model = opts.model, prompt = prompt },

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

---@param model string
---@param opts OlloumaGenerateUiOptions|nil
---@return OlloumaSplitUi split_ui
function M.start_generate_ui(model, opts)
    local config = require('ollouma').config
    local gen_ui = require('ollouma.generate.ui')

    opts = opts or {}
    local api_url = opts.api_url or config.api.generate_url

    vim.validate({
        model = { model, 'string' },
        api_url = { api_url, { 'string' } },
        initial_prompt = { opts.initial_prompt, { 'string', 'nil' } },
    })

    return gen_ui.start_ui(model, api_url, opts.initial_prompt)
end

return M
