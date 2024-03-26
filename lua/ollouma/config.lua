-- ---@class OlloumaChatConfig
-- ---@field model string
-- ---@field system_prompt string

-- ---@class OlloumaPartialChatConfig
-- ---@field model? string
-- ---@field system_prompt? string


---@class OlloumaApiConfig
---@field generate_url string
---@field chat_url string
---@field models_url string

---@class OlloumaPartialApiConfig
---@field generate_url? string
---@field chat_url? string
---@field models_url? string


---@class OlloumaModelActionConfig
---@field name string
---@field on_select fun(current_model: string): nil


-- ---@class OlloumaSubcommandConfig
-- ---@field run fun(): nil
---@alias OlloumaSubcommand fun(): nil


---@class OlloumaConfig
-- ---@field chat OlloumaChatConfig
---@field api OlloumaApiConfig
---@field model_actions fun(model: string): OlloumaModelActionConfig[]
---@field user_command_subcommands table<string, OlloumaSubcommand>

---@class OlloumaPartialConfig
-- ---@field chat? OlloumaPartialChatConfig
---@field api? OlloumaPartialApiConfig
---@field model_actions? OlloumaModelActionConfig[]
---@field user_command_subcommands? table<string, OlloumaSubcommand>


---@class OlloumaConfigModule
---@field default_config fun(): OlloumaConfig
---@field extend_config fun(current_config?: OlloumaConfig, partial_config?: OlloumaPartialConfig): OlloumaConfig
local M = {}

function M.default_config()
    ---@type OlloumaConfig
    return {
        -- chat = {
        --     model = 'mistral',
        --     system_prompt = '', -- TODO: chat + system prompt
        -- },

        api = {
            generate_url = '127.0.0.1:11434/api/generate',
            chat_url = '127.0.0.1:11434/api/chat',
            models_url = '127.0.0.1:11434/api/tags',
        },

        model_actions = function(model)
            ---@type OlloumaModelActionConfig[]
            return {
                {
                    name = 'Generate',
                    on_select = function()
                        require('ollouma.generate').start_generate_ui(model)
                    end
                },
            }
        end,

        user_command_subcommands = {
            start = function()
                require('ollouma').start()
            end,

            resume = function()
                require('ollouma').resume_session()
            end,

            exit = function()
                require('ollouma').exit_session()
            end,

            -- last = function()
            --     require('ollouma').last_model_action()
            -- end,

            -- empty = function()
            --     require('ollouma.generate.ui'):empty_buffers()
            -- end,
            --
            -- close = function()
            --     require('ollouma.generate.ui'):close()
            -- end,
        },
    }
end

--- Extend the current config with the given partial config. If the current
--- config is nil, then use default settings as the current config.
function M.extend_config(current_config, partial_config)
    current_config = current_config or M.default_config()
    if not partial_config then
        return current_config
    end

    return vim.tbl_deep_extend('force', current_config, partial_config)
end

return M
