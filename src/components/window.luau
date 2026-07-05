--!nocheck

-- Utility
local utility = script.Parent.Parent.utility
local SignalEngine = require(utility.SignalEngine)
local filesystem = require(utility.filesystem)
local image = require(utility.image)

-- Variables
local variables = require(utility.variables)

-- Themes
local themes = script.Parent.Parent.themes

-- Module
local Window = {}
Window.__index = Window

function Window.new(properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        name = properties.name or properties.Name or "Rayfield Window",
        subheading = properties.subtitle or properties.Subtitle,
        size = UDim2.fromOffset(475, 500), -- calculate sizing for mobile. use formula based on viewport?
        instances = {},
        connections = {},

        icon = properties.icon or properties.Icon,
        showName = properties.showName or properties.ShowName or "Rayfield",
        showIcon = properties.showIcon or properties.ShowIcon or 80387863064905,

        themeProperties = {},
        tabs = {},
        tags = {},
        selectedTab = nil,
        theme = if typeof(properties.theme or properties.Theme) == 'table'
        then (properties.theme or properties.Theme)
        elseif typeof(properties.theme or properties.Theme) == 'string' and themes[string.lower(properties.theme or properties.Theme)]
        then require(themes[string.lower((properties.theme or properties.Theme))])
        else require(themes['default']),

        signal = SignalEngine.new(),
        
        controls = {},

        configuration = (function()
            local cfg = properties.configuration or properties.Configuration
            if not cfg then return {} end
            return {
                autoSave = cfg.autoSave or cfg.AutoSave,
                autoLoad = cfg.autoLoad or cfg.AutoLoad,
                fileName = cfg.fileName or cfg.FileName,
                customFolder = cfg.customFolder or cfg.CustomFolder,
            }
        end)()
    }, Window)

    -- Rayfield Gen2 Screen
    self.screenGui = self:Create("ScreenGui", {
        Name = variables.httpService:GenerateGUID(false),
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        Enabled = true,
        DisplayOrder = 99999,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,

        Parent = variables.guiContainer,
    })

    -- Window
    self.main = self:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Name = self.name,
        ZIndex = 1,
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
        Rotation = 270,
        Offset = Vector2.new(0, -0.1),

        Parent = self.main
    }, {Color = {'WindowColor', function(color)
        
        if typeof(color) == 'ColorSequence' then
            return color
        else
            return ColorSequence.new(color)
        end
    
    end }})

    -- Bottom fade — gradient overlay so elements scroll out softly at the window's base
    self.bottomFade = self:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, -0.093, 100),
        ZIndex = 100,

        -- Animation
        BackgroundTransparency = 1, -- In = 0

        Parent = self.main,
    })

    self:Create("UICorner", {
        Parent = self.bottomFade,
    }, {CornerRadius = 'CornerRoundness'})

    self.bottomFadeGradient = self:Create("UIGradient", {
        Rotation = 270,
        Offset = Vector2.new(0, 0.2),
        Color = ColorSequence.new(Color3.fromRGB(10, 10, 10)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.4414, 0),
            NumberSequenceKeypoint.new(0.7007, 0.631),
            NumberSequenceKeypoint.new(1, 1),
        }),

        Parent = self.bottomFade,
    })


    -- Topbar
    self.topbar = self:Create("Frame", {
        
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 66),

        Parent = self.main
    })

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
        Size = UDim2.fromOffset(50, 24),
        Position = UDim2.new(0, 25, 0.5, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
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

            Size = UDim2.fromOffset(50, 20),
            AutomaticSize = Enum.AutomaticSize.X,
            
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
            Image = self.icon,

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

            Size = UDim2.fromOffset(50, 12),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,

            -- Animations
            TextTransparency = 1, -- In = 0.7
        
            Parent = self.titleContainer
        }, {TextColor3 = 'TitlingColor', FontFace = 'Font'})
    end

    self.tagContainer = self:Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 25, 0.5, 0),
        Size = UDim2.fromOffset(50, 24),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Visible = false,

        Parent = self.topContainer,
    })

    self.tagContainerLayout = self:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.tagContainer
    })

    -- Shadow
    self.windowShadow = self:Create("UIShadow", {
        BlurRadius = UDim.new(0, 20),

        -- Animations
        Transparency = 1, -- In = 0.6
        ZIndex = -1,

        Parent = self.main,
    }, {Color = {'ShadowColor', function(color)
        if typeof(color) == 'ColorSequence' then
            return color.Keypoints[1].Value
        else
            return color
        end
    end}})


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
        Name = "Tabs",
        Active = true,
        Size = UDim2.new(1, 0, 0, 36),
        Position = UDim2.new(0.5, 0, 0, 66),
        AnchorPoint = Vector2.new(0.5, 0),
        
        BackgroundTransparency = 1,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X,

        Parent = self.main
    })

    self.tabListLayout = self:Create('UIListLayout', {
        Padding = UDim.new(0, 7),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.tabList
    })

    self:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 22),
        PaddingRight = UDim.new(0, 10),

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
            self:ToggleHide()
        end
    })

    require(script.Parent.action).new(self, {
        name = 'Minimise',
        icon = 108115485663409,
        order = 2,

        callback = function()
            self:ToggleMinimise()
        end
    })

    self.settingsAction = require(script.Parent.action).new(self, {
        name = 'Settings',
        icon = 129180860773723,
        order = 3,
        linkedTab = self.rfSettings,

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
            print('search')
        end
    })


    self.unloaded = false
    self.minimised = false
    self.hidden = true
    self.animating = false
    self.hasShownOnce = false

    self.settings = {
        toggleKeybind = Enum.KeyCode.K,
    }

    self:LoadSettings()
    self:_buildRestoreButton()
    self:_bindKeybind()
    self:_buildSettingsUI()
    self:_buildLicense()

    if self.theme.LiveAnimation then
        task.spawn(function()
            local out = true
            local tweenInfo = TweenInfo.new(10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

            while not self.unloaded do
                local tweenW = variables.tweenService:Create(self.windowGradient, tweenInfo, {
                    Offset = Vector2.new(if out then 0.4 else -0.2, 0), Rotation = (if out then 220 else 280)
                })

                tweenW:Play()
                tweenW.Completed:Wait()
                out = not out
            end
        end)
    end

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

    if not newTab.neglectSelector then
        local isFirstVisible = true
        for _, tab in self.tabs do
            if tab ~= newTab and not tab.neglectSelector then
                isFirstVisible = false
                break
            end
        end
        if isFirstVisible then
            newTab:Select(true)
        end
    end

    return newTab
end

function Window:CreateTag(properties)
    local newTag = require(script.Parent.tag).new(self, properties)
    table.insert(self.tags, newTag)
    return newTag
end

function Window:Hide()
    if self.animating then return end
    self.animating = true
    self.hidden = true
    variables.rayfieldHidden = true

    local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    self.drag.drag.Visible = false

    variables.tweenService:Create(self.main, fadeInfo, {BackgroundTransparency = 1}):Play()
    variables.tweenService:Create(self.windowShadow, fadeInfo, {Transparency =1}):Play()
    variables.tweenService:Create(self.bottomFade, fadeInfo, {BackgroundTransparency = 1}):Play()

    if self.title then variables.tweenService:Create(self.title, fadeInfo, {TextTransparency = 1}):Play() end
    if self.subtitle then variables.tweenService:Create(self.subtitle, fadeInfo, {TextTransparency = 1}):Play() end
    if self.topbarIcon then variables.tweenService:Create(self.topbarIcon, fadeInfo, {ImageTransparency = 1}):Play() end

    for _, action in ipairs(self.actionContainer:GetChildren()) do
        if action:IsA('Frame') then
            variables.tweenService:Create(action.ImageLabel, fadeInfo, {ImageTransparency = 1}):Play()
        end
    end

    for _, tag in self.tags do
        tag:_setShown(false, fadeInfo)
    end

    for _, tab in pairs(self.tabs) do
        if not tab.neglectSelector and tab.topbarItem then
            tab:_applyVisual('hidden', fadeInfo)
        end
    end

    task.delay(0.3, function()
        self.main.Visible = false

        self.elements.Visible = false
        self.tabList.Visible = false
        for _, tab in pairs(self.tabs) do
            if not tab.neglectSelector and tab.topbarItem then
                tab.topbarItem.Visible = false
            end
        end

        if self.restoreButton then
            self.restoreButton.Visible = true
        end

        self.animating = false
    end)
end

function Window:ToggleHide()
    if self.animating then return end
    if self.hidden then
        self:Show()
    else
        self:Hide()
    end
end

function Window:ToggleMinimise()
    if self.animating or self.hidden then return end
    self.animating = true

    if self.minimised then
        self.minimised = false

        local fadeInfo = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

        variables.tweenService:Create(self.main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
            Size = self.size,
        }):Play()

        variables.tweenService:Create(self.windowShadow, fadeInfo, {Transparency =0.6}):Play()
        variables.tweenService:Create(self.bottomFade, fadeInfo, {BackgroundTransparency = 0}):Play()

        variables.tweenService:Create(self.drag.drag, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
            Position = UDim2.new(
                self.main.Position.X.Scale, self.main.Position.X.Offset,
                self.main.Position.Y.Scale, self.main.Position.Y.Offset + self.size.Y.Offset / 2 + 15
            ),
        }):Play()

        task.delay(0.2, function()
            self.elements.Visible = true
            self.tabList.Visible = true

            for _, tab in pairs(self.tabs) do
                if not tab.neglectSelector and tab.topbarItem then
                    tab.topbarItem.Visible = true
                    tab:_applyVisual(if self.selectedTab == tab then 'selected' else 'unselected', fadeInfo)
                end
            end
        end)

        task.delay(0.5, function()
            self.animating = false
        end)
    else
        self.minimised = true

        self.elements.Visible = false
        self.tabList.Visible = false
        for _, tab in pairs(self.tabs) do
            if not tab.neglectSelector and tab.topbarItem then
                tab.topbarItem.Visible = false
            end
        end

        local fadeOutInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        variables.tweenService:Create(self.windowShadow, fadeOutInfo, {Transparency = 1}):Play()
        variables.tweenService:Create(self.bottomFade, fadeOutInfo, {BackgroundTransparency = 1}):Play()

        variables.tweenService:Create(self.main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(self.size.X.Offset, 66),
        }):Play()

        variables.tweenService:Create(self.drag.drag, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
            Position = UDim2.new(
                self.main.Position.X.Scale, self.main.Position.X.Offset,
                self.main.Position.Y.Scale, self.main.Position.Y.Offset + 66 / 2 + 15
            ),
        }):Play()

        task.delay(0.5, function()
            self.animating = false
        end)
    end
end

function Window:_buildRestoreButton()
    self.restoreButton = self:Create("Frame", {
        Name = "Show",
        Size = UDim2.fromOffset(185, 50),
        Position = UDim2.new(0.5, 0, 0, 20),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 100000,

        BackgroundTransparency = 0,

        Parent = self.screenGui,
    })

    self:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),

        Parent = self.restoreButton,
    })

    self.restoreStroke = self:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 0.9,

        Parent = self.restoreButton,
    })

    self:Create("UIGradient", {
        Rotation = 270,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 13, 13)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(27, 27, 27)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 35, 35)),
        }),

        Parent = self.restoreButton,
    })

    self.restoreIcon = self:Create("ImageLabel", {
        Name = "icon",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 16, 0.5, 0),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        Image = 'rbxassetid://'..tostring(self.showIcon),
        ZIndex = 100001,

        ImageTransparency = 0,

        Parent = self.restoreButton,
    })

    self:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),

        Parent = self.restoreIcon,
    })

    local textContainer = self:Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 50, 0.5, 0),
        Size = UDim2.new(1, -60, 0, 32),
        BackgroundTransparency = 1,
        ZIndex = 100001,

        Parent = self.restoreButton,
    })

    self:Create("UIListLayout", {
        Padding = UDim.new(0, 1),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = textContainer,
    })

    self.restoreLabel = self:Create("TextLabel", {
        Name = "Title",
        Text = self.showName,
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium),
        RichText = true,
        TextColor3 = Color3.fromRGB(240, 240, 240),
        TextSize = 16,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        ZIndex = 100001,

        TextTransparency = 0,

        Parent = textContainer,
    })

    self.restoreSubtitle = self:Create("TextLabel", {
        Name = "License",
        Text = "Tap to show",
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
        ZIndex = 100001,

        TextTransparency = 0.5,

        Parent = textContainer,
    })

    local restoreInteract = self:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        TextTransparency = 1,
        ZIndex = 100002,

        Parent = self.restoreButton,
    })

    self:Connect(restoreInteract.MouseButton1Click, function()
        self:ToggleHide()
    end)
end

function Window:_bindKeybind()
    self:Connect(variables.userInputService.InputBegan, function(input, processed)
        if processed then return end
        if input.KeyCode == self.settings.toggleKeybind then
            self:ToggleHide()
        end
    end)
end

function Window:_buildSettingsUI()
    self.rfSettings:CreateSection({ name = 'General' })

    self.rfSettings:CreateButton({
        name = 'Toggle Keybind: ' .. self.settings.toggleKeybind.Name,
        icon = 100604009889706,
        callback = function()
            print('Rayfield: Keybind changing will be available with the Keybind element.')
        end
    })

    self.rfSettings:CreateSection({ name = 'Window' })

    self.rfSettings:CreateButton({
        name = 'Reset Window Position',
        callback = function()
            variables.tweenService:Create(self.main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, 0, 0.5, 0),
            }):Play()
            variables.tweenService:Create(self.drag.drag, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, 0, 0.5, self.size.Y.Offset / 2 + 15),
            }):Play()
        end
    })
end

function Window:_buildLicense()
    -- "Signed in as" welcome card, shown once for a new/changed account (sits above the topbar)
    self.license = self:Create("Frame", {
        Name = "License",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 0, 65),
        Size = UDim2.fromOffset(200, 50),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 0,
        Visible = false,

        Parent = self.main,
    })

    self:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),

        Parent = self.license,
    })

    self.licenseStroke = self:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 1, -- In = 0.9

        Parent = self.license,
    })

    self:Create("UIGradient", {
        Rotation = 270,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 13, 13)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(27, 27, 27)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 35, 35)),
        }),

        Parent = self.license,
    })

    self.licenseAvatar = self:Create("ImageLabel", {
        Name = "Avatar",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 10, 0.5, 0),
        Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 0,
        Image = `rbxthumb://type=AvatarHeadShot&id={variables.localPlayer.UserId}&w=48&h=48`,

        -- Animation
        BackgroundTransparency = 1, -- In = 0.95
        ImageTransparency = 1, -- In = 0

        Parent = self.license,
    })

    self:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),

        Parent = self.licenseAvatar,
    })

    local container = self:Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 50, 0.5, 0),
        Size = UDim2.new(1, -60, 0, 32),
        BackgroundTransparency = 1,
        ZIndex = 0,

        Parent = self.license,
    })

    self:Create("UIListLayout", {
        Padding = UDim.new(0, 1),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = container,
    })

    self.licenseSubtitle = self:Create("TextLabel", {
        Name = "License",
        Text = "Signed in as",
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 0,

        -- Animation
        TextTransparency = 1, -- In = 0.5

        Parent = container,
    })

    self.licenseTitle = self:Create("TextLabel", {
        Name = "Title",
        Text = variables.localPlayer.DisplayName,
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium),
        RichText = true,
        TextColor3 = Color3.fromRGB(240, 240, 240),
        TextSize = 16,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        ZIndex = 0,

        -- Animation
        TextTransparency = 1, -- In = 0

        Parent = container,
    })
end

function Window:_isNewUser()
    -- No filesystem available — just show the banner every launch.
    if typeof(filesystem.isfile) ~= "function" or typeof(filesystem.writefile) ~= "function" then
        return true
    end

    local path = 'Rayfield/lastuser.txt'
    local currentId = tostring(variables.localPlayer.UserId)
    local isNew = true

    pcall(function()
        if filesystem.isfile(path) then
            isNew = filesystem.readfile(path) ~= currentId
        end
    end)

    pcall(function()
        if typeof(filesystem.isfolder) == "function" and not filesystem.isfolder('Rayfield') then
            filesystem.makefolder('Rayfield')
        end
        filesystem.writefile(path, currentId)
    end)

    return isNew
end

function Window:_setLicenseShown(shown, tweenInfo)
    -- Fade as well as slide, so if the window is minimised mid-animation the banner just
    -- fades out instead of being left abruptly clipped or repositioned.
    local targets = {
        [self.license] = { BackgroundTransparency = if shown then 0 else 1 },
        [self.licenseStroke] = { Transparency = if shown then 0.9 else 1 },
        [self.licenseAvatar] = { BackgroundTransparency = if shown then 0.95 else 1, ImageTransparency = if shown then 0 else 1 },
        [self.licenseSubtitle] = { TextTransparency = if shown then 0.5 else 1 },
        [self.licenseTitle] = { TextTransparency = if shown then 0 else 1 },
    }

    for instance, props in targets do
        if tweenInfo then
            variables.tweenService:Create(instance, tweenInfo, props):Play()
        else
            for property, value in props do
                instance[property] = value
            end
        end
    end
end

function Window:_playLicenseBanner()
    task.spawn(function()
        local slideInfo = TweenInfo.new(0.7, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

        self.license.Position = UDim2.new(0, 0, 0, 65)
        self:_setLicenseShown(false)
        self.license.Visible = true

        -- Slide down + fade in, hold ~3s, then slide back up + fade out and hide.
        variables.tweenService:Create(self.license, slideInfo, {Position = UDim2.new(0, 0, 0, -8)}):Play()
        self:_setLicenseShown(true, slideInfo)

        task.wait(3)

        variables.tweenService:Create(self.license, slideInfo, {Position = UDim2.new(0, 0, 0, 65)}):Play()
        self:_setLicenseShown(false, slideInfo)

        task.wait(0.7)
        self.license.Visible = false
    end)
end

function Window:GetSettingsPath()
    local dir = 'Rayfield/Settings'
    return dir, dir .. '/rayfield.rfld'
end

function Window:SaveSettings()
    local _, fullPath = self:GetSettingsPath()

    local data = {
        toggleKeybind = { tostring(self.settings.toggleKeybind.EnumType), self.settings.toggleKeybind.Value },
    }

    local ok, encoded = pcall(variables.httpService.JSONEncode, variables.httpService, data)
    if not ok then return false end

    local writeOk, err = pcall(function()
        local dir = self:GetSettingsPath()
        local parts = {}
        for part in string.gmatch(dir, "[^/]+") do
            table.insert(parts, part)
        end
        local built = ''
        for _, part in parts do
            built = if built == '' then part else built .. '/' .. part
            if not filesystem.isfolder(built) then
                filesystem.makefolder(built)
            end
        end

        filesystem.writefile(fullPath, encoded)
    end)

    if not writeOk then
        warn("Rayfield: Failed to save settings - " .. tostring(err))
        return false
    end

    return true
end

function Window:LoadSettings()
    local _, fullPath = self:GetSettingsPath()

    local fileExists = false
    pcall(function() fileExists = filesystem.isfile(fullPath) end)
    if not fileExists then return false end

    local readOk, config = pcall(filesystem.readfile, fullPath)
    if not readOk or not config then return false end

    local decodeOk, parsed = pcall(variables.httpService.JSONDecode, variables.httpService, config)
    if not decodeOk then return false end

    if parsed.toggleKeybind then
        pcall(function()
            self.settings.toggleKeybind = Enum[parsed.toggleKeybind[1]]:FromValue(parsed.toggleKeybind[2])
        end)
    end

    return true
end

function Window:_setElementsShown()
    for _, tab in pairs(self.tabs) do
        for _, element in ipairs(tab.elements) do
            local elementType = element.__type

            if elementType == 'Section' then
                element.title.TextTransparency = 0.6
                if element.iconLabel then element.iconLabel.ImageTransparency = 0.65 end
            else
                element.stroke.Transparency = self.theme.ElementStrokeTransparency
                element.title.TextTransparency = 0
                element.main.BackgroundTransparency = self.theme.ElementTransparency or 0
                if element.iconLabel then element.iconLabel.ImageTransparency = 0 end
                if element.descriptor then element.descriptor.titleLabel.TextTransparency = 0.7 end
            end

            if elementType == 'Toggle' then
                element.indicator.BackgroundTransparency = if element.value then 0 else 0.8
                element.indicatorStroke.Transparency = if element.value then 0 else 0.7
                element.indicatorGlow.Transparency = if element.value then 0.4 else 1
                element.overlay.BackgroundTransparency = 0
                element.containerStroke.Transparency = 0.85
                element.functionContainer.BackgroundTransparency = 0.9
            elseif elementType == 'Statistic' then
                element.gradientContainer.BackgroundTransparency = 0
                element.statGlow.Transparency = 0.4
                element.valueLabel.TextTransparency = 0
                element.changeLabel.TextTransparency = 0
            elseif elementType == 'Slider' then
                element.track.BackgroundTransparency = 0
                element.progress.BackgroundTransparency = 0
                element.handle.BackgroundTransparency = 0
                element.valueLabel.TextTransparency = 0.3
            elseif elementType == 'Dropdown' then
                element.selectedLabel.TextTransparency = 0.5
                element.chevron.ImageTransparency = 0.5
            end
        end
    end
end

function Window:Show()
    if self.animating then return end
    self.animating = true

    if self.configuration.autoLoad and self.hidden then
        self:Load()
    end

    self.hidden = false
    self.minimised = false
    variables.rayfieldHidden = false

    if self.restoreButton then
        self.restoreButton.Visible = false
    end

    if self.hasShownOnce then
        self:_quickRestore()
    else
        self.hasShownOnce = true
        self:_firstShow()
    end
end

function Window:_quickRestore()
    local fadeInfo = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

    self.main.Size = self.size
    self.main.Visible = true
    self.elements.Visible = true
    self.tabList.Visible = true

    self:_setElementsShown()

    variables.tweenService:Create(self.main, fadeInfo, {BackgroundTransparency = 0}):Play()
    variables.tweenService:Create(self.windowShadow, fadeInfo, {Transparency =0.6}):Play()
    variables.tweenService:Create(self.bottomFade, fadeInfo, {BackgroundTransparency = 0}):Play()

    if self.topbarIcon then variables.tweenService:Create(self.topbarIcon, fadeInfo, {ImageTransparency = 0}):Play() end
    if self.title then variables.tweenService:Create(self.title, fadeInfo, {TextTransparency = 0}):Play() end
    if self.subtitle then variables.tweenService:Create(self.subtitle, fadeInfo, {TextTransparency = 0.7}):Play() end

    for _, action in ipairs(self.actionContainer:GetChildren()) do
        if action:IsA('Frame') then
            variables.tweenService:Create(action.ImageLabel, fadeInfo, {ImageTransparency = 0.6}):Play()
        end
    end

    for _, tag in self.tags do
        tag:_setShown(true, fadeInfo)
    end

    for _, tab in pairs(self.tabs) do
        if not tab.neglectSelector and tab.topbarItem then
            tab.topbarItem.Visible = true
            tab:_applyVisual(if self.selectedTab == tab then 'selected' else 'unselected', fadeInfo)
        end
    end

    -- Drag handle
    self.drag.drag.Visible = true
    self.drag.dragCosmetic.Size = UDim2.fromOffset(100, 4)
    variables.tweenService:Create(self.drag.dragCosmetic, fadeInfo, {BackgroundTransparency = 0.7}):Play()

    task.delay(0.4, function()
        self.animating = false
    end)
end

function Window:_firstShow()
    -- Intro animation
    self.elements.Visible = true
    self.tabList.Visible = true

    self.drag.drag.Visible = false
    self.main.Visible = true
    variables.tweenService:Create(self.main, TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut), {BackgroundTransparency = 0, Size = self.size}):Play()
    task.wait(0.5)
    variables.tweenService:Create(self.windowShadow, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = 0.6}):Play()
    variables.tweenService:Create(self.bottomFade, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
    task.wait(0.3)

    if self.icon then variables.tweenService:Create(self.topbarIcon, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = 0}):Play() end
    if self.title then variables.tweenService:Create(self.title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0}):Play() end
    task.wait(0.1)
    if self.subtitle then variables.tweenService:Create(self.subtitle, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0.7}):Play() end

    for _, action in ipairs(self.actionContainer:GetChildren()) do
        if action:IsA('Frame') then
            task.wait(0.02)
            variables.tweenService:Create(action.ImageLabel, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = 0.6}):Play()
        end
    end

    for _, tag in self.tags do
        tag:_setShown(true, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out))
    end

    task.wait(0.2)

    task.spawn(function()
        for _, tab in pairs(self.tabs) do
            if not tab.neglectSelector then
                tab.topbarItem.Visible = true
                tab:_applyVisual(if self.selectedTab == tab then 'selected' else 'unselected', TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))

                task.wait(0.15)
            end
        end
    end)

    for _, tab in pairs(self.tabs) do
        if self.selectedTab == tab then
            local perElementDelay = 0.03
            local maxStaggeredElements = math.floor(2 / perElementDelay)

            for elementIndex, element in ipairs(tab.elements) do
                local elementType = element.__type

                if elementType == 'Section' then
                    variables.tweenService:Create(element.title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0.6}):Play()
                    if element.iconLabel then variables.tweenService:Create(element.iconLabel, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = 0.65}):Play() end
                else
                    variables.tweenService:Create(element.stroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = self.theme.ElementStrokeTransparency}):Play()
                    variables.tweenService:Create(element.title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
                    variables.tweenService:Create(element.main, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
                    if element.iconLabel then variables.tweenService:Create(element.iconLabel, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = 0}):Play() end
                    if element.descriptor then variables.tweenService:Create(element.descriptor.titleLabel, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0.7}):Play() end
                end

                if elementType == 'Toggle' then
                    variables.tweenService:Create(element.indicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = element.value and 0 or 0.8}):Play()
                    variables.tweenService:Create(element.indicatorStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = element.value and 0 or 0.7}):Play()
                    variables.tweenService:Create(element.indicatorGlow, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = element.value and 0.4 or 1}):Play()
                    variables.tweenService:Create(element.overlay, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
                    variables.tweenService:Create(element.containerStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = 0.85}):Play()
                    variables.tweenService:Create(element.functionContainer, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0.9}):Play()
                elseif elementType == 'Button' then

                elseif elementType == 'Statistic' then
                    variables.tweenService:Create(element.gradientContainer, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
                    variables.tweenService:Create(element.statGlow, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = 0.4}):Play()
                    variables.tweenService:Create(element.valueLabel, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
                    variables.tweenService:Create(element.changeLabel, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
                elseif elementType == 'Slider' then
                    variables.tweenService:Create(element.track, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
                    variables.tweenService:Create(element.progress, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
                    variables.tweenService:Create(element.handle, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
                    variables.tweenService:Create(element.valueLabel, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0.3}):Play()
                elseif elementType == 'Dropdown' then
                    variables.tweenService:Create(element.selectedLabel, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0.5}):Play()
                    variables.tweenService:Create(element.chevron, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = 0.5}):Play()
                end

                if elementIndex <= maxStaggeredElements then
                    task.wait(perElementDelay)
                end
            end
        else
            for _, element in ipairs(tab.elements) do
                local elementType = element.__type

                if elementType == 'Section' then
                    element.title.TextTransparency = 0.6
                    if element.iconLabel then element.iconLabel.ImageTransparency = 0.65 end
                else
                    element.stroke.Transparency = self.theme.ElementStrokeTransparency
                    element.title.TextTransparency = 0
                    element.main.BackgroundTransparency = 0
                    if element.iconLabel then element.iconLabel.ImageTransparency = 0 end
                    if element.descriptor then element.descriptor.titleLabel.TextTransparency = 0.7 end
                end

                if elementType == 'Toggle' then
                    element.indicator.BackgroundTransparency = if element.value then 0 else 0.8
                    element.indicatorStroke.Transparency = if element.value then 0 else 0.7
                    element.indicatorGlow.Transparency = if element.value then 0.4 else 1
                    element.overlay.BackgroundTransparency = 0
                    element.containerStroke.Transparency = 0.85
                    element.functionContainer.BackgroundTransparency = 0.9
                elseif elementType == 'Statistic' then
                    element.gradientContainer.BackgroundTransparency = 0
                    element.statGlow.Transparency = 0.4
                    element.valueLabel.TextTransparency = 0
                    element.changeLabel.TextTransparency = 0
                elseif elementType == 'Slider' then
                    element.track.BackgroundTransparency = 0
                    element.progress.BackgroundTransparency = 0
                    element.handle.BackgroundTransparency = 0
                    element.valueLabel.TextTransparency = 0.3
                elseif elementType == 'Dropdown' then
                    element.selectedLabel.TextTransparency = 0.5
                    element.chevron.ImageTransparency = 0.5
                end
            end
        end
    end

    task.wait(1)

    self.drag.drag.Visible = true
    variables.tweenService:Create(self.drag.dragCosmetic, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0.7}):Play()
    variables.tweenService:Create(self.drag.dragCosmetic, TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(100, 4)}):Play()

    self.animating = false

    -- Welcome the user once if this is a new/changed account on this device.
    if self:_isNewUser() then
        self:_playLicenseBanner()
    end
end

function Window:GetPath()
    local dir = 'Rayfield/Configurations'

    if self.configuration.customFolder then
        dir = dir .. '/' .. tostring(self.configuration.customFolder)
    end

    local fileName = tostring(self.configuration.fileName or self.name) .. '.rfld'

    return dir, dir .. '/' .. fileName
end

function Window:EnsureDirectory()
    local dir = self:GetPath()

    local parts = {}
    for part in string.gmatch(dir, "[^/]+") do
        table.insert(parts, part)
    end

    local built = ''
    for _, part in parts do
        built = if built == '' then part else built .. '/' .. part
        if not filesystem.isfolder(built) then
            filesystem.makefolder(built)
        end
    end
end

function Window:Modify(element, newValue)
    -- e.g change title or subtitle text
end

function Window:Save()
    local _, fullPath = self:GetPath()

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

    local encodeSuccess, encoded = pcall(variables.httpService.JSONEncode, variables.httpService, flags)
    if not encodeSuccess then
        warn("Rayfield: Failed to encode configuration - " .. tostring(encoded))
        return false
    end

    local ok, err = pcall(function()
        self:EnsureDirectory()
        filesystem.writefile(fullPath, encoded)
    end)

    if not ok then
        warn("Rayfield: Failed to save configuration - " .. tostring(err))
        return false
    end

    return true
end

function Window:Load()
    local dir, fullPath = self:GetPath()

    if not filesystem.isfile(fullPath) then return false end

    local readOk, config = pcall(filesystem.readfile, fullPath)
    if not readOk or not config then
        warn("Rayfield: Failed to read configuration file")
        return false
    end

    local decodeOk, parsed = pcall(variables.httpService.JSONDecode, variables.httpService, config)

    if not decodeOk then
        -- Backup the corrupt file and remove the original
        warn("Rayfield: Configuration file has an invalid format, backing up and resetting")
        local backupPath = dir .. '/' .. tostring(self.configuration.fileName or self.name) .. ' (Incorrect Format).rfld'
        pcall(function()
            self:EnsureDirectory()
            filesystem.writefile(backupPath, config)
            filesystem.delfile(fullPath)
        end)
        return false
    end

    for flag, control in self.controls do
        local value = parsed[flag]
        if value ~= nil or control._canBeNil then
            if control.__type == "ColorPicker" then
                value = Color3.fromHex(value)
            end
            if control.__type == "Keybind" and value ~= nil then
                value = Enum[value[1]]:FromValue(value[2])
            end
            control:Set(value, true)
        end
    end

    return true
end

function Window:Navigate(tab)
    if typeof(tab) == "string" then
        local found = self.elements:FindFirstChild(tab)
        if found then
            tab = found
        end
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
            image.assign(instance, property, value)
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
    self.unloaded = true
    for i = #self.connections, 1, -1 do
        self.connections[i]:Disconnect()
    end
    for i = #self.instances, 1, -1 do
        self.instances[i]:Destroy()
    end
end

return Window
