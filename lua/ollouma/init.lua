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

    -- Set highlights from config
    for highlight_group, highlight_info in pairs(M.config.highlights) do
        vim.api.nvim_set_hl(
            0, -- global namespace so it can be overriden by the user
            highlight_group,
            highlight_info
        )
    end

    vim.api.nvim_create_user_command('Ollouma',
        function(cmd_opts)
            local arg = cmd_opts.fargs[1]
            local buf_get_option = require('ollouma.util.polyfill.options').buf_get_option

            ---@type OlloumaModelActionOptions
            local model_action_opts = {
                visual_selection = nil,
                filetype = buf_get_option('filetype')
            }
            if cmd_opts.range == 2 then
                -- NOTE: the actual position expressions seem to not be
                -- exposed in lua (line1 and line2 don't give the
                -- column numbers)
                -- require('ollouma.util.log').warn('TODO use get_range_text; cmd_opts=', vim.inspect(cmd_opts))
                model_action_opts.visual_selection = require('ollouma.util').get_last_visual_selection()
            end

            if not arg then
                -- :Ollouma

                if type(subcommands.ollouma) == 'function' then
                    subcommands.ollouma(cmd_opts, model_action_opts)
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

            vim.validate({
                subcommand = { subcommand, { 'function' } },
            })

            subcommand(cmd_opts, model_action_opts)
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

---@param model string
---@param model_action_opts OlloumaModelActionOptions|nil
function M.select_model_action(model, model_action_opts)
    model_action_opts = model_action_opts or {}
    vim.validate({
        model = { model, 'string' },
        model_action_opts = { model_action_opts, { 'table', 'nil' } },
        model_action_opts_visual_selection = { model_action_opts.visual_selection, { 'string', 'nil' } },
        model_action_opts_filetype = { model_action_opts.filetype, { 'string', 'nil' } },
    })

    local log = require('ollouma.util.log')
    local model_actions = M.config.model_actions(model, model_action_opts)

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
function M.select_model_then_model_action(model_action_opts)
    local Models = require('ollouma.models')

    Models.select_model(M.config.api.models_url, function(model)
        M.select_model_action(model, model_action_opts)
    end)
end

function M.resume_session()
    require('ollouma.session-store').select_session(
        'Resume session',
        function(split_ui, _)
            split_ui:resume_session()
        end
    )
end

function M.exit_session()
    require('ollouma.session-store').select_session(
        'Exit session',
        function(split_ui, _)
            split_ui:exit()
        end,
        {
            add_all_option = true,
        }
    )
end

function M.hide_session()
    require('ollouma.session-store').select_session(
        'Hide session',
        function(split_ui, _)
            split_ui:close_windows()
        end,
        {
            add_all_option = true,
        }
    )
end

return M
