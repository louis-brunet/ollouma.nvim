--- thanks to @justinmk https://github.com/neovim/neovim/pull/13896#issuecomment-1621702052
local function region_to_text(region)
    local text = ''
    local maxcol = vim.v.maxcol
    for line, cols in vim.spairs(region) do
        local endcol = cols[2] == maxcol and -1 or cols[2]
        local chunk = vim.api.nvim_buf_get_text(0, line, cols[1], line, endcol, {})[1]
        text = ('%s%s\n'):format(text, chunk)
    end
    return text
end

local M = {}

function M.is_function(value)
    return not not value and type(value) == 'function'
end

---@param buffer integer
---@return integer col
function M.buf_last_line_end_index(buffer)
    local last_line = vim.api.nvim_buf_get_lines(buffer, -2, -1, false)[1]
    return #last_line
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

function M.get_last_visual_selection()
    return M.get_range_text("'<", "'>")
end

function M.get_range_text(expr_start, expr_end)
    local pos_start = vim.fn.getpos(expr_start)
    local pos_end = vim.fn.getpos(expr_end)
    local region_start = { pos_start[2] - 1, pos_start[3] - 1 }
    local region_end = { pos_end[2] - 1, pos_end[3] - 1 }
    local region = vim.region(0, region_start, region_end, vim.fn.visualmode(), true)

    return region_to_text(region)
end

-- ---@param value any
-- ---@param possible_values any[]
-- ---@param rule_display_name string|nil
-- ---@return boolean
-- function M.validate_enum(value, possible_values, rule_display_name)
--     for _, possible_value in ipairs(possible_values) do
--         if value == possible_value then
--             return true
--         end
--     end
--
--     local prefix = ''
--     if rule_display_name then
--         prefix = '(' .. rule_display_name .. ') '
--     end
--
--     error(
--         prefix .. 'invalid value. Expected one of ['
--         .. table.concat(possible_values, ', ')
--         .. '], got ' .. vim.inspect(value)
--     )
-- end

return M
