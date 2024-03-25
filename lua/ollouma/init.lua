-- ---@class OlloumaState
-- ---@field last_action? { model: string, model_action: OlloumaModelActionConfig }

---@class Ollouma
---@field config OlloumaConfig
-- ---@field _state OlloumaState
local M = {}

---@param partial_config? OlloumaPartialConfig
function M.setup(partial_config)
    local log = require('ollouma.util.log')
    local Config = require('ollouma.config')

    M.config = Config.extend_config(M.config, partial_config)
    M._state = {}

    local subcommands = M.config.user_command_subcommands or {}
    ---@type string[]
    local subcommand_names = vim.tbl_keys(subcommands)

    vim.api.nvim_create_user_command('Ollouma',
        function(cmd_opts)
            local arg = cmd_opts.fargs[1]
            if not arg then
                if type(subcommands.ollouma) == 'function' then
                    subcommands.ollouma()
                    return
                end

                -- TODO: not only generate ui ?
                -- local ui = require('ollouma.generate.ui')
                -- if ui:are_buffers_valid() then
                --     ui:open_windows()
                -- else
                    require('ollouma').select()
                -- end
            else
                local subcommand = subcommands[arg]
                if not subcommand then
                    log.warn('invalid subcommand: "' .. arg .. '"')
                    return
                end
                subcommand()
            end
        end,

        -- :h nvim_create_user_command()
        -- :h command-attributes
        {
            nargs = '?',
            complete = function(ArgLead, CmdLine, CursorPos)
                return vim.tbl_filter(
                ---@param name string
                    function(name)
                        local match = name:match('^' .. ArgLead)
                        return not not match
                    end,
                    subcommand_names
                )
            end,
        }
    )
end

-- ---@param model? string
-- ---@param system_prompt? string
-- function M.chat(model, system_prompt)
--     local Chat = require('ollouma.chat')
--     Chat.start({
--         model = model or M.config.chat.model,
--         system_prompt = system_prompt or M.config.chat.system_prompt,
--     })
-- end

---@param model string
function M.select_model_action(model)
    vim.validate({ model = { model, 'string' } })

    local log = require('ollouma.util.log')
    local model_actions = M.config.model_actions(model)

    if #model_actions == 0 then
        log.warn('no actions to pick from')
        return
    end

    vim.ui.select(
        model_actions,

        {
            prompt = 'Actions [' .. model .. ']',
            format_item = function(item) return item.name end
        },

        ---@param item OlloumaModelActionConfig
        ---@param _ integer index
        function(item, _)
            if not item then
                log.warn('no action selected, aborting')
                return
            end

            vim.validate({ on_select = { item.on_select, 'function' } })

            -- M._state.last_action = { model = model, model_action = item }

            local ok, err = pcall(item.on_select)
            if not ok then
                log.warn('Could not call model action: ' .. err)
            end
        end
    )
end

-- function M.last_model_action()
--     local log = require('ollouma.util.log')
--     local action = M._state.last_action
--
--     if action then
--         local ok, err = pcall(action.model_action.on_select, action.model)
--         if not ok then
--             log.warn('Could not call model action: ' .. err)
--         end
--     else
--         log.warn('Last model action not found')
--     end
-- end

function M.select()
    local Models = require('ollouma.models')

    Models.select_model(M.config.api.models_url, function(model)
        M.select_model_action(model)
    end)
end

return M
