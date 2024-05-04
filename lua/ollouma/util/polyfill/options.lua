local M = {}

-- FIXME: 0.10 remove this polyfill
--
---@param option_name string
---@param buffer integer|nil
---@return any
function M.buf_get_option(option_name, buffer)
    buffer = buffer or 0

    if vim.api.nvim_get_option_value then
        return vim.api.nvim_get_option_value(option_name, { buf = buffer })
    else
        return vim.api.nvim_buf_get_option(buffer, option_name)
    end
end

-- FIXME: 0.10 remove this polyfill
--
---@param option_name string
---@param option_value string
---@param opts { buf: integer|nil }
---@return any
function M.buf_set_option(option_name, option_value, opts)
    local buf = opts.buf or 0

    if vim.api.nvim_set_option_value then
        return vim.api.nvim_set_option_value(option_name, option_value, { buf = buf })
    else
        return vim.api.nvim_buf_set_option(buf, option_name, option_value)
    end
end

-- FIXME: 0.10 remove this polyfill
--
---@param option_name string
---@param option_value string|boolean
---@param opts { win: integer|nil }
---@return any
function M.win_set_option(option_name, option_value, opts)
    local win = opts.win or 0

    if vim.api.nvim_set_option_value then
        return vim.api.nvim_set_option_value(option_name, option_value, { win = win })
    else
        return vim.api.nvim_win_set_option(win, option_name, option_value)
    end
end

return M
