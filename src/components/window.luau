--!nonstrict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Utility
local utility = script.Parent.Parent.utility
local image = require(utility.image)
local functions = require(utility.functions)
local persistence = require(utility.persistence)
local constants = require(utility.constants)
local locale = require(utility.locale)
local log = require(utility.log)
local hapticEngine = require(utility.HapticEngine)
local chrome = require(script.Parent.chrome)
local search = require(script.Parent.search)

-- Variables
local variables = require(utility.variables)

-- Themes
local themes = script.Parent.Parent.themes

-- Module
local Window = {}
Window.__index = Window

-- Default entrance-reveal tween (elements override with their own where needed)
local revealInfo = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

-- The collapsed "pill" main morphs into on Hide, top-anchored the way the old standalone
-- restore button used to sit.
local collapsedSize = UDim2.fromOffset(185, 50)
local collapsedTop = UDim2.new(0.5, 0, 0, 20)

-- Width of the top-centre toast stack container. Toasts hug their own content and centre
-- within it, so this just needs to be at least the toast's own max width.
local maxToastWidth = 320

-- Standard element row height, shared by the compact button/toggle scaffold.
local compactRowHeight = 41

-- Default window size, and the smallest we'll shrink it to on a tiny screen.
local defaultWindowSize = Vector2.new(475, 500)
local minWindowSize = Vector2.new(300, 320)
local viewportMargin = 60 -- keep the window comfortably inset from the edges of a small screen

-- The default size, shrunk to fit small screens (a phone, or a small PC window) so the window
-- never overflows the viewport. Big screens keep the full size untouched; small ones clamp to
-- the usable area minus a margin, floored so it stays usable. Computed once at open - everything
-- downstream (the reveal target, drag clamp, collapse) reads self.size, so it all inherits this.
local function fitWindowSize()
    local camera = variables.workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize
    if not viewport or viewport.X <= 0 or viewport.Y <= 0 then
        return UDim2.fromOffset(defaultWindowSize.X, defaultWindowSize.Y) -- no camera yet: full size
    end
    local width = math.max(minWindowSize.X, math.min(defaultWindowSize.X, viewport.X - viewportMargin))
    local height = math.max(minWindowSize.Y, math.min(defaultWindowSize.Y, viewport.Y - viewportMargin))
    return UDim2.fromOffset(width, height)
end

-- Keys that drive a UIGradient and so want a ColorSequence. A dev may pass a plain Color3 for
-- any of these and we widen it to a flat sequence, so a theme reads the same either way.
local gradientKeys = {
    WindowColor = true,
    ElementGradient = true,
    ElementStrokeGradient = true,
    TabBackground = true,
    TabStroke = true,
    SliderProgress = true,
}

local function coerceThemeValue(key, value)
    if gradientKeys[key] and typeof(value) == "Color3" then
        return ColorSequence.new(value)
    end
    return value
end

local function firstColor(value)
    return if typeof(value) == "ColorSequence" then value.Keypoints[1].Value else value
end

-- A subtle raised edge for a fill: lighten a dark fill, darken a light one.
local function edgeShade(color, amount)
    local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
    local target = if luminance > 0.5 then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
    return color:Lerp(target, amount)
end

-- Give a custom theme sensible strokes for free: when it recolours a surface but leaves the
-- matching stroke unset, derive one from the fill so a colours-only theme still reads coherently.
local function deriveStrokes(resolved, overrides)
    if overrides.ElementGradient then
        local fill = firstColor(resolved.ElementGradient)
        if overrides.ElementStroke == nil then
            resolved.ElementStroke = edgeShade(fill, 0.28)
        end
        if overrides.ElementStrokeGradient == nil then
            resolved.ElementStrokeGradient = ColorSequence.new(edgeShade(fill, 0.4))
        end
        if overrides.ElementStrokeHover == nil then
            resolved.ElementStrokeHover = edgeShade(fill, 0.52)
        end
    end
    if overrides.TabBackground and overrides.TabStroke == nil then
        resolved.TabStroke = ColorSequence.new(edgeShade(firstColor(resolved.TabBackground), 0.4))
    end
end

-- Resolve a theme arg to its raw key set: a table is taken as-is (partial is fine), a known
-- name is required, anything else falls back to default. Read-only - callers never mutate it,
-- so the require()-cached module stays clean for other windows.
local function themeOverrides(value)
    if typeof(value) == "table" then
        return value
    elseif typeof(value) == "string" then
        local named = themes:FindFirstChild(string.lower(value))
        if named then
            return require(named)
        end
        -- a typo'd name shouldn't crash the menu; warn and fall back so the UI still builds
        log.warn("Rayfield: unknown theme '" .. value .. "', using default")
    elseif value ~= nil then
        log.warn("Rayfield: invalid theme (expected a built-in name or a theme table), using default")
    end
    return require(themes["default"])
end

-- A complete theme for first paint: default filled in with the given overrides, so a partial
-- custom theme only needs the keys it wants to change and the rest fall back to default.
local function resolveTheme(value)
    local resolved = table.clone(require(themes["default"]))
    local overrides = themeOverrides(value)
    for key, override in overrides do
        resolved[key] = coerceThemeValue(key, override)
    end
    -- only a hand-written table gets derived strokes; a named built-in ships its own.
    if typeof(value) == "table" then
        deriveStrokes(resolved, overrides)
    end
    return resolved
end

function Window.new(properties)
    properties = if typeof(properties) == "table" then properties else {}

    -- Localization is global to the running UI: a dev translator (if any) and the active locale
    -- live on the locale module. Default the locale to the player's language unless the dev pins
    -- one. Set before any label is built so the first render is already in the right language.
    if properties.translations or properties.Translations then
        locale.register(properties.translations or properties.Translations)
    end
    if properties.translator or properties.Translator then
        locale.translator = properties.translator or properties.Translator
    end
    locale.setActive(properties.locale or properties.Locale or locale.detect())

    -- a dev can pick the stand-in font shown while the brand font downloads in secure mode; set it
    -- before resolveTheme below so the theme's brandFont picks it up
    local fallbackFont = properties.fallbackFont or properties.FallbackFont
    if fallbackFont then
        variables.setFallbackFont(fallbackFont)
    end

    local self = setmetatable({
        name = properties.name or properties.Name or "Rayfield Window",
        subheading = properties.subtitle or properties.Subtitle,
        size = fitWindowSize(),
        instances = {},
        connections = {},

        icon = properties.icon or properties.Icon,
        showName = properties.showName or properties.ShowName or "Rayfield",
        showIcon = properties.showIcon or properties.ShowIcon or constants.icons.rayfield,

        themeProperties = {},
        localeProperties = {},
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

    -- Public, always-live view of every saved control, keyed by flag. Reading returns the
    -- control's current value; assigning routes through its Set so the UI and callback fire.
    self.Flags = setmetatable({}, {
        __index = function(_, flag)
            local control = self.controls[flag]
            return control and control.value
        end,
        __newindex = function(_, flag, value)
            local control = self.controls[flag]
            if not control then
                log.warn("Rayfield: no flag '" .. tostring(flag) .. "' to set")
                return
            end
            control:Set(value)
        end,
        __iter = function()
            local flag
            return function()
                local control
                flag, control = next(self.controls, flag)
                if flag then
                    return flag, control.value
                end
                return nil
            end
        end,
    })

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

    self.windowCorner = self:Create("UICorner", {

        Parent = self.main,
    }, { CornerRadius = "CornerRoundness" })

    self.windowStroke = self:Create("UIStroke", {
        -- Animations
        Transparency = 1, -- In = 0.95

        Parent = self.main,
    }, { Color = "SurfaceStroke" })

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
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.4414, 0),
            NumberSequenceKeypoint.new(0.7007, 0.631),
            NumberSequenceKeypoint.new(1, 1),
        }),

        Parent = self.bottomFade,
    }, {
        -- Track the window's colour at its base (keypoint 0 sits at the bottom under Rotation 270)
        -- so elements dissolve into the window instead of a fixed dark smudge on light themes.
        Color = {
            "WindowColor",
            function(color)
                return ColorSequence.new(functions.toColorSequence(color).Keypoints[1].Value)
            end,
        },
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
            Text = locale.t(self.name), -- window name

            FontFace = variables.brandFont(Enum.FontWeight.Medium),

            Size = UDim2.fromOffset(50, 20),
            AutomaticSize = Enum.AutomaticSize.X,

            BackgroundTransparency = 1,
            TextSize = 20,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,

            -- Animations
            TextTransparency = 1, -- In = 0

            Parent = self.titleContainer,
        }, { FontFace = "Font", TextColor3 = "TitlingColor" })
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
            Text = locale.t(self.subheading), -- window name

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

    -- Shadow (Transparency 1 here, tweened to 0.6 on show)
    self.windowShadow = self:CreateGlow(self.main, "ShadowColor", 20, 1)

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

        -- Tabs switch via the topbar only. Kill the built-in input so scrolling a long page
        -- (or a nudge on a controller) never flips to another tab under you.
        ScrollWheelInputEnabled = false,
        GamepadInputEnabled = false,
        TouchInputEnabled = false,

        EasingStyle = Enum.EasingStyle.Exponential,
        TweenTime = 0.4,

        Parent = self.elements,
    })

    -- Tabs Preparation
    self.tabList = self:Create("ScrollingFrame", {
        Name = "Tabs",
        Active = true,
        Size = UDim2.new(1, 0, 0, 38),
        Position = UDim2.new(0.5, 0, 0, 65),
        AnchorPoint = Vector2.new(0.5, 0),

        BackgroundTransparency = 1,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 0,
        ScrollBarImageTransparency = 1,
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
        -- everything here is ephemeral: these controls persist to rayfield.rfld via SaveSettings,
        -- never the user's config. children inherit this, so none of them opt out individually.
        forgetState = true,
    })

    require(script.Parent.action).new(self, {
        name = "Close",
        icon = constants.icons.close,
        order = 1,

        callback = function()
            self:ToggleHide()
        end,
    })

    self.minimiseAction = require(script.Parent.action).new(self, {
        name = "Minimise",
        icon = constants.icons.minimise,
        order = 2,

        callback = function()
            self:ToggleMinimise()
        end,
    })

    self.settingsAction = require(script.Parent.action).new(self, {
        name = "Settings",
        icon = constants.icons.settings,
        order = 3,
        linkedTab = self.rfSettings,

        callback = function()
            self.rfSettings:Select()
        end,
    })

    search.build(self)

    self.unloaded = false
    self.minimised = false
    self.hidden = true
    self.animating = false
    self.hasShownOnce = false

    self.settings = {
        toggleKeybind = Enum.KeyCode.K,
        mouseOverride = true, -- free the cursor while the menu is open (for FPS games that lock it)
        keepOnScreen = true, -- clamp the drag so the window cant be pulled off screen
        welcomeToast = true, -- the "signed in as" toast on first open for a new/changed account
        haptics = false, -- off by default; opt in from settings (buzzes on presses/notifications)
    }

    self:LoadSettings()
    hapticEngine.setEnabled(self.settings.haptics) -- honour a saved off before any interaction
    chrome.buildCollapsedFace(self)
    self:_bindKeybind()
    self:_bindMouseOverride()
    self:_buildSettingsUI()

    if self.theme.LiveAnimation then
        task.spawn(function()
            local out = true
            local tweenInfo = TweenInfo.new(10, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

            while not self.unloaded do
                local tweenW = variables.tweenService:Create(self.windowGradient, tweenInfo, {
                    Offset = Vector2.new(if out then 0.4 else -0.2, 0),
                    Rotation = (if out then 220 else 280),
                })

                self._liveTween = tweenW
                tweenW:Play()
                tweenW.Completed:Wait()
                out = not out
            end
            self._liveTween = nil
        end)
    end

    return self
end

function Window:ChangeTheme(theme)
    -- A named theme fully switches: resolve against default so keys it omits reset rather than
    -- lingering from the previous theme. A partial table just overrides the keys it names.
    local overrides = if typeof(theme) == "table" then theme else resolveTheme(theme)
    for name, value in overrides do
        self.theme[name] = coerceThemeValue(name, value)
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

    -- themeProperties above only carry plain colours; reveal-driven transparencies and state
    -- colours (the toggle knob, field fills, glows) aren't, so refresh the elements to reach
    -- them on a live swap. Every tab's elements stay shown (just page-clipped), settings
    -- included, so refresh them all; groups forward the call to their children.
    if not self.hidden then
        for _, tab in self.tabs do
            for _, element in tab.elements do
                if element._refreshTheme then
                    element:_refreshTheme()
                end
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
-- elements don't clobber each other's saved value. Updates control.flag to the key we
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
        log.warn(
            "Rayfield: duplicate config flag '"
                .. control.flag
                .. "', saving this one as '"
                .. flag
                .. "'. Set a unique flag to keep it stable across sessions."
        )
    end

    control.flag = flag
    self.controls[flag] = control
    return flag
end

-- Autosave a control's value after an interactive or programmatic change, when the window is
-- set to autoSave and the control opts into persistence. Every Set/commit path funnels here so
-- persistence stays uniform across elements.
function Window:_persist(control)
    -- _loading: a config restore fires every control's callback, but must not autosave back over
    -- the file it's reading (or storm Save once per control)
    if control.flag and not control.forgetState and self.configuration.autoSave and not self._loading then
        task.spawn(self.Save, self)
    end
end

-- Drop a control from the flag registry when its element is removed, so Save/Load and the
-- Flags view never touch a destroyed instance.
function Window:_unregisterControl(control)
    if control.flag and self.controls[control.flag] == control then
        self.controls[control.flag] = nil
    end
end

-- find a keybind element currently bound to `key`, skipping `exclude` and unbound keys. lets
-- the menu-toggle keybind refuse a key an element keybind already owns. keybinds only live at
-- tab level (groups don't hold them), so a scan over each tab's elements catches them all.
function Window:_keybindUsing(key, exclude)
    if typeof(key) ~= "EnumItem" or key == Enum.KeyCode.Unknown then
        return nil
    end
    for _, tab in self.tabs do
        for _, element in tab.elements do
            if element ~= exclude and element.__type == "Keybind" and element.value == key then
                return element
            end
        end
    end
    return nil
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

-- Top-centre toast stack. Like Notify but for brief, centred messages that drop in from the
-- top of the screen (newest on top). Each toast takes { title, subtitle?, icon?, duration? }.
function Window:Toast(properties)
    if not self.toasts then
        self.toasts = self:Create("Frame", {
            Name = "Toasts",
            Size = UDim2.new(0, maxToastWidth, 1, -24),
            Position = UDim2.new(0.5, 0, 0, 12),
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundTransparency = 1,
            ZIndex = constants.zIndex.toast,

            Parent = self.screenGui,
        })

        self:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            -- gap lives inside each toast so removing one collapses its gap with it
            Padding = UDim.new(0, 0),

            Parent = self.toasts,
        })
    end

    return require(script.Parent.toast).new(self, properties)
end

-- Centred modal over a dimmed backdrop. Takes { title, subtitle?, icon?, content?, boxes?,
-- options?, dismissible? } - give it options for a choice dialog, or boxes for a changelog.
-- Returns the popup handle (call :Close() to dismiss it yourself).
function Window:Popup(properties)
    return require(script.Parent.popup).new(self, properties)
end

function Window:Hide()
    if self.animating then
        return
    end

    -- drop out of search first so we grow back into the normal tab view on next show. tabList
    -- stays hidden here since the collapse hides it anyway; Show re-enables it.
    if self._searching then
        search.close(self, { showTabs = false, jumpTo = self.selectedTab and self.selectedTab.tabPage })
    end

    self.animating = true
    self.hidden = true
    variables.rayfieldHidden = true
    self.collapsedInteract.Visible = false -- re-shown once the collapse settles, below

    -- closing while minimised closes properly rather than leaving a stale minimised state -
    -- Show always grows back to the full (non-minimised) layout, so the flag and icon need
    -- to agree with that
    if self.minimised then
        self.minimised = false
        image.assign(self.minimiseAction.iconLabel, "Image", constants.icons.minimise) -- back to the minimise icon
    end

    -- remember where the window sat so Show grows it back to the same spot
    self._restorePosition = self.main.Position

    local home, size = self:_collapsedRect()

    local fadeInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    -- one continuous move for the whole collapse: size and position tween together on the
    -- same curve so they stay perfectly in sync, no seam between separate legs
    local moveInfo = TweenInfo.new(0.35, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut)
    local cornerInfo = TweenInfo.new(0.35, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut)
    local faceInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    -- shrink the drag bar back down the same way it grows in on first reveal, instead of
    -- just cutting it
    variables.tweenService
        :Create(self.drag.dragCosmetic, fadeInfo, { Size = UDim2.fromOffset(0, 4), BackgroundTransparency = 1 })
        :Play()
    task.delay(0.18, function()
        if not self.hidden then
            return
        end
        self.drag.drag.Visible = false
    end)

    -- fade the window's own chrome out; main keeps its own background/gradient/corner the
    -- whole time, it just reshapes underneath - there's nothing to hand off to
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

    self:_fadeSelectedElementsOut()

    -- collapse into the pill in one continuous move - size and position tweened together
    -- so they stay perfectly in sync throughout
    variables.tweenService:Create(self.main, moveInfo, { Size = size, Position = home }):Play()
    variables.tweenService:Create(self.windowCorner, cornerInfo, { CornerRadius = UDim.new(1, 0) }):Play()

    -- once the chrome's faded, drop it and the scrolling content so nothing squashes/pokes
    -- out as the frame shrinks around it, then bring the collapsed face up over the top
    task.delay(0.18, function()
        if not self.hidden then
            return
        end
        self.topbar.Visible = false
        self.elements.Visible = false
        self.tabList.Visible = false

        chrome.setCollapsedShown(self, true, faceInfo)
    end)

    -- once the move's settled the pill is done morphing: hand clicks to it
    task.delay(0.35, function()
        if not self.hidden then
            return
        end
        self.collapsedInteract.Visible = true
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

    -- minimising drops out of search back to the tab view first, so it grows back normally
    if self._searching then
        search.close(self, { showTabs = true })
    end

    self.animating = true

    local sizeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    local fadeInfo = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

    if self.minimised then
        self.minimised = false
        image.assign(self.minimiseAction.iconLabel, "Image", constants.icons.minimise) -- back to the minimise icon

        variables.tweenService:Create(self.main, sizeInfo, { Size = self.size }):Play()
        variables.tweenService:Create(self.windowShadow, fadeInfo, { Transparency = 0.6 }):Play()
        variables.tweenService:Create(self.bottomFade, fadeInfo, { BackgroundTransparency = 0 }):Play()

        variables.tweenService
            :Create(self.drag.drag, sizeInfo, {
                Position = UDim2.new(
                    self.main.Position.X.Scale,
                    self.main.Position.X.Offset,
                    self.main.Position.Y.Scale,
                    self.main.Position.Y.Offset + self.size.Y.Offset / 2 + 15
                ),
            })
            :Play()

        -- once the window's grown back, fade the content and tab pills in rather than
        -- snapping them visible
        task.delay(0.2, function()
            if self.minimised or self.hidden then
                return -- re-minimised or hidden mid animation
            end
            self.elements.Visible = true
            self.tabList.Visible = true

            for _, tab in pairs(self.tabs) do
                if not tab.neglectSelector and tab.topbarItem then
                    tab.topbarItem.Visible = true
                    tab:_applyVisual(if self.selectedTab == tab then "selected" else "unselected", fadeInfo)
                end
            end

            self:_revealElements(0.035, 0.4)
        end)

        task.delay(0.5, function()
            self.animating = false
        end)
    else
        self.minimised = true
        image.assign(self.minimiseAction.iconLabel, "Image", constants.icons.maximise) -- maximise icon while minimised

        -- fade the content + tab pills out instead of cutting them, then hide them once faded
        -- so they don't sit clipped under the collapsed bar
        self:_fadeSelectedElementsOut()
        for _, tab in pairs(self.tabs) do
            if not tab.neglectSelector and tab.topbarItem then
                tab:_applyVisual("hidden", fadeInfo)
            end
        end

        task.delay(0.3, function()
            if not self.minimised then
                return -- restored mid animation
            end
            self.elements.Visible = false
            self.tabList.Visible = false
            for _, tab in pairs(self.tabs) do
                if not tab.neglectSelector and tab.topbarItem then
                    tab.topbarItem.Visible = false
                end
            end
        end)

        variables.tweenService:Create(self.windowShadow, fadeInfo, { Transparency = 1 }):Play()
        variables.tweenService:Create(self.bottomFade, fadeInfo, { BackgroundTransparency = 1 }):Play()
        variables.tweenService:Create(self.main, sizeInfo, { Size = UDim2.fromOffset(self.size.X.Offset, 66) }):Play()

        variables.tweenService
            :Create(self.drag.drag, sizeInfo, {
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
        if processed or self._recordingKeybind then
            return -- a keybind element is mid-rebind, don't eat its capture
        end
        if input.KeyCode == self.settings.toggleKeybind or input.UserInputType == self.settings.toggleKeybind then
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
        -- hands off while the right button is held: thats the camera panning in third person,
        -- and it needs to lock the mouse to do it. we free again the moment it lets go.
        if uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
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

    -- right-release doesn't always flip MouseBehavior back (so the signals above wouldn't fire),
    -- so re-free explicitly once the pan ends
    self:Connect(uis.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            free()
        end
    end)

    -- Show calls this on open to free the cursor immediately (the signals above only fire on change)
    self._freeMouse = free
end

function Window:_buildSettingsUI()
    self.rfSettings:CreateSection({ name = "General" })

    self.rfSettings:CreateKeybind({
        name = "Toggle Keybind",
        icon = constants.icons.search,
        value = self.settings.toggleKeybind,
        isMenuToggle = true, -- reject keys already owned by an element keybind
        onChanged = function(key)
            self.settings.toggleKeybind = key
            self:SaveSettings()
        end,
    })

    self.rfSettings:CreateToggle({
        name = "Unlock cursor while open",
        description = "Unlocks the cursor while the menu is open so you can configure in FPS games that lock it.",
        value = self.settings.mouseOverride,
        callback = function(state)
            self.settings.mouseOverride = state
            self:SaveSettings()
        end,
    })

    self.rfSettings:CreateToggle({
        name = "Welcome toast",
        description = "Shows a 'Signed in as' toast the first time you open the menu on a new account.",
        value = self.settings.welcomeToast,
        callback = function(state)
            self.settings.welcomeToast = state
            self:SaveSettings()
        end,
    })

    self.rfSettings:CreateToggle({
        name = "Haptics",
        description = "A subtle tap as you interact, on devices that support haptics.",
        value = self.settings.haptics,
        callback = function(state)
            self.settings.haptics = state
            hapticEngine.setEnabled(state)
            self:SaveSettings()
        end,
    })

    self.rfSettings:CreateSection({ name = "Window" })

    self.rfSettings:CreateToggle({
        name = "Keep window on screen",
        description = "Stops the window being dragged off the edge of the screen and lost.",
        value = self.settings.keepOnScreen,
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

    -- Configurations: save the current setup under a name and switch between saved ones.
    -- Only shown once the developer opts into config saving.
    if next(self.configuration) ~= nil then
        self.rfSettings:CreateSection({ name = "Configurations" })

        local selected = self:ListConfigs()[1]
        local configDropdown, nameInput

        local function refreshConfigs()
            local names = self:ListConfigs()
            configDropdown:Refresh(names)
            if selected and not table.find(names, selected) then
                selected = names[1]
            end
            if selected then
                configDropdown:Set(selected, true)
            end
        end

        configDropdown = self.rfSettings:CreateDropdown({
            name = "Saved Configurations",
            icon = constants.icons.config,
            options = self:ListConfigs(),
            value = selected,
            placeholder = "No saved configurations",
            callback = function(value)
                selected = value
            end,
        })

        nameInput = self.rfSettings:CreateInput({
            name = "Configuration Name",
            description = "Name a new configuration, or leave blank to overwrite the selected one.",
            placeholder = "e.g. PvP Loadout",
            clearOnFocus = false,
        })

        local actions = self.rfSettings:CreateGroup()

        actions:CreateButton({
            name = "Save",
            icon = constants.icons.config,
            callback = function()
                local name = nameInput.value
                if name == "" then
                    name = selected
                end
                if not name or name == "" then
                    self:Toast({ title = locale.resolve("Name your configuration first") })
                    return
                end
                if self:Save(name) then
                    nameInput:Set("")
                    selected = name
                    refreshConfigs()
                    self:Toast({
                        title = locale.resolve("Saved configuration"),
                        subtitle = name,
                        icon = constants.icons.config,
                    })
                else
                    self:Toast({ title = locale.resolve("Couldn't save configuration"), subtitle = name })
                end
            end,
        })

        actions:CreateButton({
            name = "Load",
            callback = function()
                if not selected or selected == "" then
                    self:Toast({ title = locale.resolve("Pick a configuration to load") })
                    return
                end
                if self:Load(selected) then
                    self:Toast({ title = locale.resolve("Loaded configuration"), subtitle = selected })
                else
                    self:Toast({ title = locale.resolve("Couldn't load configuration"), subtitle = selected })
                end
            end,
        })

        actions:CreateButton({
            name = "Delete",
            callback = function()
                local deleting = selected
                if not deleting or deleting == "" then
                    self:Toast({ title = locale.resolve("Pick a configuration to delete") })
                    return
                end
                if self:DeleteConfig(deleting) then
                    refreshConfigs()
                    self:Toast({ title = locale.resolve("Deleted configuration"), subtitle = deleting })
                else
                    self:Toast({ title = locale.resolve("Couldn't delete configuration"), subtitle = deleting })
                end
            end,
        })
    end
end

function Window:SaveSettings()
    return persistence.saveSettings(self)
end

function Window:LoadSettings()
    return persistence.loadSettings(self)
end

-- Fade the open tab's elements out - the only ones actually on screen, since the page
-- navigation keeps the other tabs' elements invisible. Shared by Hide and minimise.
function Window:_fadeSelectedElementsOut()
    if self.selectedTab then
        for _, element in ipairs(self.selectedTab.elements) do
            element:_setShown(false, true)
        end
    end
end

-- Reveal the open tab's elements with a quick top-to-bottom stagger, but only for the ones
-- actually within the scroll viewport - whatever's scrolled off (above or below) just snaps in,
-- since nobody's looking at it. So reopening a page scrolled halfway down animates from where
-- you left off, not from the very top. Everything is measured live off the scrolling frame's
-- real viewport + each element's real position, so it's correct at any window size, any scroll.
-- Other tabs snap ready off-screen too. `budget` caps how long the stagger runs before the
-- remaining on-screen elements come in together, so a tall viewport doesn't crawl.
function Window:_revealElements(perElementDelay, budget)
    for _, tab in pairs(self.tabs) do
        if tab ~= self.selectedTab then
            for _, element in ipairs(tab.elements) do
                element:_setShown(true, false)
            end
        end
    end

    local tab = self.selectedTab
    if not tab then
        return
    end

    local page = tab.tabPage
    local viewTop = page.AbsolutePosition.Y
    local viewBottom = viewTop + page.AbsoluteWindowSize.Y

    local maxStaggered = math.floor(budget / perElementDelay)
    local staggered = 0
    for _, element in ipairs(tab.elements) do
        local top = element.main.AbsolutePosition.Y
        local onScreen = (top + element.main.AbsoluteSize.Y) > viewTop and top < viewBottom
        if onScreen then
            element:_setShown(true, true)
            staggered += 1
            if staggered <= maxStaggered then
                task.wait(perElementDelay)
            end
        else
            element:_setShown(true, false) -- off-screen: no point animating what isn't visible
        end
    end
end

function Window:Show()
    if self.animating then
        return
    end
    self.animating = true

    -- autoLoad reflects the saved config once, on first open. Re-loading on every show would
    -- wipe any changes the user made and closed without saving.
    if self.configuration.autoLoad and not self._autoLoaded then
        self._autoLoaded = true
        self:Load()
    end

    self.hidden = false
    self.minimised = false
    variables.rayfieldHidden = false
    self.collapsedInteract.Visible = false -- first thing on click: stop it eating any more input

    if self._freeMouse then
        self._freeMouse()
    end

    if self.hasShownOnce then
        self:_quickRestore()
    else
        self.hasShownOnce = true
        self:_firstShow()
    end
end

function Window:_quickRestore()
    local target = self._restorePosition or UDim2.new(0.5, 0, 0.5, 0)

    local growInfo = TweenInfo.new(0.35, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut)
    local cornerInfo = TweenInfo.new(0.35, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut)
    local fadeInfo = TweenInfo.new(0.28, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

    -- Phase 1: nothing but the pill morphing back into the window frame. The collapsed face
    -- fades off, main grows + un-rounds. No chrome, no content - so you never see the topbar,
    -- tabs or bottom fade floating over a frame that isn't a window yet.
    chrome.setCollapsedShown(self, false, TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
    variables.tweenService:Create(self.main, growInfo, { Size = self.size, Position = target }):Play()
    variables.tweenService:Create(self.windowCorner, cornerInfo, { CornerRadius = self.theme.CornerRoundness }):Play()

    -- Phase 2: once the frame actually reads as a window, fade its chrome in and stagger the
    -- open tab's elements. Other tabs snap ready off-screen - nobody's looking, so no animation.
    task.delay(0.22, function()
        self.topbar.Visible = true
        self.tabList.Visible = true
        self.elements.Visible = true

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

        -- if we were hidden with the settings page open, bring its cog back lit (its open
        -- state) rather than the default resting brightness the loop above just set
        if self.settingsAction and self.selectedTab == self.rfSettings then
            variables.tweenService:Create(self.settingsAction.iconLabel, fadeInfo, { ImageTransparency = 0.2 }):Play()
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

        self:_revealElements(0.035, 0.4)
    end)

    -- Drag handle grows in with the chrome, same width sweep it uses on first reveal. Position
    -- is recalculated against the full restored size - if the window was minimised (a shorter
    -- bar-hang offset) before hiding, it would otherwise reappear at the old, wrong height.
    task.delay(0.22, function()
        self.drag.drag.Position =
            UDim2.new(target.X.Scale, target.X.Offset, target.Y.Scale, target.Y.Offset + self.size.Y.Offset / 2 + 15)
        self.drag.dragCosmetic.Size = UDim2.fromOffset(0, 4)
        self.drag.dragCosmetic.BackgroundTransparency = 1
        self.drag.drag.Visible = true
        variables.tweenService
            :Create(self.drag.dragCosmetic, growInfo, { Size = UDim2.fromOffset(100, 4), BackgroundTransparency = 0.7 })
            :Play()
    end)

    task.delay(0.6, function()
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
    task.wait(0.85) -- let the frame actually read as a window before anything shows on top of it
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
                tab:_spinGradients()

                task.wait(0.15)
            end
        end
    end)

    self:_revealElements(0.03, 2)

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

    -- Welcome the user once if this is a new/changed account on this device (unless they've
    -- turned it off in settings). Just a toast now - the profile chip is a toast like any other.
    if self.settings.welcomeToast and chrome.isNewUser() then
        self:Toast({
            title = variables.localPlayer.DisplayName,
            subtitle = locale.resolve("Signed in as"),
            subtitleAbove = true, -- reads "Signed in as" / name, label over value
            avatar = variables.localPlayer.UserId,
            minWidth = 220, -- match the old license card's width for that roomy right-hand space
        })
    end
end

function Window:GetPath()
    return persistence.getPath(self)
end

-- name saves to a specific config; omit it to save the default file.
function Window:Save(name)
    if name ~= nil and (type(name) ~= "string" or name == "") then
        return false
    end
    return persistence.save(self, name)
end

-- name loads a specific config; omit it to load the default file.
function Window:Load(name)
    if name ~= nil and (type(name) ~= "string" or name == "") then
        return false
    end
    return persistence.load(self, name)
end

function Window:ListConfigs()
    return persistence.list(self)
end

function Window:DeleteConfig(name)
    return persistence.delete(self, name)
end

-- Read a flag's current value, or nil if nothing is registered under it.
function Window:Get(flag)
    local control = self.controls[flag]
    return control and control.value
end

-- Set a flag's value, routing through the control so the UI updates and the callback fires.
-- Returns false if no control is registered under the flag.
function Window:Set(flag, value)
    local control = self.controls[flag]
    if not control then
        return false
    end
    control:Set(value)
    return true
end

-- Jump to a tab by handle, name, or its page instance. No-ops on an unknown tab rather
-- than handing JumpTo something it cant resolve.
function Window:Navigate(tab)
    local page
    if typeof(tab) == "Instance" then
        page = tab
    elseif typeof(tab) == "table" then
        page = tab.tabPage
    elseif typeof(tab) == "string" then
        for _, candidate in self.tabs do
            if candidate.name == tab then
                page = candidate.tabPage
                break
            end
        end
    end

    if not page then
        return
    end
    self.elementsLayout:JumpTo(page)
end

function Window:Create(className, properties, themeProperties)
    assert(typeof(className) == "string", "Invalid argument #1 (string expected)")
    local instance = Instance.new(className)

    -- Themed properties apply first so animation start-states in `properties` (e.g. a hidden
    -- BackgroundTransparency = 1) still win at build; the theme value is the reveal target.
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
            if locale.isToken(value) then
                self:_bindLocale(instance, property, locale.sourceOf(value))
            else
                image.assign(instance, property, value)
            end
        end
    end

    table.insert(self.instances, instance)
    return instance
end

-- Bind instance[property] to a source string: set it to the active locale's form now and remember
-- it so SetLocale can re-resolve in place without rebuilding anything. Mirrors how themeProperties
-- lets ChangeTheme re-apply themed values later.
function Window:_bindLocale(instance, property, source)
    instance[property] = locale.resolve(source)

    local entries = self.localeProperties[instance]
    if not entries then
        entries = {}
        self.localeProperties[instance] = entries
    end
    entries[property] = source
end

-- Swap every localized label to `localeId` in place. Element values, slider readouts and other
-- data aren't copy, so they're untouched. AutomaticSize reflows widths for us; the few manually
-- measured labels (toasts) are transient enough not to need a re-measure.
function Window:SetLocale(localeId)
    locale.setActive(localeId)
    for instance, entries in self.localeProperties do
        for property, source in entries do
            instance[property] = locale.resolve(source)
        end
    end
end

-- Swap the dev translation hook (source, localeId) -> string?. Follow with SetLocale (or pass the
-- same locale back) to re-resolve everything already on screen through the new hook.
function Window:SetTranslator(translator)
    locale.translator = translator
end

-- Merge more translation tables in at runtime ({ [localeId] = { [source] = translated } }) and
-- re-apply the active locale, so a language pack added after the UI is built lands immediately.
function Window:RegisterTranslations(tables)
    locale.register(tables)
    self:SetLocale(locale.current)
end

-- Soft glow behind a GuiObject via a native UIShadow (no image). ZIndex -1 keeps it behind.
-- `color` is a Color3 for a fixed glow, or a theme key (string) for a shadow that tracks the
-- theme and re-tints on ChangeTheme - a ColorSequence key resolves to its first keypoint.
function Window:CreateGlow(parent, color, blur, transparency)
    local properties = {
        BlurRadius = UDim.new(0, blur),
        Transparency = transparency,
        ZIndex = -1,

        Parent = parent,
    }

    if typeof(color) == "string" then
        return self:Create("UIShadow", properties, {
            Color = {
                color,
                function(value)
                    return if typeof(value) == "ColorSequence" then value.Keypoints[1].Value else value
                end,
            },
        })
    end

    properties.Color = color
    return self:Create("UIShadow", properties)
end

-- Flash an element's inset box + glow to signal a set landed: green for a good set, red for a
-- rejected one, then settle back to the box's idle look. green/red are our universal accents.
-- The element supplies `box`, an optional `glow`, and its idle transparencies (_boxIdle/_glowIdle).
function Window:_flashResult(element, ok)
    local box = element.box
    if not box then
        return
    end
    local glow = element.glow
    local stroke = element.boxStroke
    local white = Color3.fromRGB(255, 255, 255)
    local fill = ok and constants.accent.on or self.theme.ErrorColor
    local edge = ok and constants.accent.onStroke or self.theme.ErrorStrokeColor
    local inInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local outInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    -- a quick coloured pulse: box fill tints (transparency untouched), edge + glow brighten
    variables.tweenService:Create(box, inInfo, { BackgroundColor3 = fill }):Play()
    if stroke then
        variables.tweenService:Create(stroke, inInfo, { Color = edge, Transparency = 0.4 }):Play()
    end
    if glow then
        variables.tweenService:Create(glow, inInfo, { Color = edge, Transparency = 0.6 }):Play()
    end

    -- token so a quick re-set restarts the flash instead of an old revert cutting it short
    element._flashToken = (element._flashToken or 0) + 1
    local token = element._flashToken
    task.delay(0.22, function()
        if element._flashToken ~= token then
            return
        end
        variables.tweenService:Create(box, outInfo, { BackgroundColor3 = self.theme.FieldBackground }):Play()
        if stroke then
            variables.tweenService:Create(stroke, outInfo, { Color = white, Transparency = 0.85 }):Play()
        end
        if glow then
            variables.tweenService
                :Create(glow, outInfo, { Color = self.theme.FieldGlow, Transparency = element._glowIdle or 1 })
                :Play()
        end
    end)
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
        if not self:_interactive() then
            return -- window still revealing/hiding: don't light up mid-animation
        end
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
-- slider firing every frame flashes once. shared by every interactive element. elements whose
-- `main` is a transparent wrapper (the dropdown) set `flashTarget` to the frame to tint.
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

        local flashFrame = element.flashTarget or element.main
        local quickOut = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        variables.tweenService:Create(flashFrame, quickOut, { BackgroundColor3 = self.theme.ErrorColor }):Play()
        variables.tweenService:Create(element.stroke, quickOut, { Color = self.theme.ErrorStrokeColor }):Play()
        element.title.Text = locale.resolve("Error, log recorded in console.")

        log.warn(
            `Rayfield encountered an error, with the callback for a {element.__type} component named '{element.name}':`
        )
        log.print(err)

        task.wait(1)

        element.title.Text = locale.resolve(element.name)
        variables.tweenService
            :Create(
                flashFrame,
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

-- Shared scaffold for the compact button/toggle row: the white body + stroke, the fill flex
-- so it shares the row width, and the click surface. Callers add their own padding + content
-- into the returned interact, keeping the two elements identical where they should be.
function Window:_buildCompactRow(host, name, interactZIndex)
    local main = self:Create("Frame", {
        Name = name,
        Size = UDim2.fromOffset(0, compactRowHeight),
        AutomaticSize = Enum.AutomaticSize.X,
        ClipsDescendants = true, -- overflow guard
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,

        BackgroundTransparency = 1, -- In = ElementTransparency

        Parent = host.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    local stroke = self:StyleElementBody(main)

    -- share the row width (grow + shrink)
    self:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Fill,
        Parent = main,
    })

    -- main flows + fills the interact
    self:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,

        Parent = main,
    })

    -- clickable wrapper, doubles as the hover-brighten surface
    local interact = self:Create("TextButton", {
        Text = "",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1, -- hover fades to 0.97
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, compactRowHeight),
        BorderSizePixel = 0,
        TextTransparency = 1,
        ZIndex = interactZIndex or 1,

        Parent = main,
    })

    self:Create("UICorner", {
        Parent = interact,
    }, { CornerRadius = "ElementCornerRadius" })

    return main, stroke, interact
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
        variables.tweenService:Create(instance, info or revealInfo, props):Play()
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

-- The reverse of _revealCommon: fade the same shared parts back out to fully transparent.
function Window:_hideCommon(element, animate)
    self:_reveal(element.stroke, { Transparency = 1 }, animate)
    self:_reveal(element.title, { TextTransparency = 1 }, animate)
    self:_reveal(element.main, { BackgroundTransparency = 1 }, animate)
    if element.iconLabel then
        self:_reveal(element.iconLabel, { ImageTransparency = 1 }, animate)
    end
    if element.descriptor then
        self:_reveal(element.descriptor.titleLabel, { TextTransparency = 1 }, animate)
    end
end

-- The rect main morphs into once collapsed: the same top-centre spot the old standalone
-- restore pill used to sit at, translated into main's own centre-anchored space (main never
-- changes AnchorPoint, so its Position always addresses its centre, not its top edge).
function Window:_collapsedRect()
    local size = collapsedSize
    local home = UDim2.new(
        collapsedTop.X.Scale,
        collapsedTop.X.Offset,
        collapsedTop.Y.Scale,
        collapsedTop.Y.Offset + size.Y.Offset / 2
    )
    return home, size
end

-- true only when the window is fully shown and idle. hover/press animations gate on this so
-- nothing lights up mid show/hide/minimise reveal, while elements are still tweening in.
function Window:_interactive()
    return not self.animating and not self.hidden
end

function Window:Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self.connections, connection)
    return connection
end

-- Like Connect, but also files the connection on the element that owns it, so Tab:Remove can
-- tear an element's connections down instead of leaving them tracked until Unload. Every
-- persistent element connection funnels through here.
function Window:ConnectFor(owner, signal, callback)
    local connection = self:Connect(signal, callback)
    owner.connections = owner.connections or {}
    table.insert(owner.connections, connection)
    return connection
end

-- Disconnect a connection from Window:Connect and drop it from the tracked list.
-- Transient UI (dropdown popups, removed tabs) calls this so open/close churn doesn't
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
-- (notifications) use this instead of a bare Destroy so self.instances doesn't grow
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
            self.localeProperties[instance] = nil
        end
    end

    root:Destroy()
end

function Window:Unload()
    self.unloaded = true
    if self._liveTween then
        self._liveTween:Cancel() -- unparks the LiveAnimation loop before we destroy the gradient
        self._liveTween = nil
    end
    for i = #self.connections, 1, -1 do
        self.connections[i]:Disconnect()
    end
    for i = #self.instances, 1, -1 do
        self.instances[i]:Destroy()
    end
end

return Window
