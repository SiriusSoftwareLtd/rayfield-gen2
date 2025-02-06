local Action = {}
Action.__index = Action
Action.__type = "Action"

function Action.new(window, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        name = properties.name or properties.Name or "Action",
        icon = assert(properties.icon or properties.Icon, "Missing argument (Icon expected)"),
        callback = assert(properties.callback or properties.Callback, "Missing argument (Function expected)")
    }, Action)

    
    

    self.action = self.window:Create("Frame", {
        Name = self.name,
        BorderSizePixel = 0,

        LayoutOrder = -properties.order or 0,
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,

        Parent = self.window.actionContainer
    })

    self.iconLabel = self.window:Create("ImageLabel", {
        -- Configurables
        Image = 'rbxassetid://'..tostring(self.icon),

        Size = UDim2.fromOffset(20, 20),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundTransparency = 1,
        ImageTransparency = 0.6,
       
        Parent = self.action
    }, {ImageColor3 = 'ActionColor'})

    self.interact = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        TextTransparency = 1,

        Parent = self.action,
    })

    

    self.window:Connect(self.interact.MouseButton1Click, properties.callback)
    
    return self
end

return Action
