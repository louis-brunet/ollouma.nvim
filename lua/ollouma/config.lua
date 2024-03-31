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


---@class OlloumaModelActionOptions
---@field visual_selection string|nil

---@class OlloumaModelAction
---@field name string
---@field on_select fun(opts: OlloumaModelActionOptions|nil): nil


--- cmd_opts param is the parameter to the user command function in
--- :h nvim_create_user_command()
---@alias OlloumaSubcommand fun(cmd_opts: table): nil


---@class OlloumaConfig
-- ---@field chat OlloumaChatConfig
---@field model string|nil
---@field api OlloumaApiConfig
---@field model_actions fun(model: string): OlloumaModelAction[]
---@field user_command_subcommands table<string, OlloumaSubcommand>
---@field log_level integer :h vim.log.levels

---@class OlloumaPartialConfig
---@field model string|nil
-- ---@field chat OlloumaPartialChatConfig|nil
---@field api OlloumaPartialApiConfig|nil
---@field model_actions nil|fun(model: string): OlloumaModelAction[]
---@field user_command_subcommands table<string, OlloumaSubcommand>|nil
---@field log_level integer|nil :h vim.log.levels


---@class OlloumaConfigModule
---@field default_config fun(): OlloumaConfig
---@field extend_config fun(current_config?: OlloumaConfig, partial_config?: OlloumaPartialConfig): OlloumaConfig
local M = {}

function M.default_config()
    ---@type OlloumaConfig
    return {
        log_level = vim.log.levels.INFO,

        model = nil,

        -- chat = {
        --     model = 'mistral',
        --     system_prompt = '',
        -- },

        api = {
            generate_url = '127.0.0.1:11434/api/generate',
            chat_url = '127.0.0.1:11434/api/chat',
            models_url = '127.0.0.1:11434/api/tags',
        },

        model_actions = function(model)
            ---@type OlloumaModelAction[]
            return {
                {
                    name = 'Generate',
                    on_select = function(opts)
                        opts = opts or {}

                        require('ollouma.generate.ui').start_interactive_ui(
                            function(prompt)
                                ---@type OlloumaGenerateRequestPayload
                                return {
                                    model = model,
                                    prompt = table.concat(prompt, '\n'),
                                    -- system = 'You MUST only respond with a single JSON object in the format:`{\n  "response": <YOUR RESPONSE>\n}`. Do not write an other explanations.\n',
                                    -- format = 'json',
                                    -- options = {
                                    --     temperature = 0.0,
                                    -- }
                                }
                            end,
                            {
                                title = 'Generate - ' .. model,
                                initial_prompt = opts.visual_selection,
                                show_prompt_in_output = true,
                            }
                        )
                    end
                },
                {
                    name = 'Review',
                    on_select = function(opts)
                        opts = opts or {}

                        local prompt = 'TODO visual selection or error ?'
                        require('ollouma.generate.ui').start_output_only_ui(
                            {
                                model = model,
                                prompt = prompt,
                                system = 'TODO',
                                options = {
                                    temperature = 0,
                                },
                            },
                            {}
                        )
                    end
                },
            }
        end,

        user_command_subcommands = {
            select_action = function(cmd_opts)
                local ollouma = require('ollouma')

                local visual_selection = nil
                if cmd_opts.range == 2 then
                    -- NOTE: the actual position expressions seem to not be
                    -- exposed in lua (line1 and line2 don't give the
                    -- column numbers)
                    -- require('ollouma.util.log').warn('TODO use get_range_text; cmd_opts=', vim.inspect(cmd_opts))
                    visual_selection = require('ollouma.util').get_last_visual_selection()
                end

                ---@type OlloumaModelActionOptions
                local model_action_opts = {
                    visual_selection = visual_selection
                }

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
