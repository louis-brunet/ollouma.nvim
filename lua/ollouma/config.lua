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
---@field model_actions fun(model: string, model_action_opts: OlloumaModelActionOptions|nil): OlloumaModelAction[]
---@field user_command_subcommands table<string, OlloumaSubcommand>
---@field log_level integer :h vim.log.levels

---@class OlloumaPartialConfig
---@field model string|nil
-- ---@field chat OlloumaPartialChatConfig|nil
---@field api OlloumaPartialApiConfig|nil
---@field model_actions nil|fun(model: string): OlloumaModelAction[]
---@field user_command_subcommands table<string, OlloumaSubcommand>|nil
---@field log_level integer|nil :h vim.log.levels

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

local default_prompts = {
    generate = {
        ---@type OlloumaGenerateInteractivePrompt[]
        interactive = {
            {
                action_name = 'Generate',
                payload_generator = function(model, prompt, _)
                    ---@type OlloumaGenerateRequestPayload
                    return {
                        model = model,
                        prompt = table.concat(prompt, '\n'),
                        -- system = 'Respond only with valid JSON.',
                        -- format = 'json',
                        -- options = {
                        --     temperature = 0.0,
                        -- }
                    }
                end,
                require_selection = false,
                show_prompt_in_output = true,
            },
        },
        ---@type OlloumaGenerateOutputOnlyPrompt[]
        output_only = {
            {
                action_name = 'Review',
                payload_generator = function(model, model_action_opts)
                    local filetype_sentence = ''
                    if model_action_opts.visual_selection then
                        local filetype = vim.api.nvim_buf_get_option(0, 'ft')
                        if filetype then
                            filetype_sentence =
                                ' My IDE has detected that this file is written in "' ..
                                filetype .. '".'
                        end
                    end

                    ---@type OlloumaGenerateRequestPayload
                    return {
                        model = model,
                        prompt = model_action_opts.visual_selection,
                        system = 'You are an expert programmer. Please review' ..
                            'the following code and list possible improvements.' ..
                            'This code was taken directly from my IDE and is part of a larger codebase.' ..
                            filetype_sentence,
                        options = {
                            temperature = 0,
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

        model_actions = function(model, model_action_opts)
            local generate_ui = require('ollouma.generate.ui')
            model_action_opts = model_action_opts or {}
            ---@type OlloumaModelAction[]
            local actions = {}

            for _, interactive_prompt in ipairs(default_prompts.generate.interactive) do
                local missing_selection =
                    model_action_opts.visual_selection == nil and interactive_prompt.require_selection

                if not missing_selection then
                    ---@type OlloumaModelAction
                    local new_action = {
                        name = interactive_prompt.action_name,
                        on_select = function()
                            -- opts = opts or {}

                            local title = interactive_prompt.action_name .. ' - ' .. model

                            generate_ui.start_interactive_ui(
                                function(prompt)
                                    return interactive_prompt.payload_generator(
                                        model,
                                        prompt,
                                        model_action_opts
                                    )
                                end,
                                {
                                    title = title,
                                    initial_prompt = model_action_opts.visual_selection,
                                    show_prompt_in_output = interactive_prompt.show_prompt_in_output,
                                }
                            )
                        end,
                    }

                    table.insert(actions, new_action)
                end
            end

            for _, output_only_prompt in ipairs(default_prompts.generate.output_only) do
                local missing_selection =
                    model_action_opts.visual_selection == nil and output_only_prompt.require_selection

                if not missing_selection then
                    ---@type OlloumaModelAction
                    local new_action = {
                        name = output_only_prompt.action_name,
                        on_select = function()
                            -- opts = opts or {}

                            local payload = output_only_prompt.payload_generator(
                                model,
                                model_action_opts
                            )
                            local title = output_only_prompt.action_name .. ' - ' .. model

                            generate_ui.start_output_only_ui(
                                payload,
                                title,
                                {
                                    show_prompt_in_output = output_only_prompt.show_prompt_in_output,
                                }
                            )
                        end,
                    }

                    table.insert(actions, new_action)
                end
            end

            return actions
        end,

        user_command_subcommands = {
            ollouma = function(cmd_opts)
                local ollouma = require('ollouma')

                local visual_selection = nil
                if cmd_opts.range == 2 then
                    -- NOTE: the actual position expressions seem to not be
                    -- exposed in lua (line1 and line2 don't give the
                    -- column numbers)
                    -- require('ollouma.util.log').warn('TODO use get_range_text; cmd_opts=', vim.inspect(cmd_opts))
                    visual_selection = require('ollouma.util').get_last_visual_selection()
                end

                ollouma.start({ visual_selection = visual_selection })
            end,

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
