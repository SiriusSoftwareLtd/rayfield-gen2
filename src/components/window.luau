--!nocheck

-- Variables
local variables = require(script.Parent.Parent.utility.variables)

-- Module
local Window = {}
Window.__index = Window

function Window.new(properties)
    local self = setmetatable({
        name = properties.name or properties.Name or "Rayfield Window",
        size = UDim2.fromOffset(475, 500), -- calculate sizing for mobile. use formula based on viewport?
        instances = {},
        connections = {},

        theme = properties.theme or properties.Theme or 'unselected'
    }, Window)

    -- Rayfield Gen2 Screen
    self.screenGui = self:Create("ScreenGui", {
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        DisplayOrder = 100000,

        Parent = variables.guiContainer,
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
        Size = UDim2.fromScale(1, 1),
        TextTransparency = 1,

        Parent = self.drag,
    })

    -- Window
    self.main = self:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Size = self.size,
        Name = self.name,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),

        Parent = self.screenGui
    })

    self:Create("UICorner", {
        CornerRadius = UDim.new(0, 20),

        Parent = self.main
    })

    self.windowStroke = self:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 0.95,

        Parent = self.main
    })

    self.windowGradient = self:Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(0.0784313725, 0.0784313725, 0.0784313725)),
            ColorSequenceKeypoint.new(1, Color3.new(0.0784313725, 0.0784313725, 0.0784313725))
        }),
        Rotation = 250,
        Offset = Vector2.new(0, 0.2),

        Parent = self.main
    })


    -- Topbar
    self.topbar = self:Create("Frame", {
        
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 66),

        Parent = self.main
    })

    self.dividerTop = self:Create("Frame", {
        

        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.85,

        Parent = self.topbar
    })

    self.dividerBottom = self:Create("Frame", {
        
        
        Parent = self.main,
        Position = UDim2.new(0, 0, 0, 105),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
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
        Text = self.name, -- window name

        -- Theming
        TextColor3 = Color3.fromRGB(255, 255, 255),
        FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold),

        Size = UDim2.new(1, 0, 0, 20),
        
        BackgroundTransparency = 1,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
       
        Parent = self.titleContainer
    })

    self.subtitle = self:Create("TextLabel", {
        -- Configurables
        Text = 'Content', -- window name

        -- Theming
        TextColor3 = Color3.fromRGB(255, 255, 255),
        FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium),

        Size = UDim2.new(1, 0, 0, 12),
        
        BackgroundTransparency = 1,
        TextSize = 12,
        TextTransparency = 0.7,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
       
        Parent = self.titleContainer
    })

    -- Shadow
    self.shadowContainer = self:Create("Frame", {
        

        Size = UDim2.new(1, 35, 1, 35),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 0,

        Parent = self.main,
    })

    self.shadowImage = self:Create("ImageLabel", {
        Image = 'rbxassetid://5587865193',
        ImageColor3 = Color3.fromRGB(255, 255, 255),
        Size = UDim2.fromScale(1.6, 1.3),
        
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundTransparency = 1,
        ImageTransparency = 0.6,
        ZIndex = 0,
       
        Parent = self.shadowContainer
    })

    self.shadowGradient = self:Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(0.0784313725, 0.0784313725, 0.0784313725)),
            ColorSequenceKeypoint.new(1, Color3.new(0.0784313725, 0.0784313725, 0.0784313725))
        }),
        Rotation = 250,
        Offset = Vector2.new(0, 0.2),
        Parent = self.shadowImage,
    })


    -- Elements Preparation
    
    self.elements = self:Create("Frame", {
        

        Size = UDim2.new(1, 0, 1, -106),
        Position = UDim2.fromScale(0.5, 1),
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundTransparency = 1,
        ClipsDescendants = true,

        Parent = self.main,
    })

    self.elementsLayout = self:Create('UIPageLayout', {
        Padding = UDim.new(0, 0),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        EasingStyle = Enum.EasingStyle.Exponential,
        TweenTime = 0.4,

        Parent = self.elements
    })


    -- Tabs Preparation
    self.tabList = self:Create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 36),
        Position = UDim2.new(0.5, 0, 0, 68),
        AnchorPoint = Vector2.new(0.5, 0),
        
        BackgroundTransparency = 1,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X,

        Parent = self.main
    })

    self.tabListLayout = self:Create('UIListLayout', {
        Padding = UDim.new(0, 15),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.tabList
    })

    self:Create("Frame", {
        

        Size = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        LayoutOrder = -1,

        Parent = self.tabList
    })

    self:Create("Frame", {
        

        Size = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        LayoutOrder = 999999,

        Parent = self.tabList
    })

    -- Actions
    self.actionContainer = self:Create("Frame", {
        

        AnchorPoint = Vector2.new(1, 0.5),
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 24),
        Position = UDim2.new(1, -20, 0.5, 0),
        BackgroundTransparency = 1,

        Parent = self.topbar
    })

    self.actionsListLayout = self:Create('UIListLayout', {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.actionContainer
    })

    self.rfSettings = self:CreateTab({
        name = 'Rayfield Settings',
        customOrder = 1000,

        neglectSelector = true,
    })

    -- add require(script.Parent.action) as a variable idk where.

    require(script.Parent.action).new(self, {
        name = 'Close',
        icon = 83277910885129,
        order = 1,

        callback = function()
            print('close!')
        end
    })

    require(script.Parent.action).new(self, {
        name = 'Minimise',
        icon = 108115485663409,
        order = 2,

        callback = function()
            print('minimise!')
        end
    })

    require(script.Parent.action).new(self, {
        name = 'Settings',
        icon = 129180860773723,
        order = 3,

        callback = function()
            print('navigating to settings')
            self:Navigate(self.rfSettings.tabPage)
        end
    })

    require(script.Parent.action).new(self, {
        name = 'Search',
        icon = 100604009889706,
        order = 4,

        callback = function()
            print('search!')
        end
    })

    return self
end

function Window:ChangeTheme(theme)
    --assert(typeof(theme) == "table", "Invalid argument #1 (theme table expected)")
    -- ^ accepting strings and checking with a theme dict

    for name, value in theme do
        self.theme[name] = value
    end

    for instance, properties in self.themeProperties do
        for property, value in properties do
            instance[property] = if typeof(value) == "table"
                then value[2](self.theme[value[1]])
                else self.theme[value]
        end
    end
end

function Window:CreateTab(properties)
    return require(script.Parent.tab).new(self, properties)
end

function Window:Navigate(tab)
    if typeof(tab) == "string" then
        if self.elements[tab] then
            tab = self.elements[tab]
        end
    elseif tab:IsA("ScrollingFrame") then
        tab = tab
    end

    self.elementsLayout:JumpTo(tab)
end

function Window:Create(className, properties)
    local function hasProperty(object, prop)
        local _ins = object[prop]
    end

    local instance = Instance.new(className)
    if pcall(function() hasProperty(instance, 'BorderSizePixel') end) then instance.BorderSizePixel = 0 end -- BorderSizePixel is :(

    if properties then
        for property, value in properties do
            instance[property] = value
        end
    end

    if properties.theme then
        self.properties.theme[instance] = properties.theme
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
