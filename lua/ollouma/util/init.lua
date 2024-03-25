local M = {}

function M.is_function(value)
    return not not value and type(value) == 'function'
end

---@param buffer integer
---@param lines string[]
function M.buf_append_lines(buffer, lines)
    vim.api.nvim_buf_set_lines(buffer, -1, -1, false, lines)
end

--- Only inserts a newline if the string contains any
---@param buffer integer
---@param new_text string
function M.buf_append_string(buffer, new_text)
    local last_line = vim.api.nvim_buf_get_lines(buffer, -2, -1, false)[1]
    local concatenated = (last_line or "") .. (new_text or "")
    local new_lines = vim.split(concatenated, '\n', { plain = true })

    vim.api.nvim_buf_set_lines(buffer, -2, -1, false, new_lines)
end

return M
