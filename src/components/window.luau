--!nocheck

-- Utility
local utility = script.Parent.Parent.utility
local SignalEngine = require(utility.SignalEngine)

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
        subheading = properties.subtitle or properties.Subtitle,
        size = UDim2.fromOffset(475, 500), -- calculate sizing for mobile. use formula based on viewport?
        instances = {},
        connections = {},

        icon = properties.icon or properties.Icon,

        themeProperties = {},
        tabs = {},
        selectedTab = nil,
        theme = if typeof(properties.theme or properties.Theme) == 'table'
        then (properties.theme or properties.Theme)
        elseif typeof(properties.theme or properties.Theme) == 'string' 
        then require(themes[string.lower((properties.theme or properties.Theme))]) -- check if theme exists first too...
        else require(themes['default']),

        signal = SignalEngine.new(),
        
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
        Enabled = true,
        DisplayOrder = 99999,

        Parent = variables.guiContainer,
    })

    -- Window
    self.main = self:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Name = self.name,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),

        -- Animations
        Size = UDim2.fromOffset((self.size.X.Offset - 50), 0),
        BackgroundTransparency = 1, -- In = 0
        Visible = false, -- In == true

        Parent = self.screenGui
    })

    self.drag = require(script.Parent.drag).new(self)

    self:Create("UICorner", {

        Parent = self.main
    }, {CornerRadius = 'CornerRoundness'})

    self.windowStroke = self:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        
        -- Animations
        Transparency = 1, -- In = 0.95

        Parent = self.main
    })

    self.windowGradient = self:Create("UIGradient", {
        Rotation = 250,
        Offset = Vector2.new(0, 0.2),

        Parent = self.main
    }, {Color = {'WindowColor', function(color)
        
        if typeof(color) == 'ColorSequence' then
            return color
        else
            return ColorSequence.new(color)
        end
    
    end }})


    -- Topbar
    self.topbar = self:Create("Frame", {
        
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 66),

        Parent = self.main
    })

    self.dividerTop = self:Create("Frame", {
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Position = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 0.85,
        
        
        -- Animations
        Size = UDim2.fromOffset(0, 1), -- In = 1, 0, 0, 1

        Parent = self.topbar
    }, {BackgroundColor3 = 'DividerColor'})

    self.dividerBottom = self:Create("Frame", {
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Position = UDim2.new(0, 0, 0, 105),
        BackgroundTransparency = 0.85,

        -- Animations
        Size = UDim2.fromOffset(0, 1), -- In = 1, 0, 0, 1

        Parent = self.main,
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
    }, 
        {
            Color = {'DividerColor', function(color)
                if typeof(color) == 'ColorSequence' then
                    return color
                else
                    return ColorSequence.new(color)
                end
            
            end 
    }})

    self.dividerBottomGradient = self:Create("UIGradient", {
        Parent = self.dividerBottom,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1, 0),
            NumberSequenceKeypoint.new(0.1, 0.75, 0),
            NumberSequenceKeypoint.new(0.300499, 0, 0),
            NumberSequenceKeypoint.new(0.5, 0.75, 0),
            NumberSequenceKeypoint.new(1, 1, 0)
        })
    },
        {
            Color = {'DividerColor', function(color)
                if typeof(color) == 'ColorSequence' then
                    return color
                else
                    return ColorSequence.new(color)
                end
            
            end 
    }})

    self.topContainer = self:Create("Frame", {
        Size = UDim2.new(0, 300, 0, 24),
        Position = UDim2.new(0, 25, 0.5, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        

        Parent = self.topbar
    })

    self.topContainerLayout = self:Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.topContainer
    })

    self.titleContainer = self:Create("Frame", {
        Size = UDim2.new(1, -42, 0, 24),
        Position = UDim2.new(0, 25, 0.5, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        LayoutOrder = 1,

        Parent = self.topContainer
    })

    self.titleContainerLayout = self:Create("UIListLayout", {
        Padding = UDim.new(0, 3),
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.titleContainer
    })

    if self.name then
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

            -- Animations
            TextTransparency = 1, -- In = 0
        
            Parent = self.titleContainer
        }, {FontFace = 'TitleFont', TextColor3 = 'TitlingColor'})
    end

    if self.icon then
        self.topbarIcon = self:Create('ImageLabel', {
            Image = 'rbxassetid://'..tostring(self.icon),

            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(32, 32),

            -- Animation
            ImageTransparency = 1, -- In = 0

            Parent = self.topContainer
        }, {ImageColor3 = 'TitlingColor'})
    end

    if self.subheading then
        self.subtitle = self:Create("TextLabel", {
            -- Configurables
            Text = self.subheading, -- window name

            Size = UDim2.new(1, 0, 0, 12),
            BackgroundTransparency = 1,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,

            -- Animations
            TextTransparency = 1, -- In = 0.7
        
            Parent = self.titleContainer
        }, {TextColor3 = 'TitlingColor', FontFace = 'Font'})
    end

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
        ZIndex = 0,

        -- Animations
        ImageTransparency = 1, -- In = 0.6
       
        Parent = self.shadowContainer
    })

    self.shadowGradient = self:Create("UIGradient", {
        Rotation = 250,
        Offset = Vector2.new(0, 0.2),
        Parent = self.shadowImage,
    }, { 
        Color = {'ShadowColor', function(color)
        if typeof(color) == 'ColorSequence' then
            return color
        else
            return ColorSequence.new(color)
        end
    end }})


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
            self.rfSettings:Select()
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


    if self.theme.LiveAnimation then
        task.spawn(function()
            local out = true
            local tweenInfo = TweenInfo.new(10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
        
            while true do
                local tweenS = variables.tweenService:Create(self.shadowGradient, tweenInfo, {
                    Offset = Vector2.new(if out then 0.4 else -0.2, 0), Rotation = (if out then 220 else 280)
                })
    
                local tweenW = variables.tweenService:Create(self.windowGradient, tweenInfo, {
                    Offset = Vector2.new(if out then 0.4 else -0.2, 0), Rotation = (if out then 220 else 280)
                })
                
                tweenW:Play()
                tweenS:Play()
                tweenS.Completed:Wait()
                out = not out
            end
        end)
    end

    
    self:Hide()

    return self
end

function Window:ChangeTheme(theme)
    --assert(typeof(theme) == "table", "Invalid argument #1 (theme table expected)")
    -- ^ gonna be accepting strings and checking with a theme dict

    theme = if typeof(theme) == 'table' then theme
        elseif typeof(theme) == 'string' and themes[string.lower(theme)]
        then require(themes[string.lower(theme)])
        else require(themes['default'])

    for name, value in theme do
        self.theme[name] = value
    end
    
    for instance, properties in self.themeProperties do
        for property, value in properties do
            local targetValue = if typeof(value) == "table"
                then value[2](self.theme[value[1]])
                else self.theme[value]

            if typeof(targetValue) == "Color3" or typeof(targetValue) == "number" then
                variables.tweenService:Create(instance, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {[property] = targetValue}):Play()
            else
                instance[property] = targetValue
            end
        end
    end
end

function Window:CreateTab(properties)
    local newTab = require(script.Parent.tab).new(self, properties)

    table.insert(self.tabs, newTab)
    return newTab
end

function Window:Hide()
    self.signal:Fire('hide')
end

function Window:Show()
    --self.signal:Fire('show')

    self.drag.drag.Visible = false
    self.main.Visible = true
    variables.tweenService:Create(self.main, TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut), {BackgroundTransparency = 0, Size = self.size}):Play()
    task.wait(0.5)
    variables.tweenService:Create(self.shadowImage, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = 0.6}):Play()
    task.wait(0.2)
    variables.tweenService:Create(self.dividerTop, TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0.85, Size = UDim2.new(1, 0, 0, 1)}):Play()
    task.wait(0.1)

    if self.icon then variables.tweenService:Create(self.topbarIcon, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = 0}):Play() end
    variables.tweenService:Create(self.title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
    task.wait(0.1)
    variables.tweenService:Create(self.subtitle, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0.7}):Play()



    task.wait(0.2)
    variables.tweenService:Create(self.dividerBottom, TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0.85, Size = UDim2.new(1, 0, 0, 1)}):Play()


    task.spawn(function()
        for _, tab in pairs(self.tabs) do
            if not tab.neglectSelector then
                tab.topbarItem.Visible = true

                if tab.icon then
                    variables.tweenService:Create(tab.topbarItemIcon, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = if self.selectedTab == tab then 0.1 else 0.65}):Play()
                end

                task.wait(0.04)
            
                if tab.name then
                    variables.tweenService:Create(tab.topbarItemTitle, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = if self.selectedTab == tab then 0.1 else 0.65}):Play()
                end

                task.wait(0.15)
            end
        end
    end)

    for _, tab in pairs(self.tabs) do
        if self.selectedTab == tab then
            for _, element in ipairs(tab.elements) do
                local elementValue = element[1]
                local elementType = element[2]
        
                variables.tweenService:Create(elementValue.stroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = self.theme.ElementStrokeTransparency}):Play()
                variables.tweenService:Create(elementValue.title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
                variables.tweenService:Create(elementValue.main, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
                if element.icon then variables.tweenService:Create(elementValue.icon, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = 0}):Play() end
        
                if elementType == 'toggle' then
                    variables.tweenService:Create(elementValue.indicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0.8}):Play()
                    variables.tweenService:Create(elementValue.indicatorStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = 0.7}):Play()
                    variables.tweenService:Create(elementValue.overlay, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
                    variables.tweenService:Create(elementValue.containerStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = 0.85}):Play()
                    variables.tweenService:Create(elementValue.functionContainer, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0.9}):Play()
                    -- this will be changed when :Set is ran after config is loaded.
                elseif elementType == 'button' then
        
                end

                --max out the wait at a certain amount of elements as to not have too long anims.
                task.wait(0.03)
            end
        else
            for _, element in ipairs(tab.elements) do
                local elementValue = element[1]
                local elementType = element[2]
    
                -- instant tween it all..
    
                if elementType == 'toggle' then
        
                elseif elementType == 'button' then
    
                end
            end
        end
    end

    task.wait(1)

    self.drag.drag.Visible = true
    variables.tweenService:Create(self.drag.dragCosmetic, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0.7}):Play()
    variables.tweenService:Create(self.drag.dragCosmetic, TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(100, 4)}):Play()
            
end

function getPath()
    local path = 'Rayfield Gen2/Script Configurations/'
    
    if Window.customFolder then
        path = path..tostring(Window.configuration.customFolder)..'/'
    end

    path = path..tostring((Window.configuration.fileName or Window.name))..'.rfld'

    return path
end

function Window:Modify(element, newValue)
    -- e.g change title or subtitle text
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

function Window:Create(className, properties, themeProperties)
    assert(typeof(className) == "string", "Invalid argument #1 (string expected)")
    local instance = Instance.new(className)

    if themeProperties and self.theme then
        for property, value in themeProperties do
            instance[property] = (if typeof(value) == "table"
                then value[2](self.theme[value[1]])
                else self.theme[value])
        end

        self.themeProperties[instance] = themeProperties
    end

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
