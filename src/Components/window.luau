--!nocheck

-- Variables
local variables = require(script.Parent.Parent.utility.variables)

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

    -- Rayfield Gen2 Screen
    self.screenGui = self:Create("ScreenGui", {
        Parent = variables.guiContainer,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        DisplayOrder = 100000,
    })

    -- Drag Point
    self.drag = self:Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(150, 20),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 265),
        Parent = self.screenGui,
    })

    self.dragCosmetic = self:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.7,
        Size = UDim2.fromOffset(100, 4),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.3),
        Parent = self.drag,
    })

    self:Create("UICorner", {
        CornerRadius = UDim.new(0, 20),
        Parent = self.dragCosmetic,
    })

    self.dragInteract = self:Create("TextButton", {
        BackgroundTransparency = 1,
        Parent = self.drag,
        Size = UDim2.fromScale(1, 1),
        TextTransparency = 1,
    })

    -- Window
    self.main = self:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Size = self.size,
        Name = self.name,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Parent = self.screenGui,
    })

    self:Create("UICorner", {
        CornerRadius = UDim.new(0, 20),
        Parent = self.main,
    })

    self.windowStroke = self:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 0.95,
        Parent = self.main,
    })

    self.windowGradient = self:Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(0.0784313725, 0.0784313725, 0.0784313725)),
            ColorSequenceKeypoint.new(1, Color3.new(0.0784313725, 0.0784313725, 0.0784313725))
        }),
        Rotation = 250,
        Offset = Vector2.new(0, 0.2),
        Parent = self.main,
    })

    


    -- Topbar
    self.topbar = self:Create("Frame", {
        BorderSizePixel = 0,

        Parent = self.main,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 66),
    })

    self.dividerTop = self:Create("Frame", {
        BorderSizePixel = 0,

        Parent = self.topbar,
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundTransparency = 0.85
    })

    self.dividerBottom = self:Create("Frame", {
        BorderSizePixel = 0,
        
        Parent = self.main,
        Position = UDim2.new(0, 0, 0, 105),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundTransparency = 0.85
    })

    self.dividerTopGradient = self:Create("UIGradient", {
        Parent = self.dividerTop,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1, 0),
            NumberSequenceKeypoint.new(0.1, 0.75, 0),
            NumberSequenceKeypoint.new(0.300499, 0, 0),
            NumberSequenceKeypoint.new(0.5, 0.75, 0),
            NumberSequenceKeypoint.new(1, 1, 0)
        })
    })

    self.dividerBottomGradient = self:Create("UIGradient", {
        Parent = self.dividerBottom,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1, 0),
            NumberSequenceKeypoint.new(0.1, 0.75, 0),
            NumberSequenceKeypoint.new(0.300499, 0, 0),
            NumberSequenceKeypoint.new(0.5, 0.75, 0),
            NumberSequenceKeypoint.new(1, 1, 0)
        })
    })

    self.titleContainer = self:Create("Frame", {
        BorderSizePixel = 0,

        Parent = self.topbar,
        Size = UDim2.new(0, 300, 0, 24),
        Position = UDim2.new(0, 25, 0.5, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1
    })

    self.titleContainerLayout = self:Create("UIListLayout", {
        Parent = self.titleContainer,
        Padding = UDim.new(0, 3),
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Center
    })

    self.title = self:Create("TextLabel", {
        -- Configurables
        Text = 'Title', -- window name

        -- Theming
        TextColor3 = Color3.fromRGB(255, 255, 255),
        FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold),

        Size = UDim2.new(1, 0, 0, 20),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
       
        Parent = self.titleContainer
    })

    self.subtitle = self:Create("TextLabel", {
        -- Configurables
        Text = 'Script Description Example', -- window name

        -- Theming
        TextColor3 = Color3.fromRGB(255, 255, 255),
        FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium),

        Size = UDim2.new(1, 0, 0, 12),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 12,
        TextTransparency = 0.7,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
       
        Parent = self.titleContainer
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