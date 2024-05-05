---@class OlloumaAsyncQueueNode
---@field callback OlloumaAsyncQueueCallback
---@field next OlloumaAsyncQueueNode|nil
local M = {}
M.__index = M

---@param callback OlloumaAsyncQueueCallback
---@return OlloumaAsyncQueueNode
function M:new(callback)
    ---@type OlloumaAsyncQueueNode
    local async_queue_node = {
        callback = callback,
        next = nil,
    }

    return setmetatable(async_queue_node, self)
end

return M
