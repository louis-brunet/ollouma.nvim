-- ---@class OlloumaChatJobOptions
-- ---@field command string
-- ---@field args string[]
--
-- ---@class OlloumaChatStartOptions
-- ---@field model string
-- ---@field system_prompt string
-- ---@field job OlloumaChatJobOptions

---@class OlloumaChatModule
local M = {}

-- ---@type OlloumaChatModule?
-- local chat_instance = nil
--
-- function OlloumaChat:new()
--     if chat_instance ~= nil then
--         -- TODO: reset instance
--     end
--     chat_instance = {}
--
--     ---@type OlloumaChatModule
--     return chat_instance
-- end

local function on_stdout(_, data)
    -- print('Job stdout: ' .. data)

    -- vim.schedule(function()
    --     local success, result = pcall(function()
    --         return vim.fn.json_decode(data)
    --     end)
    --
    --     if not success then
    --         print("Error: " .. result)
    --         return
    --     end
    --
    --     if not result then
    --         return
    --     end
    --
    --     if not result.done then
    --         local token = result.message.content
    --
    --         if string.match(token, "\n") then
    --             line = line + 1
    --             words = {}
    --             line_char_count = 0
    --             token = token:gsub("\n", "")
    --         end
    --
    --         -- trim leading whitespace on new lines
    --         if line_char_count == 0 then
    --             token = token:gsub("^%s+", "")
    --         end
    --
    --         line_char_count = line_char_count + #token
    --
    --         table.insert(words, token)
    --
    --         vim.api.nvim_buf_set_lines(
    --             self.chat_float.bufnr,
    --             line,
    --             line + 1,
    --             false,
    --             { table.concat(words, "") }
    --         )
    --
    --         -- scroll to bottom
    --         vim.api.nvim_win_set_cursor(self.chat_float.winid, { line + 1, 0 })
    --
    --         -- save response
    --         response.content = response.content .. result.message.content
    --     else
    --         self.running = false
    --     end
    -- end)
end

function M.start(opts)
    -- vim.validate({ opts = { opts, 'table' } })



    -- local config = require'ollouma'.config
    -- TODO: use `vim.system or ollouma.util.system`

    -- local Job = require 'plenary.job'

    -- error('todo: on_stdout')
    --
    -- local job = Job:new({
    --     command = opts.job.command,
    --
    --     args = opts.job.args,
    --
    --
    --     on_stdout = on_stdout, -- TODO:
    --
    --     on_stderr = function(_, data)
    --         print("Error: " .. data)
    --     end,
    -- })
    --
    -- print(vim.inspect(opts))
    -- print(vim.inspect(job))
    error('todo: chat')
end

return M
