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
---@param buffer integer|nil
---@return any
function M.buf_set_option(option_name, option_value, buffer)
    buffer = buffer or 0

    if vim.api.nvim_set_option_value then
        return vim.api.nvim_set_option_value(option_name, option_value, { buf = buffer })
    else
        return vim.api.nvim_buf_set_option(buffer, option_name, option_value)
    end
end

return M
