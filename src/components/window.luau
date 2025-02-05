--!nocheck

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)

-- Themes
local themes = script.Parent.Parent.themes

-- Module
local Window = {}
Window.__index = Window

function Window.new(properties)
    local self = setmetatable({
        name = properties.name or properties.Name or "Rayfield Window",
        size = UDim2.fromOffset(475, 500), -- calculate sizing for mobile. use formula based on viewport?
        instances = {},
        connections = {},

        theme = if typeof(properties.theme or properties.Theme) == "string"
        then (properties.theme or properties.Theme)
        else themes[(properties.theme or properties.Theme)],
        
        configuration = {
            -- fix this being so long lma
            autoSave = (properties.configruation or properties.Configuration) and properties.configuration.autoSave, -- blah blah
            fileName = (properties.configruation or properties.Configuration) and (properties.Configuration.fileName or properties.configuration.fileName or properties.Configuration.FileName or properties.configuration.FileName),
            customFolder = (properties.configruation or properties.Configuration) and (properties.configuration.customFolder or properties.Configuration.CustomFolder or properties.Configuration.customFolder or properties.configuration.CustomFolder)
        }
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
    }, {BackgroundColor3 = 'SecondaryColor'})

    self.dividerBottom = self:Create("Frame", {
        
        
        Parent = self.main,
        Position = UDim2.new(0, 0, 0, 105),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.85
    }, {BackgroundColor3 = 'SecondaryColor'})

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
    -- ^ gonna be accepting strings and checking with a theme dict

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

function getPath()
    local path = 'Rayfield Gen2/Script Configurations/'
    
    if Window.customFolder then
        path = path..tostring(Window.configuration.customFolder)..'/'
    end

    path = path..tostring((Window.configuration.fileName or Window.name))..'.rfld'

    return path
end


-- save/load not done
-- add studio saving i.e save to datastore for testing w/out execs
function Window:Save()
    local path = getPath()

    assert(typeof(path) == "string", "Invalid argument #1 (string expected)")
    -- make custom assert func in utils !! to allow this
    assert(writefile ~= nil, "Failed to save configuration. No writing capabilities.")

    local flags = {}
    for flag, control in self.controls do
        local value = control.value
        if control.__type == "ColorPicker" then
            value = value:ToHex()
        elseif control.__type == "Keybind" then
            value = { tostring(value.EnumType), value.Value }
        end
        flags[flag] = value
    end

    local success, parsed = pcall(variables.httpService.JSONEncode, variables.httpService, flags)
    assert(success, "Failed to save configuration: failed to parse flags")
    utils.createDirectories(path) -- Create folders e.g Rayfield Gen2/ Script Configs blah blah etc/ etc
    writefile(path, parsed)
end

function Window:Load()
    local path = 'Rayfield Gen2/Script Configurations/CUSTOMFOLDER/'

    assert(typeof(path) == "string", "Invalid argument #1 (string expected)")
    assert(not isfile or isfile(path), "Can't load configuration, file doesn't exist.") -- no message is likely to be for production

    local config = assert(readfile and readfile(path), "Failed to load config: couldn't read config")
    local success, parsed = pcall(variables.httpService.JSONDecode, variables.httpService, config)

    assert(success, "Can't load configuration, the file has an issue decoding.")
    -- make new file with old data and call it CONFIGNAME (Incorrect Format).rfld
    -- then delete old file

    for flag, control in self.controls do
        local value = parsed[flag]
        if value ~= nil or control._canBeNil then
            if control.__type == "ColorPicker" then
                value = Color3.fromHex(value)
            end
            if control.__type == "Keybind" and value ~= nil then
                value = Enum[value[1]]:FromValue(value[2])
            end
            control:Set(value)
        end
    end
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

--[[ function Window:Create(className, properties, themeProperties)
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

    table.insert(self.instances, instance)
    return instance
end ]]

function Window:Create(className, properties, themeProperties)
    assert(typeof(className) == "string", "Invalid argument #1 (string expected)")
    local instance = Instance.new(className)

    if properties then
        for property, value in properties do
            instance[property] = value
        end
    end

    if themeProperties and self.theme then
        for property, value in themeProperties do
            instance[property] = (if typeof(value) == "table"
                then value[2](self.theme[value[1]])
                else self.theme[value])
        end

        self.themeProperties[instance] = themeProperties
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
