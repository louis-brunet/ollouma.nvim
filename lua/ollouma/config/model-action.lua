---@class OlloumaModelActionOptions
---@field visual_selection string|nil
---@field filetype string|nil

---@class OlloumaModelAction
---@field name string
---@field on_select fun(opts: OlloumaModelActionOptions|nil): nil


local M = {}

---@param interactive_prompts OlloumaGenerateInteractivePrompt[]
---@param model string
---@param model_action_opts OlloumaModelActionOptions
---@param filtered_actions OlloumaModelAction[]|nil insert created actions into this table if not nil
---@return OlloumaModelAction[]
function M.from_interactive_prompt_config(interactive_prompts, model, model_action_opts, filtered_actions)
    local generate_ui = require('ollouma.generate.ui')
    filtered_actions = filtered_actions or {}

    for _, interactive_prompt in ipairs(interactive_prompts) do
        local is_missing_selection =
            model_action_opts.visual_selection == nil and interactive_prompt.require_selection

        if not is_missing_selection then
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

            table.insert(filtered_actions, new_action)
        end
    end

    return filtered_actions
end

---@param output_only_prompts OlloumaGenerateOutputOnlyPrompt[]
---@param model string
---@param model_action_opts OlloumaModelActionOptions
---@param filtered_actions OlloumaModelAction[]|nil insert created actions into this table if not nil
---@return OlloumaModelAction[]
function M.from_output_only_prompt_config(output_only_prompts, model, model_action_opts, filtered_actions)
    local generate_ui = require('ollouma.generate.ui')

    filtered_actions = filtered_actions or {}

    for _, output_only_prompt in ipairs(output_only_prompts) do
        local is_missing_selection =
            model_action_opts.visual_selection == nil and output_only_prompt.require_selection

        if not is_missing_selection then
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

            table.insert(filtered_actions, new_action)
        end
    end

    return filtered_actions
end

---@param prompts_from_config OlloumaPromptsConfig
---@param model string
---@param model_action_opts OlloumaModelActionOptions
---@param existing_actions OlloumaModelAction[]|nil insert into this table if not nil
---@return OlloumaModelAction[]
function M.from_prompt_config(prompts_from_config, model, model_action_opts, existing_actions)
    existing_actions = existing_actions or {}

    table.insert(existing_actions, {
        name = 'Chat',
        on_select = function()
            local system_prompt = prompts_from_config.chat.system_prompt
            local system_prompt_str = nil
            if type(system_prompt) == 'function' then
                system_prompt_str = system_prompt(model, model_action_opts)
            else
                system_prompt_str = system_prompt
            end

            require('ollouma.chat.ui').start_chat_ui(
                {
                    model = model,
                    system_prompt = system_prompt_str,
                }
            )
        end
    })

    M.from_interactive_prompt_config(prompts_from_config.generate.interactive, model, model_action_opts, existing_actions)
    M.from_output_only_prompt_config(prompts_from_config.generate.output_only, model, model_action_opts, existing_actions)

    return existing_actions
end

return M
