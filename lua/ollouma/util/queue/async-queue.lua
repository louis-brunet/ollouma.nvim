---@alias OlloumaAsyncQueueCallback fun(resolve: fun():nil):nil

---@class OlloumaAsyncQueue
---@field head OlloumaAsyncQueueNode|nil
---@field tail OlloumaAsyncQueueNode|nil
local M = {}
M.__index = M

---@return OlloumaAsyncQueue
function M:new()
    ---@type OlloumaAsyncQueue
    local async_queue = {
        head = nil,
    }

    return setmetatable(async_queue, self)
end

---@class OlloumaAsyncQueueEnqueueOptions
---@field on_wait_start nil|fun():nil

---@param callback OlloumaAsyncQueueCallback
---@param opts OlloumaAsyncQueueEnqueueOptions|nil
function M:enqueue(callback, opts)
    local OlloumaAsyncQueueCallback = require('ollouma.util.queue.async-queue-node')
    local new_node = OlloumaAsyncQueueCallback:new(callback)
    opts = opts or {}

    if self.tail ~= nil then
        self.tail.next = new_node
    end

    self.tail = new_node

    local log = require('ollouma.util.log')
    log.trace('[enqueue] head was ', vim.inspect(self.head))
    if self.head == nil then
        self.head = new_node

        callback(function()
            self:_resolve_async_task()
        end)
    else
        if opts.on_wait_start then
            opts.on_wait_start()
        end
    end
end

---@return OlloumaAsyncQueueCallback|nil
function M:dequeue()
    local log = require('ollouma.util.log')
    log.trace('[dequeue] before head = ', vim.inspect(self.head))
    if self.head == nil then
        return nil
    end

    local dequeued_node = self.head ---@type OlloumaAsyncQueueNode

    self.head = self.head.next
    if self.head == nil then
        self.tail = nil
    end

    log.trace('[dequeue] after head = ', vim.inspect(self.head))
    return dequeued_node.callback
end

function M:_resolve_async_task()
    local log = require('ollouma.util.log')
    log.trace('[_resolve_async_task] RESOLVE')
    local _ = self:dequeue()
    if self.head == nil then
        log.trace('[_resolve_async_task] no next task, ', vim.inspect(self.head), vim.inspect(self.tail))
        return
    end

    vim.schedule(function()
        self.head.callback(function()
            self:_resolve_async_task()
        end)
    end)
end

return M
