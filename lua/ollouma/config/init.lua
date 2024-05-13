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
---@field payload_generator nil|fun(model: string, prompt: string[], model_action_opts: OlloumaModelActionOptions):OlloumaGenerateRequestPayload
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


---@class OlloumaPromptsConfigChat
---@field system_prompt string|fun(model: string, model_action_opts: OlloumaModelActionOptions):string

---@class OlloumaPartialPromptsConfigChat
---@field system_prompt string|(fun(model: string, model_action_opts: OlloumaModelActionOptions):string)|nil


---@class OlloumaPromptsConfig
---@field generate OlloumaPromptsConfigGenerate
---@field chat OlloumaPromptsConfigChat

---@class OlloumaPartialPromptsConfig
---@field generate OlloumaPartialPromptsConfigGenerate|nil
---@field chat OlloumaPartialPromptsConfigChat|nil


---@alias OlloumaHighlightsConfig table<OlloumaHighlightGroup, vim.api.keyset.highlight>
-- ---@alias OlloumaHighlightsConfig { [OlloumaHighlightGroup]: vim.api.keyset.highlight }

-- ---@field  OlloumaPromptsConfigGenerate
-- ---@field chat OlloumaPromptsConfigChat
--
-- ---@class OlloumaPartialPromptsConfig
-- ---@field generate OlloumaPartialPromptsConfigGenerate|nil
-- ---@field chat OlloumaPartialPromptsConfigChat|nil


---@class OlloumaConfig
-- ---@field chat OlloumaChatConfig
---@field model string|nil
---@field api OlloumaApiConfig
---@field prompts OlloumaPromptsConfig
---@field model_actions fun(model: string, model_action_opts: OlloumaModelActionOptions|nil): OlloumaModelAction[]
---@field user_command_subcommands table<string, OlloumaSubcommand>
---@field log_level integer :h vim.log.levels
---@field highlights OlloumaHighlightsConfig

---@class OlloumaPartialConfig
---@field model string|nil
-- ---@field chat OlloumaPartialChatConfig|nil
---@field api OlloumaPartialApiConfig|nil
---@field prompts OlloumaPartialPromptsConfig|nil
---@field model_actions nil|fun(model: string, model_action_opts: OlloumaModelActionOptions|nil): OlloumaModelAction[]
---@field user_command_subcommands table<string, OlloumaSubcommand>|nil
---@field log_level integer|nil :h vim.log.levels
---@field highlights OlloumaHighlightsConfig|nil


-- ---@type OlloumaPromptsConfig
-- local default_prompts =


---@class OlloumaConfigModule
---@field default_config fun(): OlloumaConfig
---@field extend_config fun(current_config?: OlloumaConfig, partial_config?: OlloumaPartialConfig): OlloumaConfig
local M = {}

function M.default_config()
    local highlight_groups = require('ollouma.util.ui').highlight_groups
    local default_base_url = '127.0.0.1:11434'

    local title_highlight = vim.api.nvim_get_hl(
        0,
        { name = 'Title', link = false, }
    )
    local cursor_line_highlight = vim.api.nvim_get_hl(
        0,
        { name = 'CursorLine', link = false, }
    )
    local comment_highlight = vim.api.nvim_get_hl(
        0,
        { name = 'Comment', link = false, }
    )
    local error_highlight = vim.api.nvim_get_hl(
        0,
        { name = 'Error', link = false, }
    )

    ---@type OlloumaConfig
    return {
        log_level = vim.log.levels.INFO,

        -- query the server for the list of models and let the user choose which one
        model = nil,

        api = {
            generate_url = default_base_url .. '/api/generate',
            chat_url = default_base_url .. '/api/chat',
            models_url = default_base_url .. '/api/tags',
        },

        -- these prompts are only used in the default implementation of the config.model_actions()
        prompts = {
            chat = {
                -- system_prompt = 'You are an AI assistant integrated in Neovim via the plugin ollouma.nvim.',
                system_prompt = function(model, model_action_opts)
                    local assistant_str = 'You are an AI assistant integrated in Neovim via the plugin ollouma.nvim. '
                    local model_str = 'The user has configured you to use the model named ' .. model .. '. '
                    -- local code_blocks_str = 'When you write code blocks with triple backticks, include a language annotation for better syntax highlighting. '
                    -- local filetype_str = '... something about ' .. model_action_opts.filetype

                    return assistant_str .. model_str -- .. code_blocks_str
                end,
            },

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
                        action_name = 'Generate JSON', -- (TODO: set output filetype + custom output separator?)',
                        payload_generator = function(model, prompt, _)
                            ---@type OlloumaGenerateRequestPayload
                            return {
                                model = model,
                                prompt = table.concat(prompt, '\n'),
                                system = 'Respond to the following message with a single JSON-formatted object. Do not write any text before or after the returned JSON object.',
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
                        action_name = 'Review code (visual selection)',
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
                                system = 'Review the following code snippet and list any improvements to be made.'
                                    .. ' Only give relevant suggestions with good implementations.'
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
        },

        model_actions = function(model, model_action_opts)
            model_action_opts = model_action_opts or {}
            local prompts = require('ollouma').config.prompts
            local model_actions_module = require('ollouma.config.model-action')

            ---@type OlloumaModelAction[]
            local model_actions = model_actions_module.from_prompt_config(prompts, model, model_action_opts)

            return model_actions
        end,

        user_command_subcommands = {
            ollouma = function(cmd_opts, model_action_opts)
                require('ollouma').config.user_command_subcommands.select_action(cmd_opts, model_action_opts)
            end,

            select_action = function(_, model_action_opts)
                local ollouma = require('ollouma')

                if ollouma.config.model then
                    ollouma.select_model_action(ollouma.config.model, model_action_opts)
                else
                    ollouma.select_model_then_model_action(model_action_opts)
                end
            end,

            select_model = function(_, model_action_opts)
                require('ollouma').select_model_then_model_action(model_action_opts)
            end,

            hide = function()
                require('ollouma').hide_session()
            end,

            resume = function()
                require('ollouma').resume_session()
            end,

            exit = function()
                require('ollouma').exit_session()
            end,
        },

        highlights = {
            [highlight_groups.chat_content] = {
            },

            [highlight_groups.chat_role] = {
                link = title_highlight.link,
                fg = title_highlight.fg,
                bg = title_highlight.bg,
                -- bg = cursor_line_highlight.bg,
                bold = title_highlight.bold,
                cterm = title_highlight.cterm,
                sp = title_highlight.sp,
            },

            [highlight_groups.loading_indicator] = {
                bold = true,
                italic = true,
                fg = comment_highlight.fg,
            },

            [highlight_groups.error_title] = {
                bold = true,
                fg = error_highlight.fg,
            },
            --
            -- [highlight_groups.error_reason] = {
            --     italic = true,
            --     fg = error_highlight.fg,
            -- },

            [highlight_groups.error_details] = {
                fg = error_highlight.fg,
            },
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
