local function format_msg(...)
    return '[ollouma]: ' .. vim.fn.join({ ... }, ' ')
end

local M = {}

local function log(vim_level, ...)
    local config_log_level = require('ollouma').config.log_level
    if config_log_level > vim_level then
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
