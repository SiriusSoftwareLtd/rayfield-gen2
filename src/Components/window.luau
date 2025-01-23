--!nocheck

-- Variables
local variables = require(script.Parent.Parent.Utility.variables)

-- Module
local Window = {}
Window.__index = Window

function Window.new(name, size)
    local self = setmetatable({
        name = name or "Window",
        size = size or UDim2.fromOffset(475, 500),
        instances = {},
        connections = {},
    }, Window)

    self.screenGui = self:Create("ScreenGui", {
        Parent = variables.guiContainer,
    })

    self.main = self:Create("Frame", {
        Size = self.size,
        Name = self.name,
        Parent = self.screenGui,
    })

    self.top = self:Create("Frame", {
        Parent = self.main,
    })

    return self
end

function Window:Create(className, properties)
    local instance = Instance.new(className)
    if properties then
        for property, value in properties do
            instance[property] = value
        end
    end
    table.insert(self.instances, instance)
    return instance
end

function Window:Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self.connections, connection)
    return connection
end

function Window:Unload()
    for i = #self.connections, 1, -1 do
        self.connections[i]:Disconnect()
    end
    for i = #self.instances, 1, -1 do
        self.instances[i]:Destroy()
    end
end

return Window