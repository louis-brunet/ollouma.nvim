---@class Ollouma
---@field config OlloumaConfig
local M = {}

---@param partial_config? OlloumaPartialConfig
function M.setup(partial_config)
    local log = require('ollouma.util.log')
    local Config = require('ollouma.config')

    M.config = Config.extend_config(M.config, partial_config)

    local subcommands = M.config.user_command_subcommands or {}
    ---@type string[]
    local subcommand_names = vim.tbl_keys(subcommands)

    vim.api.nvim_create_user_command('Ollouma',
        function(cmd_opts)
            local arg = cmd_opts.fargs[1]

            if not arg then
                -- :Ollouma

                if type(subcommands.ollouma) == 'function' then
                    subcommands.ollouma(cmd_opts)
                    return
                end

                log.info('to set a default behavior for Ollouma, define a subcommand "ollouma"')

                return
            end

            -- :Ollouma <arg>

            local subcommand = subcommands[arg]
            if not subcommand then
                log.error('invalid subcommand: "' .. arg .. '"')
                return
            end

            subcommand(cmd_opts)
        end,

        -- :h nvim_create_user_command()
        -- :h command-attributes
        {
            nargs = '?', -- expect 0 or 1 args

            range = true,

            -- function(ArgLead, CmdLine, CursorPos)
            complete = function(ArgLead, _, _)
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
---@param model_action_opts OlloumaModelActionOptions |nil
function M.select_model_action(model, model_action_opts)
    model_action_opts = model_action_opts or {}
    vim.validate({
        model = { model, 'string' },
        model_action_opts = { model_action_opts, { 'table', 'nil' } },
        model_action_opts_visual_selection = { model_action_opts.visual_selection, { 'string', 'nil' } },
    })

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

        ---@param item OlloumaModelAction
        ---@param _ integer index
        function(item, _)
            if not item then
                log.debug('no action selected, aborting')
                return
            end

            vim.validate({ on_select = { item.on_select, 'function' } })

            -- M._state.last_action = { model = model, model_action = item }

            local ok, err = pcall(item.on_select, model_action_opts)
            if not ok then
                log.error('Could not call model action: ' .. err)
            end
        end
    )
end

---@param model_action_opts OlloumaModelActionOptions|nil
function M.start(model_action_opts)
    local Models = require('ollouma.models')

    Models.select_model(M.config.api.models_url, function(model)
        M.select_model_action(model, model_action_opts)
    end)
end

-- TODO: refactor session handling (name formatting; selection?; in generate module ?)
function M.resume_session()
    local log = require('ollouma.util.log')
    local opened_gen_uis = require('ollouma.generate.ui').list_opened_uis()

    if not opened_gen_uis or #opened_gen_uis == 0 then
        log.warn('no open sessions, aborting')
        return
    end

    vim.ui.select(
        opened_gen_uis,

        {
            prompt = 'Resume session',
            ---@param item OlloumaGenerateOpenedUi
            ---@return string
            format_item = function(item)
                return vim.fn.printf('%s (%s)', item.metadata.title, os.date(nil, item.metadata.created_at))
            end
        },

        ---@param item OlloumaGenerateOpenedUi
        ---@param _ integer index
        function(item, _)
            if not item then
                log.debug('no session selected, aborting')
                return
            end

            item.ui:resume_session()
        end
    )
end

-- TODO: refactor session handling (name formatting; selection?; in generate module ?)
function M.exit_session()
    local log = require('ollouma.util.log')
    local OPTION_ALL = 'all'
    local opened_gen_uis = require('ollouma.generate.ui').list_opened_uis()

    if not opened_gen_uis or #opened_gen_uis == 0 then
        log.warn('no open sessions, aborting')
        return
    end

    local options = { OPTION_ALL }
    for _, gen_ui_option in ipairs(opened_gen_uis) do
        table.insert(options, gen_ui_option)
    end

    vim.ui.select(
        options,

        {
            prompt = 'Exit session',
            ---@param item OlloumaGenerateOpenedUi|"all"
            ---@return string
            format_item = function(item)
                if item == OPTION_ALL then
                    ---@type string
                    return item
                end

                return vim.fn.printf('%s (%s)', item.metadata.title, os.date(nil, item.metadata.created_at))
            end
        },

        ---@param item OlloumaGenerateOpenedUi|"all"
        ---@param _ integer index
        function(item, _)
            if not item then
                log.debug('no session selected, aborting')
                return
            end

            if item == OPTION_ALL then
                for _, opened_ui in ipairs(opened_gen_uis) do
                    opened_ui.ui:exit()
                end
            else
                item.ui:exit()
            end
        end
    )
end

return M
