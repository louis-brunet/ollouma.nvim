local function format_msg(...)
    return '[ollouma]: ' .. vim.fn.join({ ... }, ' ')
end

local M = {
    --- :h vim.log.levels
    -- TODO: value from config
    level = vim.log.levels.INFO
}

local function log(vim_level, ...)
    if M.level > vim_level then
        return
    end

    vim.notify(format_msg(...), vim_level)
end

function M.error(...)
    log(vim.log.levels.ERROR, '(ERROR)', ...)
end

function M.warn(...)
    log(vim.log.levels.WARN, '(WARN)', ... )
end

function M.info(...)
    log(vim.log.levels.INFO, '(INFO)', ... )
end

function M.debug(...)
    log(vim.log.levels.DEBUG, '(DEBUG)', ... )
end

function M.trace(...)
    log(vim.log.levels.TRACE, '(TRACE)', ... )
end

return M
