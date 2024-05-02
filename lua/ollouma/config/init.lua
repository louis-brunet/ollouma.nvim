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


--- cmd_opts param is the parameter to the user command function in
--- :h nvim_create_user_command()
---@alias OlloumaSubcommand fun(cmd_opts: table, model_action_opts: OlloumaModelActionOptions|nil): nil


---@class OlloumaGenerateInteractivePrompt
---@field action_name string
---@field payload_generator fun(model: string, prompt: string[], model_action_opts: OlloumaModelActionOptions):OlloumaGenerateRequestPayload
---@field require_selection boolean|nil
---@field show_prompt_in_output boolean|nil

---@class OlloumaGenerateOutputOnlyPrompt
---@field action_name string
---@field payload_generator fun(model: string, model_action_opts: OlloumaModelActionOptions):OlloumaGenerateRequestPayload
---@field require_selection boolean|nil
---@field show_prompt_in_output boolean|nil


---@class OlloumaPromptsConfigGenerate
---@field interactive OlloumaGenerateInteractivePrompt[]
---@field output_only OlloumaGenerateOutputOnlyPrompt[]

---@class OlloumaPartialPromptsConfigGenerate
---@field interactive OlloumaGenerateInteractivePrompt[]|nil
---@field output_only OlloumaGenerateOutputOnlyPrompt[]|nil


---@class OlloumaPromptsConfig
---@field generate OlloumaPromptsConfigGenerate

---@class OlloumaPartialPromptsConfig
---@field generate OlloumaPartialPromptsConfigGenerate|nil


---@class OlloumaConfig
-- ---@field chat OlloumaChatConfig
---@field model string|nil
---@field api OlloumaApiConfig
---@field prompts OlloumaPromptsConfig
---@field model_actions fun(model: string, model_action_opts: OlloumaModelActionOptions|nil): OlloumaModelAction[]
---@field user_command_subcommands table<string, OlloumaSubcommand>
---@field log_level integer :h vim.log.levels

---@class OlloumaPartialConfig
---@field model string|nil
-- ---@field chat OlloumaPartialChatConfig|nil
---@field api OlloumaPartialApiConfig|nil
---@field prompts OlloumaPartialPromptsConfig|nil
---@field model_actions nil|fun(model: string, model_action_opts: OlloumaModelActionOptions|nil): OlloumaModelAction[]
---@field user_command_subcommands table<string, OlloumaSubcommand>|nil
---@field log_level integer|nil :h vim.log.levels


---@type OlloumaPromptsConfig
local default_prompts = {
    generate = {
        interactive = {
            {
                action_name = 'Generate',
                payload_generator = function(model, prompt, _)
                    ---@type OlloumaGenerateRequestPayload
                    return {
                        model = model,
                        prompt = table.concat(prompt, '\n'),
                    }
                end,
                -- require_selection = false,
                show_prompt_in_output = true,
            },

            {
                action_name = 'Generate JSON (TODO: set output filetype + custom output separator?)',
                payload_generator = function(model, prompt, _)
                    ---@type OlloumaGenerateRequestPayload
                    return {
                        model = model,
                        prompt = table.concat(prompt, '\n'),
                        system = 'Respond to the following message with a single JSON-formatted object.',
                        format = 'json',
                        options = {
                            temperature = 0.0,
                        }
                    }
                end,
                -- require_selection = false,
                -- show_prompt_in_output = false,
            },
        },

        output_only = {
            {
                action_name = 'Review code (visual mode)',
                payload_generator = function(model, model_action_opts)
                    local filetype_sentence = ''

                    if model_action_opts.filetype then
                        filetype_sentence = string.format(
                            ' (filetype=%s)',
                            model_action_opts.filetype
                        )
                    end

                    ---@type OlloumaGenerateRequestPayload
                    return {
                        model = model,
                        prompt = model_action_opts.visual_selection,
                        system = 'Please review the following code snippet and list any improvements to be made.'
                            .. ' Only give relevant suggestions with performant implementations.'
                            -- .. ' Keep in mind that this code it is part of a larger codebase.'
                            .. ' Here is the code snippet' .. filetype_sentence .. ': ',
                        options = {
                            temperature = 0.8,
                        },
                    }
                end,
                require_selection = true,
                show_prompt_in_output = false,
            },
        }
    },
}


---@class OlloumaConfigModule
---@field default_config fun(): OlloumaConfig
---@field extend_config fun(current_config?: OlloumaConfig, partial_config?: OlloumaPartialConfig): OlloumaConfig
local M = {}

function M.default_config()
    local default_base_url = '127.0.0.1:11434'

    ---@type OlloumaConfig
    return {
        log_level = vim.log.levels.TRACE,

        model = nil,

        -- chat = {
        --     model = 'mistral',
        --     system_prompt = '',
        -- },

        api = {
            generate_url = default_base_url .. '/api/generate',
            chat_url = default_base_url .. '/api/chat',
            models_url = default_base_url .. '/api/tags',
        },

        prompts = default_prompts,

        model_actions = function(model, model_action_opts)
            model_action_opts = model_action_opts or {}
            local prompts = require('ollouma').config.prompts
            local model_actions = require('ollouma.config.model-action')

            return {
                ---@type OlloumaModelAction
                {
                    name = 'Chat',
                    on_select = function ()
                        require('ollouma.chat.ui').start_chat_ui({ model = model, title = 'chat - ' .. model })
                    end
                },
                unpack(model_actions.from_prompt_config(prompts, model, model_action_opts)),
            }
        end,

        user_command_subcommands = {
            ollouma = function(_, model_action_opts)
                local ollouma = require('ollouma')
                ollouma.start(model_action_opts)
            end,

            select_action = function(_, model_action_opts)
                local ollouma = require('ollouma')

                if ollouma.config.model then
                    ollouma.select_model_action(ollouma.config.model, model_action_opts)
                else
                    ollouma.start(model_action_opts)
                end
            end,

            resume = function()
                require('ollouma').resume_session()
            end,

            exit = function()
                require('ollouma').exit_session()
            end,
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
