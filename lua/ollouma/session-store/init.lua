---@class OlloumaSessionMetadata
---@field title string
---@field created_at integer
---@field tags string[]|nil

---@class OlloumaSession
---@field ui OlloumaSplitUi
---@field metadata OlloumaSessionMetadata


local M = {
    ---@type table<OlloumaSplitUi,  OlloumaSessionMetadata>
    sessions = {},
}

---@return OlloumaSession[]
function M.list_sessions()
    ---@type OlloumaSession[]
    local open_sessions = {}

    for ui, metadata in pairs(M.sessions) do
        table.insert(
            open_sessions,
            {
                ui = ui,
                metadata = metadata,
            }
        )
    end

    return open_sessions
end

---@param split_ui OlloumaSplitUi
---@param metadata OlloumaSessionMetadata
function M.add_session(split_ui, metadata)
    M.sessions[split_ui] = metadata
end

---@param split_ui OlloumaSplitUi
function M.remove_session(split_ui)
    M.sessions[split_ui] = nil
end

---@class OlloumaSessionSelectOptions
---@field add_all_option boolean|nil add an option to select all sessions if there is more than 1 open session

---@param prompt string
---@param on_select fun(split_ui: OlloumaSplitUi, ui_metadata: OlloumaSessionMetadata): nil
---@param opts OlloumaSessionSelectOptions|nil
function M.select_session(prompt, on_select, opts)
    local log = require('ollouma.util.log')
    opts = opts or {}
    local OPTION_ALL = 'all'
    local sessions = M.list_sessions()
    -- local sessions = require('ollouma.generate.ui').list_opened_uis()

    if not sessions or #sessions == 0 then
        log.warn('no open sessions, aborting')
        return
    end

    local options = {}
    if opts.add_all_option and #sessions > 1 then
        table.insert(options, OPTION_ALL)
    end
    for _, session in ipairs(sessions) do
        table.insert(options, session)
    end

    vim.ui.select(
        options,

        {
            prompt = prompt,

            ---@param item OlloumaSession|"all"
            ---@return string
            format_item = function(item)
                if item == OPTION_ALL then
                    ---@type string
                    return item
                end

                return vim.fn.printf('%s (%s)', item.metadata.title, os.date(nil, item.metadata.created_at))
            end
        },

        ---@param item OlloumaSession|"all"
        ---@param _ integer index
        function(item, _)
            if not item then
                log.debug('no session selected, aborting')
                return
            end

            if item == OPTION_ALL then
                for _, session in ipairs(sessions) do
                    on_select(session.ui, session.metadata)
                end
            else
                on_select(item.ui, item.metadata)
            end
        end
    )
end

return M
