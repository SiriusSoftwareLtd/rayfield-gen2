--!nocheck

-- Utility
local utility = script.Parent.Parent.utility
local image = require(utility.image)
local functions = require(utility.functions)
local persistence = require(utility.persistence)
local constants = require(utility.constants)
local chrome = require(script.Parent.chrome)

-- Variables
local variables = require(utility.variables)

-- Themes
local themes = script.Parent.Parent.themes

-- Module
local Window = {}
Window.__index = Window

-- Default entrance-reveal tween (elements override with their own where needed)
local REVEAL_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

-- Resolve a theme arg (table or name) to a fresh table. We copy so ChangeTheme never
-- mutates the required theme module, which require() caches and shares between windows.
local function resolveTheme(value)
    local source = if typeof(value) == "table"
        then value
        elseif typeof(value) == "string" and themes:FindFirstChild(string.lower(value)) then require(
            themes[string.lower(value)]
        )
        else require(themes["default"])

    return table.clone(source)
end

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
        theme = resolveTheme(properties.theme or properties.Theme),

        controls = {},

        configuration = (function()
            local cfg = properties.configuration or properties.Configuration
            if not cfg then
                return {}
            end
            return {
                autoSave = cfg.autoSave or cfg.AutoSave,
                autoLoad = cfg.autoLoad or cfg.AutoLoad,
                fileName = cfg.fileName or cfg.FileName,
                customFolder = cfg.customFolder or cfg.CustomFolder,
            }
        end)(),
    }, Window)

    -- Rayfield Gen2 Screen
    self.screenGui = self:Create("ScreenGui", {
        Name = variables.httpService:GenerateGUID(false),
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        Enabled = true,
        DisplayOrder = constants.displayOrder.window,
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

        Parent = self.screenGui,
    })

    self.drag = require(script.Parent.drag).new(self)

    self:Create("UICorner", {

        Parent = self.main,
    }, { CornerRadius = "CornerRoundness" })

    self.windowStroke = self:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),

        -- Animations
        Transparency = 1, -- In = 0.95

        Parent = self.main,
    })

    self.windowGradient = self:Create("UIGradient", {
        Rotation = 270,
        Offset = Vector2.new(0, -0.1),

        Parent = self.main,
    }, { Color = { "WindowColor", functions.toColorSequence } })

    -- Bottom fade - gradient overlay so elements scroll out softly at the window's base
    self.bottomFade = self:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, -0.093, 100),
        ZIndex = constants.zIndex.bottomFade,

        -- Animation
        BackgroundTransparency = 1, -- In = 0

        Parent = self.main,
    })

    self:Create("UICorner", {
        Parent = self.bottomFade,
    }, { CornerRadius = "CornerRoundness" })

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

        Parent = self.main,
    })

    self.topContainer = self:Create("Frame", {
        Size = UDim2.new(0, 300, 0, 24),
        Position = UDim2.new(0, 25, 0.5, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,

        Parent = self.topbar,
    })

    self.topContainerLayout = self:Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.topContainer,
    })

    self.titleContainer = self:Create("Frame", {
        Size = UDim2.fromOffset(50, 24),
        Position = UDim2.new(0, 25, 0.5, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        LayoutOrder = 1,

        Parent = self.topContainer,
    })

    self.titleContainerLayout = self:Create("UIListLayout", {
        Padding = UDim.new(0, 3),
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.titleContainer,
    })

    if self.name then
        self.title = self:Create("TextLabel", {
            -- Configurables
            Text = self.name, -- window name

            -- Theming
            TextColor3 = Color3.fromRGB(255, 255, 255),
            FontFace = Font.new(constants.fontAsset, Enum.FontWeight.SemiBold),

            Size = UDim2.fromOffset(50, 20),
            AutomaticSize = Enum.AutomaticSize.X,

            BackgroundTransparency = 1,
            TextSize = 20,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,

            -- Animations
            TextTransparency = 1, -- In = 0

            Parent = self.titleContainer,
        }, { FontFace = "TitleFont", TextColor3 = "TitlingColor" })
    end

    if self.icon then
        self.topbarIcon = self:Create("ImageLabel", {
            Image = self.icon,

            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(32, 32),

            -- Animation
            ImageTransparency = 1, -- In = 0

            Parent = self.topContainer,
        }, { ImageColor3 = "TitlingColor" })
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

            Parent = self.titleContainer,
        }, { TextColor3 = "TitlingColor", FontFace = "Font" })
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

        Parent = self.tagContainer,
    })

    -- Shadow
    self.windowShadow = self:Create("UIShadow", {
        BlurRadius = UDim.new(0, 20),

        -- Animations
        Transparency = 1, -- In = 0.6
        ZIndex = -1,

        Parent = self.main,
    }, {
        Color = {
            "ShadowColor",
            function(color)
                if typeof(color) == "ColorSequence" then
                    return color.Keypoints[1].Value
                else
                    return color
                end
            end,
        },
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

    self.elementsLayout = self:Create("UIPageLayout", {
        Padding = UDim.new(0, 0),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        EasingStyle = Enum.EasingStyle.Exponential,
        TweenTime = 0.4,

        Parent = self.elements,
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

        Parent = self.main,
    })

    self.tabListLayout = self:Create("UIListLayout", {
        Padding = UDim.new(0, 7),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.tabList,
    })

    self:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 22),
        PaddingRight = UDim.new(0, 10),

        Parent = self.tabList,
    })

    -- Actions
    self.actionContainer = self:Create("Frame", {

        AnchorPoint = Vector2.new(1, 0.5),
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 24),
        Position = UDim2.new(1, -20, 0.5, 0),
        BackgroundTransparency = 1,

        Parent = self.topbar,
    })

    self.actionsListLayout = self:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.actionContainer,
    })

    self.rfSettings = self:CreateTab({
        name = "Rayfield Settings",
        customOrder = 1000,

        neglectSelector = true,
    })

    require(script.Parent.action).new(self, {
        name = "Close",
        icon = 83277910885129,
        order = 1,

        callback = function()
            self:ToggleHide()
        end,
    })

    require(script.Parent.action).new(self, {
        name = "Minimise",
        icon = 108115485663409,
        order = 2,

        callback = function()
            self:ToggleMinimise()
        end,
    })

    self.settingsAction = require(script.Parent.action).new(self, {
        name = "Settings",
        icon = 129180860773723,
        order = 3,
        linkedTab = self.rfSettings,

        callback = function()
            self.rfSettings:Select()
        end,
    })

    require(script.Parent.action).new(self, {
        name = "Search",
        icon = 100604009889706,
        order = 4,

        callback = function()
            -- TODO: search isn't wired up yet
        end,
    })

    self.unloaded = false
    self.minimised = false
    self.hidden = true
    self.animating = false
    self.hasShownOnce = false

    self.settings = {
        toggleKeybind = Enum.KeyCode.K,
        mouseOverride = true, -- free the cursor while the menu is open (for FPS games that lock it)
        keepOnScreen = true, -- clamp the drag so the window cant be pulled off screen
    }

    self:LoadSettings()
    chrome.buildRestoreButton(self)
    self:_bindKeybind()
    self:_bindMouseOverride()
    self:_buildSettingsUI()
    chrome.buildLicense(self)

    if self.theme.LiveAnimation then
        task.spawn(function()
            local out = true
            local tweenInfo = TweenInfo.new(10, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

            while not self.unloaded do
                local tweenW = variables.tweenService:Create(self.windowGradient, tweenInfo, {
                    Offset = Vector2.new(if out then 0.4 else -0.2, 0),
                    Rotation = (if out then 220 else 280),
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
    theme = resolveTheme(theme)

    for name, value in theme do
        self.theme[name] = value
    end

    for instance, properties in self.themeProperties do
        for property, value in properties do
            local targetValue = if typeof(value) == "table" then value[2](self.theme[value[1]]) else self.theme[value]

            if typeof(targetValue) == "Color3" or typeof(targetValue) == "number" then
                variables.tweenService
                    :Create(
                        instance,
                        TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                        { [property] = targetValue }
                    )
                    :Play()
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

-- Register a saveable control under its flag. Keeps flags unique so two same-named
-- elements dont clobber each other's saved value. Updates control.flag to the key we
-- actually stored under and returns it.
function Window:_registerControl(control)
    if not control.flag or control.flag == "" or control.forgetState then
        return
    end

    local flag = control.flag
    if self.controls[flag] then
        local n = 2
        while self.controls[flag .. n] do
            n += 1
        end
        flag = flag .. n
        warn("Rayfield: duplicate config flag '" .. control.flag .. "', saving this one as '" .. flag .. "'")
    end

    control.flag = flag
    self.controls[flag] = control
    return flag
end

function Window:Notify(properties)
    if not self.notifications then
        self.notifications = self:Create("Frame", {
            Name = "Notifications",
            Size = UDim2.new(0, 300, 0, 800),
            Position = UDim2.new(1, -20, 1, -20),
            AnchorPoint = Vector2.new(1, 1),
            BackgroundTransparency = 1,

            Parent = self.screenGui,
        })

        self:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            -- No padding here: the gap lives inside each notification so removing
            -- one doesn't drop an external gap and jolt the stack.
            Padding = UDim.new(0, 0),

            Parent = self.notifications,
        })
    end

    return require(script.Parent.notification).new(self, properties)
end

function Window:Hide()
    if self.animating then
        return
    end
    self.animating = true
    self.hidden = true
    variables.rayfieldHidden = true

    local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    self.drag.drag.Visible = false

    variables.tweenService:Create(self.main, fadeInfo, { BackgroundTransparency = 1 }):Play()
    variables.tweenService:Create(self.windowShadow, fadeInfo, { Transparency = 1 }):Play()
    variables.tweenService:Create(self.bottomFade, fadeInfo, { BackgroundTransparency = 1 }):Play()

    if self.title then
        variables.tweenService:Create(self.title, fadeInfo, { TextTransparency = 1 }):Play()
    end
    if self.subtitle then
        variables.tweenService:Create(self.subtitle, fadeInfo, { TextTransparency = 1 }):Play()
    end
    if self.topbarIcon then
        variables.tweenService:Create(self.topbarIcon, fadeInfo, { ImageTransparency = 1 }):Play()
    end

    for _, action in ipairs(self.actionContainer:GetChildren()) do
        if action:IsA("Frame") then
            variables.tweenService:Create(action.ImageLabel, fadeInfo, { ImageTransparency = 1 }):Play()
        end
    end

    for _, tag in self.tags do
        tag:_setShown(false, fadeInfo)
    end

    for _, tab in pairs(self.tabs) do
        if not tab.neglectSelector and tab.topbarItem then
            tab:_applyVisual("hidden", fadeInfo)
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
    if self.animating then
        return
    end
    if self.hidden then
        self:Show()
    else
        self:Hide()
    end
end

function Window:ToggleMinimise()
    if self.animating or self.hidden then
        return
    end
    self.animating = true

    if self.minimised then
        self.minimised = false

        local fadeInfo = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

        variables.tweenService
            :Create(self.main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                Size = self.size,
            })
            :Play()

        variables.tweenService:Create(self.windowShadow, fadeInfo, { Transparency = 0.6 }):Play()
        variables.tweenService:Create(self.bottomFade, fadeInfo, { BackgroundTransparency = 0 }):Play()

        variables.tweenService
            :Create(self.drag.drag, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                Position = UDim2.new(
                    self.main.Position.X.Scale,
                    self.main.Position.X.Offset,
                    self.main.Position.Y.Scale,
                    self.main.Position.Y.Offset + self.size.Y.Offset / 2 + 15
                ),
            })
            :Play()

        task.delay(0.2, function()
            self.elements.Visible = true
            self.tabList.Visible = true

            for _, tab in pairs(self.tabs) do
                if not tab.neglectSelector and tab.topbarItem then
                    tab.topbarItem.Visible = true
                    tab:_applyVisual(if self.selectedTab == tab then "selected" else "unselected", fadeInfo)
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
        variables.tweenService:Create(self.windowShadow, fadeOutInfo, { Transparency = 1 }):Play()
        variables.tweenService:Create(self.bottomFade, fadeOutInfo, { BackgroundTransparency = 1 }):Play()

        variables.tweenService
            :Create(self.main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                Size = UDim2.fromOffset(self.size.X.Offset, 66),
            })
            :Play()

        variables.tweenService
            :Create(self.drag.drag, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                Position = UDim2.new(
                    self.main.Position.X.Scale,
                    self.main.Position.X.Offset,
                    self.main.Position.Y.Scale,
                    self.main.Position.Y.Offset + 66 / 2 + 15
                ),
            })
            :Play()

        task.delay(0.5, function()
            self.animating = false
        end)
    end
end

function Window:_bindKeybind()
    self:Connect(variables.userInputService.InputBegan, function(input, processed)
        if processed then
            return
        end
        if input.KeyCode == self.settings.toggleKeybind then
            self:ToggleHide()
        end
    end)
end

function Window:_bindMouseOverride()
    local uis = variables.userInputService

    local function active()
        return self.settings.mouseOverride and not self.hidden and not self.minimised
    end

    local function free()
        if not active() then
            return
        end
        if uis.MouseBehavior ~= Enum.MouseBehavior.Default then
            uis.MouseBehavior = Enum.MouseBehavior.Default
        end
        if not uis.MouseIconEnabled then
            uis.MouseIconEnabled = true
        end
    end

    -- react to the game re-locking instead of racing it each frame. it sets LockCenter, we set
    -- it back, so we always get the last word. same deal if it hides the mouse icon.
    self:Connect(uis:GetPropertyChangedSignal("MouseBehavior"), free)
    self:Connect(uis:GetPropertyChangedSignal("MouseIconEnabled"), free)

    -- Show calls this on open to free the cursor immediately (the signals above only fire on change)
    self._freeMouse = free
end

function Window:_buildSettingsUI()
    self.rfSettings:CreateSection({ name = "General" })

    self.rfSettings:CreateButton({
        name = "Toggle Keybind: " .. self.settings.toggleKeybind.Name,
        icon = 100604009889706,
        callback = function()
            print("Rayfield: Keybind changing will be available with the Keybind element.")
        end,
    })

    self.rfSettings:CreateToggle({
        name = "Unlock cursor while open",
        description = "Unlocks the cursor while the menu is open so you can configure in FPS games that lock it.",
        value = self.settings.mouseOverride,
        forgetState = true, -- lives in settings.rfld, not the user's config
        callback = function(state)
            self.settings.mouseOverride = state
            self:SaveSettings()
        end,
    })

    self.rfSettings:CreateSection({ name = "Window" })

    self.rfSettings:CreateToggle({
        name = "Keep window on screen",
        description = "Stops the window being dragged off the edge of the screen and lost.",
        value = self.settings.keepOnScreen,
        forgetState = true, -- lives in settings.rfld, not the user's config
        callback = function(state)
            self.settings.keepOnScreen = state
            self:SaveSettings()
        end,
    })

    self.rfSettings:CreateButton({
        name = "Reset Window Position",
        callback = function()
            variables.tweenService
                :Create(self.main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                })
                :Play()
            variables.tweenService
                :Create(self.drag.drag, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                    Position = UDim2.new(0.5, 0, 0.5, self.size.Y.Offset / 2 + 15),
                })
                :Play()
        end,
    })
end

function Window:SaveSettings()
    return persistence.saveSettings(self)
end

function Window:LoadSettings()
    return persistence.loadSettings(self)
end

function Window:_setElementsShown()
    for _, tab in pairs(self.tabs) do
        for _, element in ipairs(tab.elements) do
            element:_setShown(false)
        end
    end
end

function Window:Show()
    if self.animating then
        return
    end
    self.animating = true

    if self.configuration.autoLoad and self.hidden then
        self:Load()
    end

    self.hidden = false
    self.minimised = false
    variables.rayfieldHidden = false

    if self._freeMouse then
        self._freeMouse()
    end

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

    variables.tweenService:Create(self.main, fadeInfo, { BackgroundTransparency = 0 }):Play()
    variables.tweenService:Create(self.windowShadow, fadeInfo, { Transparency = 0.6 }):Play()
    variables.tweenService:Create(self.bottomFade, fadeInfo, { BackgroundTransparency = 0 }):Play()

    if self.topbarIcon then
        variables.tweenService:Create(self.topbarIcon, fadeInfo, { ImageTransparency = 0 }):Play()
    end
    if self.title then
        variables.tweenService:Create(self.title, fadeInfo, { TextTransparency = 0 }):Play()
    end
    if self.subtitle then
        variables.tweenService:Create(self.subtitle, fadeInfo, { TextTransparency = 0.7 }):Play()
    end

    for _, action in ipairs(self.actionContainer:GetChildren()) do
        if action:IsA("Frame") then
            variables.tweenService:Create(action.ImageLabel, fadeInfo, { ImageTransparency = 0.6 }):Play()
        end
    end

    for _, tag in self.tags do
        tag:_setShown(true, fadeInfo)
    end

    for _, tab in pairs(self.tabs) do
        if not tab.neglectSelector and tab.topbarItem then
            tab.topbarItem.Visible = true
            tab:_applyVisual(if self.selectedTab == tab then "selected" else "unselected", fadeInfo)
        end
    end

    -- Drag handle
    self.drag.drag.Visible = true
    self.drag.dragCosmetic.Size = UDim2.fromOffset(100, 4)
    variables.tweenService:Create(self.drag.dragCosmetic, fadeInfo, { BackgroundTransparency = 0.7 }):Play()

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
    variables.tweenService
        :Create(
            self.main,
            TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut),
            { BackgroundTransparency = 0, Size = self.size }
        )
        :Play()
    task.wait(0.5)
    variables.tweenService
        :Create(
            self.windowShadow,
            TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
            { Transparency = 0.6 }
        )
        :Play()
    variables.tweenService
        :Create(
            self.bottomFade,
            TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
            { BackgroundTransparency = 0 }
        )
        :Play()
    task.wait(0.3)

    if self.icon then
        variables.tweenService
            :Create(
                self.topbarIcon,
                TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
                { ImageTransparency = 0 }
            )
            :Play()
    end
    if self.title then
        variables.tweenService
            :Create(
                self.title,
                TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
                { TextTransparency = 0 }
            )
            :Play()
    end
    task.wait(0.1)
    if self.subtitle then
        variables.tweenService
            :Create(
                self.subtitle,
                TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
                { TextTransparency = 0.7 }
            )
            :Play()
    end

    for _, action in ipairs(self.actionContainer:GetChildren()) do
        if action:IsA("Frame") then
            task.wait(0.02)
            variables.tweenService
                :Create(
                    action.ImageLabel,
                    TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
                    { ImageTransparency = 0.6 }
                )
                :Play()
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
                tab:_applyVisual(
                    if self.selectedTab == tab then "selected" else "unselected",
                    TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                )

                task.wait(0.15)
            end
        end
    end)

    for _, tab in pairs(self.tabs) do
        if self.selectedTab == tab then
            local perElementDelay = 0.03
            local maxStaggeredElements = math.floor(2 / perElementDelay)

            for elementIndex, element in ipairs(tab.elements) do
                element:_setShown(true)

                if elementIndex <= maxStaggeredElements then
                    task.wait(perElementDelay)
                end
            end
        else
            for _, element in ipairs(tab.elements) do
                element:_setShown(false)
            end
        end
    end

    task.wait(1)

    self.drag.drag.Visible = true
    variables.tweenService
        :Create(
            self.drag.dragCosmetic,
            TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
            { BackgroundTransparency = 0.7 }
        )
        :Play()
    variables.tweenService
        :Create(
            self.drag.dragCosmetic,
            TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
            { Size = UDim2.fromOffset(100, 4) }
        )
        :Play()

    self.animating = false

    -- Welcome the user once if this is a new/changed account on this device.
    if chrome.isNewUser() then
        chrome.playLicenseBanner(self)
    end
end

function Window:GetPath()
    return persistence.getPath(self)
end

function Window:Save()
    return persistence.save(self)
end

function Window:Load()
    return persistence.load(self)
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
            instance[property] = (
                if typeof(value) == "table" then value[2](self.theme[value[1]]) else self.theme[value]
            )
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

-- Soft glow behind a GuiObject via a native UIShadow (no image). ZIndex -1 keeps it behind.
function Window:CreateGlow(parent, color, blur, transparency)
    return self:Create("UIShadow", {
        Color = color,
        BlurRadius = UDim.new(0, blur),
        Transparency = transparency,
        ZIndex = -1,

        Parent = parent,
    })
end

-- Additive white hover-brighten overlay filling an element (fill colour comes from the gradient).
-- Tween its BackgroundTransparency 1 -> ~0.97 on hover.
function Window:CreateHoverOverlay(parent)
    local overlay = self:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        ZIndex = 1,

        Parent = parent,
    })

    self:Create("UICorner", {
        Parent = overlay,
    }, { CornerRadius = "ElementCornerRadius" })

    return overlay
end

-- hover: brighten stroke + title (+ overlay). shared by button/toggle
function Window:_wireElementHover(element)
    local info = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local theme = self.theme

    self:Connect(element.main.MouseEnter, function()
        variables.tweenService
            :Create(
                element.stroke,
                info,
                { Transparency = theme.ElementStrokeHoverTransparency, Color = theme.ElementStrokeHover }
            )
            :Play()
        variables.tweenService:Create(element.title, info, { TextColor3 = theme.ElementTextHoverColor }):Play()
        if element.hoverOverlay then
            variables.tweenService:Create(element.hoverOverlay, info, { BackgroundTransparency = 0.97 }):Play()
        end
    end)

    self:Connect(element.main.MouseLeave, function()
        variables.tweenService
            :Create(
                element.stroke,
                info,
                { Transparency = theme.ElementStrokeTransparency, Color = theme.ElementStroke }
            )
            :Play()
        variables.tweenService:Create(element.title, info, { TextColor3 = theme.ContentColor }):Play()
        if element.hoverOverlay then
            variables.tweenService:Create(element.hoverOverlay, info, { BackgroundTransparency = 1 }):Play()
        end
    end)
end

-- run a callback with the red error-flash on failure, debounced via element._errored so a
-- slider firing every frame flashes once. shared by button/toggle/slider
function Window:_runGuarded(element, fn, ...)
    local args = table.pack(...)
    task.spawn(function()
        local ok, err = pcall(function()
            return fn(table.unpack(args, 1, args.n))
        end)
        if ok or element._errored then
            return
        end
        element._errored = true

        local quickOut = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        variables.tweenService:Create(element.main, quickOut, { BackgroundColor3 = self.theme.ErrorColor }):Play()
        variables.tweenService:Create(element.stroke, quickOut, { Color = self.theme.ErrorStrokeColor }):Play()
        element.title.Text = "Error, log recorded in console."

        warn(
            `Rayfield encountered an error, with the callback for a {element.__type} component named '{element.name}':`
        )
        print(err)

        task.wait(1)

        element.title.Text = element.name
        variables.tweenService
            :Create(
                element.main,
                TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
                { BackgroundColor3 = Color3.fromRGB(255, 255, 255) }
            )
            :Play()
        variables.tweenService
            :Create(
                element.stroke,
                TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { Color = self.theme.ElementStroke }
            )
            :Play()
        element._errored = false
    end)
end

-- Standard element body: white base + gradient fill + rounded corner + flat stroke (hidden until shown).
-- Returns the stroke; call after creating `main` with a white BackgroundColor3.
function Window:StyleElementBody(main)
    self:Create("UIGradient", {
        Rotation = 270,

        Parent = main,
    }, { Color = "ElementGradient" })

    self:Create("UICorner", {
        Parent = main,
    }, { CornerRadius = "ElementCornerRadius" })

    return self:Create("UIStroke", {
        Transparency = 1,

        Parent = main,
    }, { Color = "ElementStroke", Transparency = "ElementStrokeTransparency" })
end

-- Like StyleElementBody but with a gradient stroke (subtle sheen) instead of a flat one.
-- White stroke base tinted by the ElementStrokeGradient. Used by the dropdown's header +
-- options cards. Returns the stroke.
function Window:StyleElementPanel(frame)
    self:Create("UIGradient", {
        Rotation = 270,

        Parent = frame,
    }, { Color = "ElementGradient" })

    self:Create("UICorner", {
        Parent = frame,
    }, { CornerRadius = "ElementCornerRadius" })

    local stroke = self:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 1, -- In = ElementStrokeTransparency

        Parent = frame,
    })

    self:Create("UIGradient", {
        Rotation = 270,

        Parent = stroke,
    }, { Color = "ElementStrokeGradient" })

    return stroke
end

-- Reveal a single instance: instantly set props when animate is false, else tween them with info.
function Window:_reveal(instance, props, animate, info)
    if not instance then
        return
    end
    if animate then
        variables.tweenService:Create(instance, info or REVEAL_INFO, props):Play()
    else
        for property, value in props do
            instance[property] = value
        end
    end
end

-- Reveal the parts every non-Section element shares (fill/stroke/title/icon/descriptor).
function Window:_revealCommon(element, animate)
    self:_reveal(element.stroke, { Transparency = self.theme.ElementStrokeTransparency }, animate)
    self:_reveal(element.title, { TextTransparency = 0 }, animate)
    self:_reveal(element.main, { BackgroundTransparency = self.theme.ElementTransparency or 0 }, animate)
    if element.iconLabel then
        self:_reveal(element.iconLabel, { ImageTransparency = 0 }, animate)
    end
    if element.descriptor then
        self:_reveal(element.descriptor.titleLabel, { TextTransparency = 0.7 }, animate)
    end
end

function Window:Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self.connections, connection)
    return connection
end

-- Disconnect a connection from Window:Connect and drop it from the tracked list.
-- Transient UI (dropdown popups, removed tabs) calls this so open/close churn doesnt
-- pile up dead entries that only get cleared at Unload.
function Window:Disconnect(connection)
    if not connection then
        return
    end
    local index = table.find(self.connections, connection)
    if index then
        table.remove(self.connections, index)
    end
    connection:Disconnect()
end

-- Destroy a subtree and forget every tracked instance inside it. Transient elements
-- (notifications) use this instead of a bare Destroy so self.instances doesnt grow
-- for the whole session.
function Window:DestroySubtree(root)
    if not root then
        return
    end

    local inSubtree = { [root] = true }
    for _, descendant in root:GetDescendants() do
        inSubtree[descendant] = true
    end
    for i = #self.instances, 1, -1 do
        local instance = self.instances[i]
        if inSubtree[instance] then
            table.remove(self.instances, i)
            self.themeProperties[instance] = nil
        end
    end

    root:Destroy()
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
