local Button = {}
Button.__index = Button
Button.__type = "Button"

function Button.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        name = properties.name or properties.Name or "Button",
        icon = properties.icon or properties.Icon,
        customOrder = properties.customOrder or properties.CustomOrder
    }, Button)

    self.main = self.tab.window:Create("Frame", {

        -- Theming
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),

        Size = UDim2.new(1, -20, 0, 43),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Name = self.name,

        LayoutOrder = self.customOrder or 0,

        Parent = self.tab.tabPage,
    })

    self.tab.window:Create("UICorner", {
        CornerRadius = UDim.new(0, 12),
        Parent = self.main,
    })

    self.stroke = self.tab.window:Create("UIStroke", {
        Color = Color3.fromRGB(35, 35, 35),
        Transparency = 0,
        Parent = self.main,
    })
    
    self.container = self.tab.window:Create("Frame", {
        BorderSizePixel = 0,

        Parent = self.main,
        Size = UDim2.new(0, 170, 0, 16),
        Position = UDim2.new(0, 20, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1
    })

    self.containerLayout = self.tab.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,

        Parent = self.container
    })

    if self.icon then
        self.iconLabel = self.tab.window:Create("ImageLabel", {
            -- Configurables
            Image = 'rbxassetid://'..tostring(self.icon),
            
            -- Theming
            ImageColor3 = Color3.fromRGB(255, 255, 255),

            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ImageTransparency = 0,
       
            Parent = self.container
        })
    end

    self.title = self.tab.window:Create("TextLabel", {
        -- Configurables
        Text = self.name, -- tab name

        -- Theming
        TextColor3 = Color3.fromRGB(255, 255, 255),
        FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium),

        Size = UDim2.fromOffset(170, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextTransparency = 0,
        AutomaticSize = Enum.AutomaticSize.X,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 1,
    
        Parent = self.container
    })

    return self
end

return Button
