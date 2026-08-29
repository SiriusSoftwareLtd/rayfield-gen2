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
local windowSizing = require(utility.windowSizing)
local layouts = require(utility.layouts)
local chrome = require(script.Parent.chrome)
local search = require(script.Parent.search)
local sidebar = require(script.Parent.sidebar)

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
-- restore button used to sit. showIconOnly trades the label for a round badge.
local collapsedSize = UDim2.fromOffset(185, 50)
local collapsedIconSize = UDim2.fromOffset(50, 50)
local collapsedTop = UDim2.new(0.5, 0, 0, 20)
local topToastOpenPosition = UDim2.new(0.5, 0, 0, 12)
local topToastClosedPosition = UDim2.new(0.5, 0, 0, collapsedTop.Y.Offset + collapsedSize.Y.Offset + 12)
local topToastMoveInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- Width of the top-centre toast stack container. Toasts hug their own content and centre
-- within it, so this just needs to be at least the toast's own max width.
local maxToastWidth = 320

-- Standard element row height, shared by the compact button/toggle scaffold.
local compactRowHeight = 41

-- A locked element just dims: light enough that you can still read what it was, heavy enough
-- that it reads as out of reach. Nothing is laid over the top - a panel covering the row hides
-- the very thing you are being told is locked. The reason goes in the description underneath,
-- where there is nothing to compete with it.
local lockScrimTransparency = 0.55
local lockedDescriptionTransparency = 0.55

-- How the tab selector arrives on first reveal: a quick ripple, capped so a long tab list
-- doesn't turn the entrance into a queue.
local tabStagger = 0.04
local maxStaggeredTabs = 8

-- How often the backstop re-checks the fit, for anything the viewport signal misses.
local viewportReconcileInterval = 2

-- The size the current screen calls for, for this window's layout. Everything downstream (the
-- reveal target, drag clamp, collapse) reads self.size, so it all inherits whatever this returns.
local function fitWindowSize(mode): UDim2
    local camera = variables.workspace.CurrentCamera
    return windowSizing.fit(camera and camera.ViewportSize, mode)
end

-- Per-corner radii are newer than the oldest clients Rayfield runs on, so a shape that only
-- rounds some of its corners has to check before it asks. Everything still gets a radius on a
-- client without them, just the same one on all four.
local cornerNames = { "TopLeftRadius", "TopRightRadius", "BottomLeftRadius", "BottomRightRadius" }

local perCornerSupported = (function()
    return (
        pcall(function()
            local probe = Instance.new("UICorner")
            probe.TopLeftRadius = UDim.new(0, 1)
            probe:Destroy()
        end)
    )
end)()

-- Resolve the sidebarLayout property: tabs down the left instead of across the top.
local function resolveLayout(value)
    return if value then layouts.sidebar else layouts.top
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

local function setTopToastPosition(window, animate)
    local container = window._toastsTop
    if not container then
        return
    end

    local target = if window._collapsedShown then topToastClosedPosition else topToastOpenPosition
    if not animate or container.Position == target then
        container.Position = target
        return
    end

    local tween = variables.tweenService:Create(container, topToastMoveInfo, { Position = target })
    window._topToastTween = tween
    tween.Completed:Connect(function()
        if window._topToastTween == tween then
            window._topToastTween = nil
        end
    end)
    tween:Play()
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
        -- a typo'd name shouldnt crash the menu; warn and fall back so the UI still builds
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

    -- theme modules call brandFont at first require and are cached from then on, so a
    -- fallbackFont set afterwards would never reach them. recompute against the current
    -- stand-in, unless the dev named a font themselves.
    local userTable = if typeof(value) == "table" then value else nil
    if not (userTable and (userTable.Font or userTable.font)) then
        resolved.Font = variables.brandFont(Enum.FontWeight.Medium)
    end
    if not (userTable and (userTable.TitleFont or userTable.titleFont)) then
        resolved.TitleFont = variables.brandFont(Enum.FontWeight.SemiBold)
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

    -- the layout decides the window's whole shape, so it has to settle before the first fit
    local layout = resolveLayout(properties.sidebarLayout or properties.SidebarLayout)

    local self = setmetatable({
        name = properties.name or properties.Name or "Rayfield Window",
        subheading = properties.subtitle or properties.Subtitle,
        layout = layout,
        size = fitWindowSize(layout.mode),
        instances = {},
        connections = {},

        icon = properties.icon or properties.Icon,
        showName = properties.showName or properties.ShowName or "Rayfield",
        showIcon = properties.showIcon or properties.ShowIcon or constants.icons.rayfield,
        -- collapse to a round badge rather than an icon-and-label pill
        showIconOnly = properties.showIconOnly or properties.ShowIconOnly or false,
        -- the line under the player's name in the sidebar's profile block
        profileText = properties.profile or properties.Profile,

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

    -- Defaults before anything is built: the sidebar rail reads showProfile as it lays out, and
    -- LoadSettings lands on top of these once the UI exists.
    self.settings = {
        toggleKeybind = Enum.KeyCode.K,
        mouseOverride = true, -- free the cursor while the menu is open (for FPS games that lock it)
        keepOnScreen = true, -- clamp the drag so the window cant be pulled off screen
        welcomeToast = true, -- the "signed in as" toast on first open for a new/changed account
        haptics = false, -- off by default; opt in from settings (buzzes on presses/notifications)
        showProfile = true, -- the player chip at the base of the sidebar rail
    }

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

    -- Bottom fade - gradient overlay so elements scroll out softly at the base of the content.
    -- Sized and anchored to whatever the layout gives the content: the full window under top
    -- tabs, the card alone beside a sidebar.
    self.bottomFade = self:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.fromScale(1, 1),
        Size = self.layout.fadeSize,
        ZIndex = constants.zIndex.bottomFade,

        -- Animation
        BackgroundTransparency = 1, -- In = 0

        Parent = self.main,
    })

    self.bottomFadeCorner = self:_roundCorners(self.bottomFade, self.layout.fadeCorners)

    self.bottomFadeGradient = self:Create("UIGradient", {
        Rotation = 270,
        Offset = Vector2.new(0, 0.2),
        Transparency = self.layout.fadeTransparency,

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
        Size = UDim2.new(1, 0, 0, self.layout.topbarHeight),
        -- Active so empty topbar space can catch input directly - tabs/actions/search sit on
        -- top and still get first pick, this is just the backdrop becoming a drag handle
        Active = true,

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

    -- Anchored bottom-right in both layouts: under top tabs it fills the width, beside a
    -- sidebar it gives the rail its slice off the left and becomes a card in the corner.
    self.elements = self:Create("Frame", {
        Size = UDim2.new(1, 0, 1, -self.layout.chromeHeight),
        Position = UDim2.fromScale(1, 1),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ClipsDescendants = true,

        Parent = self.main,
    })

    if self.layout.mode == "sidebar" then
        self.elementsCorner = self:_roundCorners(self.elements, self.layout.cardCorners)

        self.elementsStroke = self:Create("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,

            -- Animation
            Transparency = 1, -- In = 0

            Parent = self.elements,
        }, { Color = "SurfaceStroke" })

        -- the rim is the gradient's job: a diagonal sweep that's brightest at the top-left
        -- corner and gone by the bottom-right, where the window's own stroke already runs
        self:Create("UIGradient", {
            Rotation = self.layout.cardStrokeRotation,
            Transparency = self.layout.cardStrokeTransparency,

            Parent = self.elementsStroke,
        })
    end

    self.elementsLayout = self:Create("UIPageLayout", {
        Padding = UDim.new(0, 0),
        FillDirection = self.layout.pageDirection,
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

    -- Tabs Preparation. Either shape is `tabList` from here on, so nothing downstream has to
    -- know which one it got.
    if self.layout.mode == "sidebar" then
        sidebar.build(self, self.layout)
        sidebar.applyWidth(self, layouts.railWidthFor(self.layout, self.size.X.Offset))
    else
        self.tabList = self:Create("ScrollingFrame", {
            Name = "Tabs",
            Active = true,
            Size = UDim2.new(1, 0, 0, self.layout.tabStripHeight),
            Position = UDim2.new(0.5, 0, 0, self.layout.tabStripTop),
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
    end

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
    -- the field is built after the rail, so hand it the width the rail actually settled on
    self:_applyRailWidth()

    self.unloaded = false
    self.minimised = false
    self.hidden = true
    self.animating = false
    self._revealing = false
    self.hasShownOnce = false
    self._collapsedShown = false

    -- saved settings land after the rail was built against the defaults, so let it settle again
    self:LoadSettings()
    if self.layout.mode == "sidebar" then
        sidebar.reflowProfile(self)
        sidebar.setSubtitle(self, self.profileText)
    end
    hapticEngine.setContainer(self.screenGui) -- effects live with the interface, not the workspace
    hapticEngine.setEnabled(self.settings.haptics) -- honour a saved off before any interaction
    chrome.buildCollapsedFace(self)
    self:_bindKeybind()
    self:_bindMouseOverride()
    self:_bindTopbarDrag()
    self:_watchViewport()
    self:_buildSettingsUI()

    self:_syncLiveAnimation()

    return self
end

-- start or stop the gradient drift to match the current theme. called on build and on every
-- ChangeTheme, so switching into or out of an animated theme takes effect either way.
function Window:_syncLiveAnimation()
    if not self.theme.LiveAnimation then
        self._liveAnimating = false -- the running loop sees this and stops after its current leg
        return
    end
    if self._liveAnimating then
        return -- already drifting
    end

    self._liveAnimating = true
    -- generation stamp: an old loop parked in Completed:Wait() through a static->animated
    -- swap wakes up stale and exits, instead of drifting alongside the new loop
    self._liveGeneration = (self._liveGeneration or 0) + 1
    local generation = self._liveGeneration
    task.spawn(function()
        local out = true
        local tweenInfo = TweenInfo.new(10, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

        while self._liveGeneration == generation and self._liveAnimating and not self.unloaded do
            local tweenW = variables.tweenService:Create(self.windowGradient, tweenInfo, {
                Offset = Vector2.new(if out then 0.4 else -0.2, 0),
                Rotation = (if out then 220 else 280),
            })

            self._liveTween = tweenW
            tweenW:Play()
            tweenW.Completed:Wait()
            out = not out
        end
        if self._liveGeneration == generation then
            self._liveAnimating = false
            self._liveTween = nil
        end
    end)
end

function Window:ChangeTheme(theme)
    -- A named theme fully switches: resolve against default so keys it omits reset rather than
    -- lingering from the previous theme. A partial table just overrides the keys it names.
    local overrides = if typeof(theme) == "table" then theme else resolveTheme(theme)
    for name, value in overrides do
        self.theme[name] = coerceThemeValue(name, value)
    end
    -- match the constructor: a hand-written table gets derived strokes for the keys it changes
    if typeof(theme) == "table" then
        deriveStrokes(self.theme, overrides)
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
    if self.hidden then
        -- a hidden window has nothing to animate into, so defer the refresh to the next Show
        -- rather than dropping it and reopening with the old themes state colours
        self._themeRefreshPending = true
    else
        self:_refreshElementThemes()
    end

    self:_syncLiveAnimation()
end

function Window:_refreshElementThemes()
    for _, tab in self.tabs do
        for _, element in tab.elements do
            if element._refreshTheme then
                element:_refreshTheme()
            end
        end
    end
end

function Window:CreateTab(properties)
    assert(not self.unloaded, "Cannot create a tab on an unloaded window.")
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

        -- a tab built after the window is already open reveals its pill right away, the
        -- same way _register shows late elements. hidden/minimised windows reveal on restore.
        if not self.hidden and not self.minimised then
            newTab.topbarItem.Visible = true
            newTab:_applyVisual(
                if self.selectedTab == newTab then "selected" else "unselected",
                TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            )
        end
    end

    return newTab
end

function Window:CreateTag(properties)
    assert(not self.unloaded, "Cannot create a tag on an unloaded window.")
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

-- Restore an element built after the config was already loaded. autoLoad only fires once on
-- first Show, so without this a late element (one built after a remote fetch, say) keeps its
-- default and the next autosave writes that default over the saved value.
-- Called from the CreateX tails once the element is fully built, since _registerControl runs
-- mid-construction and :Set would touch instances that dont exist yet.
function Window:_restoreLate(element)
    if not self._loadedConfig or not element.flag or element.forgetState then
        return
    end

    local wasLoading = self._loading
    self._loading = true -- dont autosave the value we just read back
    persistence.applyTo(element, self._loadedConfig[element.flag])
    self._loading = wasLoading
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
-- tab level (groups dont hold them), so a scan over each tab's elements catches them all.
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
    if self.unloaded then
        return -- nothing to parent into once the ScreenGui is gone
    end
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

-- Top-centre / bottom-centre toast stack. Like Notify but for brief, centred messages that drop
-- in from the top (or rise from the bottom) of the screen (newest on top). Each toast takes
-- { title, subtitle?, icon?, duration?, position? }.
function Window:Toast(properties)
    if self.unloaded then
        return
    end

    -- both casings and any case for the value, like every other toast property
    properties = if typeof(properties) == "table" then properties else {}
    local position = properties.position or properties.Position or "Top"
    local isTop = typeof(position) ~= "string" or position:lower() ~= "bottom"
    properties.position = if isTop then "Top" else "Bottom"
    local containerKey = if isTop then "_toastsTop" else "_toastsBottom"
    local container = self[containerKey]

    if not container then
        container = self:Create("Frame", {
            Name = "Toasts",
            Size = UDim2.new(0, maxToastWidth, 1, -24),
            Position = if isTop
                then if self._collapsedShown then topToastClosedPosition else topToastOpenPosition
                else UDim2.new(0.5, 0, 1, -12),
            AnchorPoint = if isTop then Vector2.new(0.5, 0) else Vector2.new(0.5, 1),
            BackgroundTransparency = 1,
            ZIndex = constants.zIndex.toast,

            Parent = self.screenGui,
        })

        self:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            VerticalAlignment = if isTop then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            -- gap lives inside each toast so removing one collapses its gap with it
            Padding = UDim.new(0, 0),

            Parent = container,
        })

        self[containerKey] = container
    end

    return require(script.Parent.toast).new(self, properties, container)
end

-- Centred modal over a dimmed backdrop. Takes { title, subtitle?, icon?, content?, boxes?,
-- options?, dismissable? } - give it options for a choice dialog, or boxes for a changelog.
-- Returns the popup handle (call :Close() to dismiss it yourself).
function Window:Popup(properties)
    if self.unloaded then
        return
    end
    return require(script.Parent.popup).new(self, properties)
end

function Window:Hide()
    -- idempotent: a second Hide while collapsed would capture the pill spot as the
    -- restore position and teleport the window there on the next Show
    if self.animating or self.hidden then
        return
    end

    -- drop out of search first so we grow back into the normal tab view on next show. tabList
    -- stays hidden here since the collapse hides it anyway; Show re-enables it.
    if self._searching then
        search.close(self, { showTabs = false, jumpTo = self.selectedTab and self.selectedTab.tabPage })
    end

    -- a keybind left recording would capture the next keypress against an invisible UI and
    -- eat the toggle key
    if self._recordingKeybind then
        self._recordingKeybind:_stopRecording()
    end

    self.animating = true
    self._revealing = true
    self.hidden = true
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
    self:_fadeSurfaces(false, fadeInfo)

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
    local collapse = variables.tweenService:Create(self.main, moveInfo, { Size = size, Position = home })
    collapse.Completed:Connect(function(state)
        if state ~= Enum.PlaybackState.Completed or not self.hidden then
            return
        end

        -- The pill now occupies the top-centre slot. Move the stack only when the frame says
        -- the collapse is complete, so this cannot drift from the animation that creates it.
        self._collapsedShown = true
        setTopToastPosition(self, true)
        self.collapsedInteract.Visible = true
        self.animating = false
        self._revealing = false
    end)
    collapse:Play()
    variables.tweenService:Create(self.windowCorner, cornerInfo, { CornerRadius = UDim.new(1, 0) }):Play()

    -- once the chrome's faded, drop it and the scrolling content so nothing squashes/pokes
    -- out as the frame shrinks around it, then bring the collapsed face up over the top
    task.delay(0.18, function()
        if not self.hidden then
            return
        end
        self.topbar.Visible = false
        self:_setContentVisible(false)

        chrome.setCollapsedShown(self, true, faceInfo)
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
        self:_fadeSurfaces(true, fadeInfo)

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
            self:_setContentVisible(true)

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
            self:_setContentVisible(false)
            for _, tab in pairs(self.tabs) do
                if not tab.neglectSelector and tab.topbarItem then
                    tab.topbarItem.Visible = false
                end
            end
        end)

        self:_fadeSurfaces(false, fadeInfo)
        variables.tweenService
            :Create(self.main, sizeInfo, { Size = UDim2.fromOffset(self.size.X.Offset, self.layout.topbarHeight) })
            :Play()

        variables.tweenService
            :Create(self.drag.drag, sizeInfo, {
                Position = UDim2.new(
                    self.main.Position.X.Scale,
                    self.main.Position.X.Offset,
                    self.main.Position.Y.Scale,
                    self.main.Position.Y.Offset + self.layout.topbarHeight / 2 + 15
                ),
            })
            :Play()

        task.delay(0.5, function()
            self.animating = false
        end)
    end
end

-- Park the drag bar under the window's bottom edge, matching whichever positioning the window
-- itself uses so a centred window stays centred and a dragged one stays where it was left.
function Window:_syncDragBar()
    local bar = self.drag and self.drag.drag
    if not bar then
        return
    end
    local position = self.main.Position
    local below = self.size.Y.Offset / 2 + 15
    bar.Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + below)
end

-- Pull a dragged window back on screen after a re-fit, the same way a drag clamps. A window
-- parked near an edge would otherwise end up half off it when the viewport shrinks underneath.
-- Where a position ends up once the current size has to fit on the current screen. Returns it
-- unchanged when theres nothing to do, so callers can compare.
function Window:_clampedPosition(position: UDim2): UDim2
    if not self.settings or not self.settings.keepOnScreen then
        return position
    end
    -- untouched windows sit on scale and are centred, so theyre on screen by construction -
    -- clamping would only freeze them to offsets and stop them recentring later
    if position.X.Scale ~= 0 or position.Y.Scale ~= 0 then
        return position
    end

    local screen = self.screenGui.AbsoluteSize
    local halfX, halfY = self.size.X.Offset / 2, self.size.Y.Offset / 2
    local margin = 8
    -- math.max in case the window is bigger than the screen
    local x = math.clamp(position.X.Offset, halfX + margin, math.max(halfX + margin, screen.X - halfX - margin))
    local y = math.clamp(position.Y.Offset, halfY + margin, math.max(halfY + margin, screen.Y - halfY - margin))
    if x == position.X.Offset and y == position.Y.Offset then
        return position
    end
    return UDim2.fromOffset(x, y)
end

function Window:_clampToScreen()
    self.main.Position = self:_clampedPosition(self.main.Position)
end

-- Take the size the current screen calls for. Only a live window is resized on the spot;
-- hidden, minimised or mid-animation ones just bank the size and pick it up on their next
-- show, so a rotation cant yank a collapsed pill back open.
function Window:_applyWindowSize()
    if self.unloaded then
        return
    end

    local size = fitWindowSize(self.layout.mode)
    local changed = size ~= self.size
    self.size = size

    -- the rail is sized off main, so setting it now is right whether main resizes on the spot
    -- below or grows into the banked size on its next show
    self:_applyRailWidth()

    -- a window mid-animation is already tweening toward the old size, so bank the change and
    -- let the reconcile apply it once the tween is done rather than fighting it
    if self.hidden or self.minimised or self.animating or self._revealing then
        self._pendingResize = self._pendingResize or changed
        return
    end

    if not changed and not self._pendingResize then
        return
    end
    self._pendingResize = false

    self.main.Size = size
    self:_clampToScreen()
    self:_syncDragBar()
end

-- The rail keeps its labels while there's width to spare and drops to icons when there isn't,
-- so the content card never pays for them. No-op outside the sidebar layout.
function Window:_applyRailWidth()
    if self.layout.mode ~= "sidebar" then
        return
    end
    sidebar.applyWidth(self, layouts.railWidthFor(self.layout, self.size.X.Offset))
end

-- Follow the screen. The property signal is the fast path, but CurrentCamera gets swapped
-- (respawn, or a game replacing it) and a listener bound to the old camera dies silently, so
-- rebind on the swap and keep a slow reconcile behind it as the backstop.
function Window:_watchViewport()
    local cameraConnection: RBXScriptConnection? = nil
    local pending = false

    local function request()
        -- a rotation fires a burst of intermediate sizes, so settle on the last one
        if pending then
            return
        end
        pending = true
        task.defer(function()
            pending = false
            self:_applyWindowSize()
        end)
    end

    local function bind()
        if cameraConnection then
            self:Disconnect(cameraConnection)
            cameraConnection = nil
        end
        local camera = variables.workspace.CurrentCamera
        if camera then
            cameraConnection = self:Connect(camera:GetPropertyChangedSignal("ViewportSize"), request)
        end
        request()
    end

    self:Connect(variables.workspace:GetPropertyChangedSignal("CurrentCamera"), bind)
    bind()

    -- Backstop for anything the signals miss. Heartbeat rather than a wait loop so it rides the
    -- normal connection cleanup and cant spin if the scheduler hands back a wait that never yields.
    local sinceReconcile = 0
    self:Connect(variables.runService.Heartbeat, function(delta: number)
        sinceReconcile += delta
        if sinceReconcile < viewportReconcileInterval then
            return
        end
        sinceReconcile = 0
        self:_applyWindowSize()
    end)
end

function Window:_bindKeybind()
    self:Connect(variables.userInputService.InputBegan, function(input, processed)
        if processed or self._recordingKeybind then
            return -- a keybind element is mid-rebind, dont eat its capture
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

    -- right-release doesnt always flip MouseBehavior back (so the signals above wouldnt fire),
    -- so re-free explicitly once the pan ends
    self:Connect(uis.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            free()
        end
    end)

    -- Show calls this on open to free the cursor immediately (the signals above only fire on change)
    self._freeMouse = free
end

-- Grabbing the topbar drags the whole window too, its own separate handle from the bar
-- underneath - tracks the cursor 1:1 with no lag, unlike the bars own deliberate smoothing, and
-- the bar just glues to wherever main currently is each frame so it never drifts off on its own
function Window:_bindTopbarDrag()
    local uis = variables.userInputService
    local dragging = false
    local relative = Vector2.zero

    -- main.Position lives in a space shifted from AbsolutePosition by the gui inset, even
    -- though the ScreenGui ignores it - add it back or the window jumps on the first move
    local offset = Vector2.zero
    if self.screenGui and self.screenGui.IgnoreGuiInset then
        offset = variables.guiService:GetGuiInset()
    end

    local function getTarget()
        local position = uis:GetMouseLocation() + relative + offset
        local x, y = position.X, position.Y

        if self.settings and self.settings.keepOnScreen then
            local size = self.main.AbsoluteSize
            local screen = self.screenGui.AbsoluteSize
            local margin = 8
            local halfX, halfY = size.X / 2, size.Y / 2
            x = math.clamp(x, halfX + margin, math.max(halfX + margin, screen.X - halfX - margin))
            y = math.clamp(y, halfY + margin, math.max(halfY + margin, screen.Y - halfY - margin))
        end

        return UDim2.fromOffset(x, y)
    end

    -- Global ZIndexBehavior still delivers InputBegan to an Active ancestor even when a child
    -- button covers that exact pixel, so checking the event alone isnt enough - a press over the
    -- tabs or the actions has to be rejected by where it actually landed, not just left to bubble
    local function overInteractiveChild(x, y)
        for _, region in { self.tabList, self.actionContainer } do
            local position, size = region.AbsolutePosition, region.AbsoluteSize
            if x >= position.X and x <= position.X + size.X and y >= position.Y and y <= position.Y + size.Y then
                return true
            end
        end
        return false
    end

    self:Connect(self.topbar.InputBegan, function(input, processed)
        if processed then
            return
        end

        local inputType = input.UserInputType.Name
        if inputType ~= "MouseButton1" and inputType ~= "Touch" then
            return
        end

        if overInteractiveChild(input.Position.X, input.Position.Y) then
            return
        end

        -- a grab started mid-reveal would fight the tween thats still moving the window
        if not self:_interactive() then
            return
        end

        dragging = true

        if self.screenGui and self.screenGui.IgnoreGuiInset then
            offset = variables.guiService:GetGuiInset()
        end

        relative = self.main.AbsolutePosition + self.main.AbsoluteSize * self.main.AnchorPoint - uis:GetMouseLocation()
    end)

    self:Connect(uis.InputEnded, function(input)
        local inputType = input.UserInputType.Name
        if inputType == "MouseButton1" or inputType == "Touch" then
            dragging = false
        end
    end)

    -- alt-tabbing with the button still down never delivers InputEnded, so without this the
    -- grab stays armed and the window snaps to the cursor the moment youre back
    self:Connect(uis.WindowFocusReleased, function()
        dragging = false
    end)

    self:Connect(variables.runService.RenderStepped, function()
        if not dragging then
            return
        end

        -- hidden or mid-animation means the grab went stale under us, so drop it here rather
        -- than let it wake up later and yank the window to wherever the cursor drifted
        if not self:_interactive() then
            dragging = false
            return
        end

        self.main.Position = getTarget()

        if self.drag and self.drag.drag then
            local mainPosition = self.main.Position
            self.drag.drag.Position = UDim2.new(
                mainPosition.X.Scale,
                mainPosition.X.Offset,
                mainPosition.Y.Scale,
                mainPosition.Y.Offset + (self.main.Size.Y.Offset / 2 + 15)
            )
        end
    end)
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

    -- only the sidebar layout has somewhere to put a profile, so only it offers the switch
    if self.layout.mode == "sidebar" and self.profile then
        self.rfSettings:CreateToggle({
            name = "Show profile",
            description = "Shows your avatar and name at the base of the sidebar. Turn it off to keep "
                .. "them out of a stream or a screenshot.",
            value = self.settings.showProfile,
            callback = function(state)
                sidebar.setProfileEnabled(self, state)
                self:SaveSettings()
            end,
        })
    end

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
                if self:_applyNamedConfig(selected) then
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

-- The line under the player's name in the sidebar's profile block ("Premium", a rank, a tier).
-- Pass nil or "" to drop it and leave the name on its own. No-op in the top-tab layout, which
-- has no profile block to put it in.
function Window:SetProfile(text)
    self.profileText = text
    sidebar.setSubtitle(self, text)
end

function Window:SaveSettings()
    return persistence.saveSettings(self)
end

function Window:LoadSettings()
    return persistence.loadSettings(self)
end

-- Round a shape's corners to the theme's radius. `corners` names the ones that take it and
-- squares the rest; omit it and the whole shape is rounded, which is the single themed radius
-- the top layout has always used.
function Window:_roundCorners(parent, corners)
    if not corners or not perCornerSupported then
        return self:Create("UICorner", {
            Parent = parent,
        }, { CornerRadius = "CornerRoundness" })
    end

    local properties = { Parent = parent }
    local themed = {}
    for _, name in cornerNames do
        properties[name] = UDim.new(0, 0)
    end
    for _, name in corners do
        properties[name] = nil -- the theme sets this one, so dont square it first
        themed[name] = "CornerRoundness"
    end

    return self:Create("UICorner", properties, themed)
end

-- Lock or unlock one element. It dims, it stops taking input, and its callback wont fire (see
-- _runGuarded). `reason` replaces the element's description while it's locked, so the UI can
-- say why without covering the element up to do it.
function Window:_setElementLocked(element, locked, reason)
    locked = locked == true
    -- locked starts out nil, so compare against a real boolean: `nil == false` is false, and
    -- Unlock on an element that was never locked would otherwise build a scrim just to fade it
    -- straight back out. A fresh reason on an already-locked element is still worth applying.
    local wasLocked = element.locked == true
    if wasLocked == locked and not (locked and reason) then
        return
    end
    element.locked = locked

    if not element.lockScrim then
        self:_buildLockScrim(element)
    end

    local info = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    if locked then
        element.lockScrim.Visible = true
    end
    variables.tweenService
        :Create(element.lockScrim, info, {
            BackgroundTransparency = if locked then lockScrimTransparency else 1,
        })
        :Play()
    if not locked then
        task.delay(info.Time, function()
            if not element.locked and element.lockScrim then
                element.lockScrim.Visible = false -- out of hit-testing once it has faded
            end
        end)
    end

    -- say why in the description, and put the element's own back when it unlocks
    local descriptor = element.descriptor
    if not descriptor then
        return
    end

    if locked then
        -- `or`, not plain assignment: re-locking with a new reason must not remember the old
        -- reason as though it were the element's own description
        element._descriptionBefore = element._descriptionBefore or descriptor.titleLabel.Text
        descriptor.titleLabel.Text = locale.resolve(reason or "This element is locked.")
    elseif element._descriptionBefore then
        descriptor.titleLabel.Text = element._descriptionBefore
        element._descriptionBefore = nil
    end

    variables.tweenService
        :Create(descriptor.titleLabel, info, {
            TextTransparency = if locked then lockedDescriptionTransparency else 0.7,
        })
        :Play()
end

-- The scrim: a sheet of the window's own colour over the element, dimming it. It carries
-- nothing itself - it's the dimming and the description that say what's happened. It is an
-- Active button, so it swallows anything aimed at the element underneath rather than leaving
-- each element to check a flag on every input path.
function Window:_buildLockScrim(element)
    element.lockScrim = self:Create("TextButton", {
        Name = "ElementLock",
        Active = true,
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        Text = "",
        TextTransparency = 1,
        ZIndex = constants.zIndex.elementLock,
        Visible = false,

        -- no literal BackgroundColor3 here: Create applies the theme first and plain properties
        -- second, so setting it both ways would paint straight over the themed colour
        BackgroundTransparency = 1, -- In = lockScrimTransparency

        Parent = element.main,
    }, { BackgroundColor3 = { "WindowColor", firstColor } })

    self:Create("UICorner", {
        Parent = element.lockScrim,
    }, { CornerRadius = "ElementCornerRadius" })
end

-- Show or hide everything below the topbar in one go: the content area and the tab selector,
-- whichever shape it is. Kept together so a collapse can never leave a rail floating over a pill.
function Window:_setContentVisible(visible)
    self.elements.Visible = visible
    self.tabList.Visible = visible
    if self.sidebar then
        self.sidebar.Visible = visible
    end
end

-- The window's own surfaces: shadow, rim, the fade over the content, and (sidebar) the content
-- card and the profile chip. These come and go together every time the window opens or collapses.
function Window:_fadeSurfaces(shown, fadeInfo)
    local targets = {
        [self.windowShadow] = { Transparency = if shown then 0.6 else 1 },
        [self.windowStroke] = { Transparency = if shown then 0.95 else 1 },
        [self.bottomFade] = { BackgroundTransparency = if shown then 0 else 1 },
    }

    if self.elementsStroke then
        targets[self.elements] = {
            BackgroundTransparency = if shown then self.layout.cardTransparency else 1,
        }
        targets[self.elementsStroke] = { Transparency = if shown then 0 else 1 }
    end

    for instance, properties in targets do
        if fadeInfo then
            variables.tweenService:Create(instance, fadeInfo, properties):Play()
        else
            for property, value in properties do
                instance[property] = value
            end
        end
    end

    sidebar.setProfileShown(self, shown, fadeInfo)
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
    -- idempotent: replaying the restore on a visible window teleports it to a stale position
    if self.animating or not self.hidden then
        return
    end
    self.animating = true
    self._revealing = true

    -- autoLoad reflects the saved config once, on first open. Re-loading on every show would
    -- wipe any changes the user made and closed without saving. a load that throws must not
    -- strand animating=true, or the window could never open again.
    if self.configuration.autoLoad and not self._autoLoaded then
        self._autoLoaded = true
        local ok, err = pcall(self.Load, self)
        if not ok then
            log.warn("Rayfield: Failed to load configuration - " .. tostring(err))
        end
    end

    self.hidden = false
    self.minimised = false

    -- a ChangeTheme landed while we were collapsed; apply it before anything fades back in
    if self._themeRefreshPending then
        self._themeRefreshPending = false
        self:_refreshElementThemes()
    end

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
    -- the screen can have changed while we were hidden, so where it sat may no longer fit
    local target = self:_clampedPosition(self._restorePosition or UDim2.new(0.5, 0, 0.5, 0))
    self._restorePosition = target

    local growInfo = TweenInfo.new(0.35, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut)
    local cornerInfo = TweenInfo.new(0.35, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut)
    local fadeInfo = TweenInfo.new(0.28, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

    -- Phase 1: nothing but the pill morphing back into the window frame. The collapsed face
    -- fades off, main grows + un-rounds. No chrome, no content - so you never see the topbar,
    -- tabs or bottom fade floating over a frame that isn't a window yet.
    chrome.setCollapsedShown(self, false, TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
    local restore = variables.tweenService:Create(self.main, growInfo, { Size = self.size, Position = target })
    restore.Completed:Connect(function(state)
        if state ~= Enum.PlaybackState.Completed or self.hidden or self.unloaded then
            return
        end

        -- The restored frame has cleared the pill's slot. Its own completion is the single
        -- clock for moving the toast stack back, regardless of how this motion is implemented.
        self._collapsedShown = false
        setTopToastPosition(self, true)
    end)
    restore:Play()
    variables.tweenService:Create(self.windowCorner, cornerInfo, { CornerRadius = self.theme.CornerRoundness }):Play()

    -- Phase 2: once the frame actually reads as a window, fade its chrome in and stagger the
    -- open tab's elements. Other tabs snap ready off-screen - nobody's looking, so no animation.
    task.delay(0.22, function()
        self.topbar.Visible = true
        self:_setContentVisible(true)

        self:_fadeSurfaces(true, fadeInfo)

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
        self._revealing = false
    end)
end

function Window:_firstShow()
    -- Intro animation
    self:_setContentVisible(true)

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
    self:_fadeSurfaces(true, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out))
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

    -- Stagger the selector in, but on a budget: past a handful of tabs the rest arrive
    -- together rather than making a long list crawl in one at a time.
    task.spawn(function()
        local info = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        local staggered = 0
        for _, tab in pairs(self.tabs) do
            if not tab.neglectSelector then
                tab.topbarItem.Visible = true
                tab:_applyVisual(if self.selectedTab == tab then "selected" else "unselected", info)
                tab:_spinGradients()

                staggered += 1
                if staggered <= maxStaggeredTabs then
                    task.wait(tabStagger)
                end
            end
        end
    end)

    self:_revealElements(0.03, 2)

    task.wait(1)

    -- the fit can change between construction and now (a late camera banks a new size), so
    -- re-derive the bar's spot rather than trusting the construction-time position
    self:_syncDragBar()
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
    self._revealing = false

    -- Welcome the user once if this is a new/changed account on this device (unless they've
    -- turned it off in settings). Just a toast now - the profile chip is a toast like any other.
    local localPlayer = variables.localPlayer
    if localPlayer and self.settings.welcomeToast and chrome.isNewUser() then
        self:Toast({
            title = localPlayer.DisplayName,
            subtitle = locale.resolve("Signed in as"),
            subtitleAbove = true, -- reads "Signed in as" / name, label over value
            avatar = localPlayer.UserId,
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

-- Load a named config and make it the live state autoLoad restores next session. Loading only
-- applies to the running UI; writing it back to the default file is what carries it across
-- sessions, so the config manager can pick a config once and have it stick.
function Window:_applyNamedConfig(name)
    if not self:Load(name) then
        return false
    end
    -- promotion means the default file becomes this config, unbuilt elements included; repoint
    -- the carry-forward so Save doesnt drop flags for elements that havent registered yet
    local _, defaultPath = persistence.getPath(self)
    self._loadedConfigPath = defaultPath
    self:Save()
    return true
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
-- Move the page view only. Tab:Select owns the selection state and the pill, and calls this
-- for the scroll; nothing else should jump pages without going through it.
function Window:_jumpTo(page)
    if page then
        self.elementsLayout:JumpTo(page)
    end
end

-- Go to a tab, by name or by the tab itself. Routes through Tab:Select so the selection,
-- the pill and the page all agree; jumping the page alone would leave the wrong tab lit and
-- the reveal animations pointed at the wrong elements.
function Window:Navigate(tab)
    if tab == nil then
        return
    end

    local target
    for _, candidate in self.tabs do
        -- by name, by the tab itself, or by the page instance a caller held onto
        if candidate == tab or candidate.name == tab or candidate.tabPage == tab then
            target = candidate
            break
        end
    end

    if not target then
        return
    end
    target:Select()
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
            variables.tweenService
                :Create(stroke, outInfo, { Color = self.theme.SurfaceStroke, Transparency = 0.85 })
                :Play()
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

    self:ConnectFor(element, element.main.MouseEnter, function()
        if not self:_interactive() then
            return -- window still revealing/hiding: dont light up mid-animation
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

    self:ConnectFor(element, element.main.MouseLeave, function()
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
    -- a locked element fires nothing. This is the one place every element's callback goes
    -- through, so locking here is what makes the lock real rather than cosmetic.
    if element.locked then
        return
    end

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
        -- minimal elements build without a label, and the flash must survive that
        if element.title then
            element.title.Text = locale.resolve("Error, log recorded in console.")
        end

        log.warn(
            `Rayfield encountered an error, with the callback for a {element.__type} component named '{element.name}':`
        )
        log.print(err)

        task.wait(1)

        if element.title then
            element.title.Text = locale.resolve(element.name)
        end
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
    local size = if self.showIconOnly then collapsedIconSize else collapsedSize
    -- a pill that's been dragged stays where it was put, rather than snapping back to the top
    if self._collapsedPosition then
        return self._collapsedPosition, size
    end
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

-- true when the window is up and not mid reveal or hide. action icons settle on this rather
-- than _interactive: minimise animates too, but it never repaints the icons the way show and
-- hide do, so an icon settling during it has nothing to fight and would otherwise stay lit.
function Window:_settled()
    return not self.hidden and not self._revealing
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
            self.localeProperties[instance] = nil
        end
    end

    root:Destroy()
end

-- Drop a batch of connections in one go. Disconnect does a linear scan and a shift per
-- connection, which is fine for one and quadratic for a thousand; this filters each list once.
-- `owner` is the element that also tracked them, if any.
function Window:DisconnectMany(owner, connections)
    if not connections or #connections == 0 then
        return
    end

    local dropping = {}
    for _, connection in connections do
        dropping[connection] = true
        connection:Disconnect()
    end

    local function filter(list)
        if not list then
            return
        end
        local kept = 0
        for index = 1, #list do
            local entry = list[index]
            if not dropping[entry] then
                kept += 1
                list[kept] = entry
            end
        end
        for index = #list, kept + 1, -1 do
            list[index] = nil
        end
    end

    filter(self.connections)
    if owner and owner ~= self then
        filter(owner.connections)
    end
end

-- DestroySubtree for a batch. One walk of the tracked instances for the whole set rather than
-- one per subtree - tearing down a long list was otherwise re-walking every instance in the
-- window for every row it dropped.
function Window:DestroySubtrees(roots)
    if not roots or #roots == 0 then
        return
    end

    local inSubtree = {}
    for _, root in roots do
        inSubtree[root] = true
        for _, descendant in root:GetDescendants() do
            inSubtree[descendant] = true
        end
    end

    local kept = 0
    for index = 1, #self.instances do
        local instance = self.instances[index]
        if inSubtree[instance] then
            self.themeProperties[instance] = nil
            self.localeProperties[instance] = nil
        else
            kept += 1
            self.instances[kept] = instance
        end
    end
    for index = #self.instances, kept + 1, -1 do
        self.instances[index] = nil
    end

    for _, root in roots do
        root:Destroy()
    end
end

function Window:Unload()
    self.unloaded = true
    -- drop our effects and release the gui they hung on, but leave the enabled flag alone -
    -- another window may still be open and haptics arent ours to switch off for it
    hapticEngine.teardown()
    hapticEngine.releaseContainer(self.screenGui)
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

    -- destroying isnt forgetting: a hub that loads and unloads repeatedly would keep the whole
    -- dead instance graph reachable through the handle it still holds. DestroySubtree already
    -- clears as it goes, so match it here.
    table.clear(self.connections)
    table.clear(self.instances)
    table.clear(self.themeProperties)
    table.clear(self.localeProperties)
    table.clear(self.controls)
    table.clear(self.tabs)
end

return Window
