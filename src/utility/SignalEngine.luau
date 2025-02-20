-- Signal Engine 1

-- Connection
local Connection = {}
Connection.__index = Connection
Connection.__type = "Connection"

function Connection.new(signal, callback)
    assert(typeof(signal) == "table" and signal.__type == "Signal", "Invalid argument #1 (Signal expected)")
    assert(typeof(callback) == "function", "Invalid argument #2 (function expected)")

    return setmetatable({
        signal = signal,
        callback = callback
    }, Connection)
end

function Connection:Disconnect()
    assert(self.signal ~= nil, "The connection is not connected")
    local index = table.find(self.signal.connections, self)
    if index then
        table.remove(self.signal.connections, index)
    end
    self.signal = nil
end

-- Signal
local Signal = {}
Signal.__index = Signal
Signal.__type = "Signal"

function Signal.new()
    return setmetatable({
        connections = {},
        yieldingThreads = {},
    }, Signal)
end

function Signal:Fire(...)
    for _, connection in self.connections do
        task.spawn(connection.callback, ...)
    end
    for _, thread in self.yieldingThreads do
        task.spawn(thread, ...)
    end
    table.clear(self.yieldingThreads)
end

function Signal:Connect(callback)
    assert(typeof(callback) == "function", "Invalid argument #1 (function expected)")
    local connection = Connection.new(self, callback)
    table.insert(self.connections, connection)
    return connection
end

function Signal:Wait()
    table.insert(self.yieldingThreads, coroutine.running())
    return coroutine.yield()
end

return Signal