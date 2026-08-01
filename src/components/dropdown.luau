--!nonstrict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local Dropdown = {}
Dropdown.__index = Dropdown
Dropdown.__type = "Dropdown"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local functions = require(utility.functions)
local image = require(utility.image)
local constants = require(utility.constants)
local locale = require(utility.locale)
local hapticEngine = require(utility.HapticEngine)

local chevronIcon = constants.icons.chevron
local checkIcon = constants.icons.check
local dotIcon = constants.icons.dot
local searchIconAsset = constants.icons.search

-- Per-corner radii: an option's edge is rounded when nothing sits next to it, sharp otherwise
local roundRadius = UDim.new(0, 12)
local flatRadius = UDim.new(0, 7)

local searchCollapsedHeight = 30
local searchExpandedHeight = 38

-- Option row geometry, and the room the card takes around the list of them: the header, the gap
-- under it, the card's own padding and the search bar. Named because the height the card opens
-- to is built from them, and a cap written as a bare number drifts out of step with the rows it
-- is meant to be counting.
local optionHeight = 38
local optionGap = 5
local listPadding = 2 -- above and below the rows, so the first and last strokes clear the clip

-- The header pill and the gap under it, which is what the options card is offset by, and the
-- card's own padding. Everything the card owes on top of its rows is one of these, so the height
-- it opens to is added up from them rather than carried as a single number that no longer says
-- what it is made of, and that therefore stops being true when one of the parts changes.
local headerHeight = 41
local headerGap = 6
local cardPaddingTop = 7
local cardPaddingBottom = 6
local cardPadding = cardPaddingTop + cardPaddingBottom

-- How many options are on screen before the list starts scrolling. Two was enough to say what
-- the control was; it was not enough to choose from without scrolling almost immediately.
local maxVisibleOptions = 4

-- The row of bulk actions a multi-select card carries above its list, and the soft edge drawn
-- over the bottom of that list while there is more of it below the fold.
local actionsHeight = 22
local fadeHeight = 26
local fadeTween = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- The card's own colour, taken from the first stop of its gradient, so the soft edge is drawn in
-- the tone the list sits on whatever the theme is rather than a grey guessed against the default.
local function firstColorOf(value)
    return functions.toColorSequence(value).Keypoints[1].Value
end
local searchTween = TweenInfo.new(0.35, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

local function dedupStrings(arr)
    local seen = {}
    local out = {}
    for _, v in arr do
        if typeof(v) == "string" and not seen[v] then
            seen[v] = true
            table.insert(out, v)
        end
    end
    return out
end

local function normalizeValue(value, multi)
    if value == nil then
        return {}
    end
    if typeof(value) == "string" then
        return { value }
    end
    if typeof(value) == "table" then
        local out = dedupStrings(value)
        if not multi and #out > 1 then
            return { out[1] }
        end
        return out
    end
    return {}
end

-- The visible selection is always the intent narrowed to options that currently exist.
local function intersectWithOptions(value, options)
    local out = {}
    for _, v in value do
        if table.find(options, v) then
            table.insert(out, v)
        end
    end
    return out
end

local function sameSelection(a, b)
    if #a ~= #b then
        return false
    end
    for _, v in a do
        if not table.find(b, v) then
            return false
        end
    end
    return true
end

function Dropdown.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local options = properties.options or properties.Options or {}
    local multiSelect = properties.multiSelect or properties.MultiSelect or properties.MultipleOptions or false

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or "Dropdown",
        icon = properties.icon or properties.Icon,
        description = properties.description or properties.Description,
        forgetState = properties.forgetState or properties.ForgetState or tab.forgetState, -- dont save config for this element if true.

        flag = properties.flag
            or properties.Flag
            or (
                not (properties.forgetState or properties.ForgetState or tab.forgetState)
                    and functions.deriveFlagFromName(properties.name or properties.Name or "Dropdown")
                or nil
            ),

        callback = properties.callback or properties.Callback or function() end,

        options = dedupStrings(options),
        multiSelect = multiSelect,
        placeholderText = locale.resolve(properties.placeholder or properties.Placeholder or "None"),
        value = normalizeValue(
            properties.value or properties.Value or properties.currentOption or properties.CurrentOption,
            multiSelect
        ),

        _isOpen = false,
        _optionFrames = {},
    }, Dropdown)

    -- Remember the full intent so a selection survives options that only load later (via
    -- Refresh), while self.value stays narrowed to options that currently exist.
    self._desiredValue = self.value
    self.value = intersectWithOptions(self.value, self.options)

    -- Register as a saveable control if flagged
    self.window:_registerControl(self)

    -- Outer wrapper: transparent, just holds the two cards and animates its height
    -- open <-> closed. It does not clip: a UIStroke is drawn outside the frame it belongs to,
    -- and both cards fill this exactly, so clipping here took the border off both of them. The
    -- options card cannot overflow anyway, since its height is this one's less the header.
    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 41),
        BorderSizePixel = 0,
        Name = self.name,
        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    })

    -- Header card: the always-visible pill (icon + title + selected value + chevron)
    self.top = self.window:Create("Frame", {
        Size = UDim2.new(1, 0, 0, 41),
        Position = UDim2.fromScale(0, 0),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        ZIndex = 1,

        Parent = self.main,
    }, { BackgroundTransparency = "ElementTransparency" })

    self.stroke = self.window:StyleElementPanel(self.top)
    self.hoverOverlay = self.window:CreateHoverOverlay(self.top)
    self.flashTarget = self.top -- main is a transparent wrapper, so the error-flash tints the pill

    self.container = self.window:Create("Frame", {
        BorderSizePixel = 0,

        Parent = self.top,
        Size = UDim2.new(0, 170, 0, 16),
        Position = UDim2.new(0, 20, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 5,
    })

    self.containerLayout = self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,

        Parent = self.container,
    })

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,

            -- Animation
            ImageTransparency = 1, -- In = 0

            ZIndex = 5,
            Parent = self.container,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = self.window:Create("TextLabel", {
        -- Configurables
        Text = locale.t(self.name),

        Size = UDim2.fromOffset(150, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        AutomaticSize = Enum.AutomaticSize.X,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 1,

        -- Animation
        TextTransparency = 1, -- In = 0

        ZIndex = 5,
        Parent = self.container,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self.selectedLabel = self.window:Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -41, 0.5, 0),
        Size = UDim2.fromOffset(168, 15),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextWrapped = true,

        -- Animation
        TextTransparency = 1, -- In = 0.5

        ZIndex = 5,
        Parent = self.top,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self.chevron = self.window:Create("ImageLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -18, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Image = "rbxassetid://" .. tostring(chevronIcon),
        Rotation = 180,

        -- Animation
        ImageTransparency = 1, -- In = 0.5

        ZIndex = 5,
        Parent = self.top,
    }, { ImageColor3 = "ContentColor" })

    -- Covers only the header, so option clicks in the open panel below don't hit it.
    self.interact = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 41),
        Position = UDim2.fromScale(0, 0),
        BorderSizePixel = 0,
        Text = "",
        TextTransparency = 1,
        ZIndex = 10,
        AutoButtonColor = false,

        Parent = self.main,
    })

    -- Options card: a second (full-width) pill below the header, revealed as the wrapper
    -- grows. Anchored to the wrapper's bottom (top edge sits 6px under the header) so the
    -- clip hides it while collapsed.
    -- Clips its own contents rather than being clipped: collapsed it is zero height, so the
    -- search bar and the list have to be cut off here, and its own border is left to draw
    -- outside it the way every other element's does.
    self.panel = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, 0, 1, 0),
        Size = UDim2.new(1, 0, 1, -(headerHeight + headerGap)),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        ZIndex = 1,

        BackgroundTransparency = 1, -- Open = ElementTransparency

        Parent = self.main,
    })

    self.panelStroke = self.window:StyleElementPanel(self.panel)

    -- The card stacks the search bar over the list. The search bar is always present in
    -- the layout (it just grows/shrinks), so the gap under it is stable; the list is a
    -- flex-fill item, so it takes whatever height is left and slides down as search grows.
    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.panel,
    })

    self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, cardPaddingTop),
        PaddingBottom = UDim.new(0, cardPaddingBottom),

        Parent = self.panel,
    })

    self:_buildSearch()
    self:_buildActions()

    self.list = self.window:Create("ScrollingFrame", {
        Active = true,
        Size = UDim2.new(1, 0, 0, 0), -- height comes from the UIFlexItem below
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        ScrollBarImageColor3 = Color3.fromRGB(240, 240, 240),
        ScrollBarThickness = 3,
        ScrollBarImageTransparency = 1, -- scrollbar kept fully transparent
        ScrollingDirection = Enum.ScrollingDirection.Y,
        LayoutOrder = 3,
        ZIndex = 1,

        Parent = self.panel,
    })

    self.window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Fill,

        Parent = self.list,
    })

    self.window:ConnectFor(self, self.list:GetPropertyChangedSignal("CanvasPosition"), function()
        self:_syncFade()
    end)
    self.window:ConnectFor(self, self.list:GetPropertyChangedSignal("AbsoluteCanvasSize"), function()
        self:_syncFade()
    end)

    self.listLayout = self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,

        Parent = self.list,
    })

    -- top as well as bottom: the list clips, and a row's stroke is drawn outside it, so the
    -- first row lost its top border to the clip edge without this
    self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, listPadding),
        PaddingBottom = UDim.new(0, listPadding),

        Parent = self.list,
    })

    -- Nothing on screen says a list is longer than the card, since the scrollbar is kept out of
    -- the way. This is the edge of the list going soft while there is more of it below, which
    -- reads as more to come rather than as a list that simply ends there.
    --
    -- It hangs off the wrapper rather than the card, because the card lays its children out with
    -- a UIListLayout and that lays out every visible child it has, wherever it has been put. On
    -- the card this took a slot in the flow instead of floating over the list: it pushed the
    -- search bar and every row down by its own height and forced the last row past the card's
    -- edge, and only once there was something to scroll, which is when it first became visible.
    self.listFade = self.window:Create("Frame", {
        Name = "Fade",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -cardPaddingBottom),
        Size = UDim2.new(1, -12, 0, fadeHeight),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ZIndex = 3,
        Visible = false,

        Parent = self.main,
    }, { BackgroundColor3 = { "ElementGradient", firstColorOf } })

    self.window:Create("UIGradient", {
        Rotation = 270,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),

        Parent = self.listFade,
    })

    -- Said when a search matches nothing. Without it the card is a search box over an empty
    -- space, which reads as broken rather than as no matches.
    self.emptyLabel = self.window:Create("TextLabel", {
        Name = "Empty",
        Size = UDim2.new(1, -12, 0, optionHeight),
        BackgroundTransparency = 1,
        Text = locale.t("No matches"),
        TextSize = 14,
        TextTransparency = 0.55,
        Visible = false,
        LayoutOrder = 1,

        Parent = self.list,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    local function isOptionSelected(name)
        return table.find(self.value, name) ~= nil
    end

    local function renderOptionState(data, animate)
        local selected = isOptionSelected(data.name)
        local bgT = if self._isOpen then (selected and 0.9 or 0.95) else 1
        local titleT = if self._isOpen then (selected and 0 or 0.3) else 1
        -- Selected shows a bright check; unselected shows a faint dot
        local iconT = if self._isOpen then (selected and 0 or 0.7) else 1
        local strokeT = if self._isOpen then (selected and 0.85 or 0.93) else 1

        image.assign(data.checkIcon, "Image", if selected then checkIcon else dotIcon)

        if animate then
            local info = TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
            variables.tweenService:Create(data.frame, info, { BackgroundTransparency = bgT }):Play()
            variables.tweenService:Create(data.title, info, { TextTransparency = titleT }):Play()
            variables.tweenService:Create(data.checkIcon, info, { ImageTransparency = iconT }):Play()
            variables.tweenService:Create(data.stroke, info, { Transparency = strokeT }):Play()
        else
            data.frame.BackgroundTransparency = bgT
            data.title.TextTransparency = titleT
            data.checkIcon.ImageTransparency = iconT
            data.stroke.Transparency = strokeT
        end
    end

    local function updateSelectedLabel()
        if self.multiSelect then
            local n = #self.value
            if n == 0 then
                self.selectedLabel.Text = self.placeholderText
            elseif n == 1 then
                self.selectedLabel.Text = self.value[1]
            else
                self.selectedLabel.Text = locale.resolve("Various")
            end
        else
            self.selectedLabel.Text = self.value[1] or self.placeholderText
        end
    end

    self._renderOptionState = renderOptionState
    self._updateSelectedLabel = updateSelectedLabel

    local function buildOption(optionName)
        local frame = self.window:Create("Frame", {
            Size = UDim2.new(1, -12, 0, optionHeight),
            BorderSizePixel = 0,

            BackgroundTransparency = 1,

            Parent = self.list,
        }, { BackgroundColor3 = "DropdownHighlight" })

        -- Radius is driven by adjacency in _updateCorners (7 flat / 12 rounded)
        local corner = self.window:Create("UICorner", {
            CornerRadius = flatRadius,
            Parent = frame,
        })

        -- Subtle stroke, only shown on the selected option
        local optionStroke = self.window:Create("UIStroke", {
            Color = Color3.fromRGB(255, 255, 255),
            Transparency = 1, -- selected = 0.85
            Parent = frame,
        })

        local interact = self.window:Create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            TextTransparency = 1,
            ZIndex = 50,
            Parent = frame,
        })

        local container = self.window:Create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 14, 0.5, 0),
            Size = UDim2.fromOffset(170, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ZIndex = 5,
            Parent = frame,
        })

        self.window:Create("UIListLayout", {
            Padding = UDim.new(0, 5),
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = container,
        })

        local checkIcon = self.window:Create("ImageLabel", {
            Image = "rbxassetid://" .. tostring(checkIcon),
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ImageTransparency = 1,
            ZIndex = 5,
            Parent = container,
        }, { ImageColor3 = "ContentColor" })

        local title = self.window:Create("TextLabel", {
            Text = optionName,
            Size = UDim2.fromOffset(170, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            LayoutOrder = 1,
            TextTransparency = 1,
            ZIndex = 5,
            Parent = container,
        }, { TextColor3 = "ContentColor", FontFace = "Font" })

        local data = {
            name = optionName,
            frame = frame,
            interact = interact,
            title = title,
            checkIcon = checkIcon,
            container = container,
            stroke = optionStroke,
            corner = corner,
            -- tracked per option so a rebuild tears them down with the frame
            connections = {},
        }

        table.insert(
            data.connections,
            self.window:ConnectFor(self, frame.MouseEnter, function()
                if not self._isOpen or not self.window:_interactive() then
                    return
                end
                if isOptionSelected(optionName) then
                    return
                end
                variables.tweenService
                    :Create(
                        frame,
                        TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                        { BackgroundTransparency = 0.9 }
                    )
                    :Play()
                variables.tweenService
                    :Create(
                        title,
                        TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                        { TextTransparency = 0.15 }
                    )
                    :Play()
            end)
        )

        table.insert(
            data.connections,
            self.window:ConnectFor(self, frame.MouseLeave, function()
                if not self._isOpen then
                    return
                end
                if isOptionSelected(optionName) then
                    return
                end
                variables.tweenService
                    :Create(
                        frame,
                        TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                        { BackgroundTransparency = 0.95 }
                    )
                    :Play()
                variables.tweenService
                    :Create(
                        title,
                        TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                        { TextTransparency = 0.3 }
                    )
                    :Play()
            end)
        )

        table.insert(
            data.connections,
            self.window:ConnectFor(self, interact.MouseButton1Click, function()
                -- options stay visible through the close tween; a click mid-fade must not land
                if not self._isOpen then
                    return
                end
                hapticEngine.click()
                local sel = isOptionSelected(optionName)

                if not self.multiSelect then
                    if sel then
                        self:_close()
                        return
                    end
                    table.clear(self.value)
                    table.insert(self.value, optionName)
                else
                    if sel then
                        local idx = table.find(self.value, optionName)
                        if idx then
                            table.remove(self.value, idx)
                        end
                    else
                        table.insert(self.value, optionName)
                    end
                end

                -- the visible selection is now the player's intent; a later Refresh must build
                -- on this, not revert to whatever was restored before they touched it
                self._desiredValue = table.clone(self.value)

                for _, d in self._optionFrames do
                    renderOptionState(d, true)
                end

                updateSelectedLabel()

                self.window:_runGuarded(self, self.callback, self:_callbackValue())
                self.window:_persist(self)

                if not self.multiSelect then
                    task.wait(0.1)
                    self:_close()
                end
            end)
        )

        return data
    end

    self._buildOption = buildOption

    for _, opt in self.options do
        local data = buildOption(opt)
        table.insert(self._optionFrames, data)
    end

    updateSelectedLabel()
    self:_updateCorners()

    -- Function
    self.window:ConnectFor(self, self.interact.MouseButton1Click, function()
        hapticEngine.click()
        if self._isOpen then
            self:_close()
        else
            self:_open()
        end
    end)

    -- Hover feedback via the overlay + title only. The card uses a gradient stroke (white
    -- base tinted by the gradient), so tweening stroke.Color here would fight the gradient.
    self.window:ConnectFor(self, self.main.MouseEnter, function()
        if self._isOpen or not self.window:_interactive() then
            return
        end
        variables.tweenService
            :Create(
                self.title,
                TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { TextColor3 = self.window.theme.ElementTextHoverColor }
            )
            :Play()
        variables.tweenService
            :Create(
                self.hoverOverlay,
                TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { BackgroundTransparency = 0.97 }
            )
            :Play()
    end)

    self.window:ConnectFor(self, self.main.MouseLeave, function()
        variables.tweenService
            :Create(
                self.title,
                TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { TextColor3 = self.window.theme.ContentColor }
            )
            :Play()
        variables.tweenService
            :Create(
                self.hoverOverlay,
                TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { BackgroundTransparency = 1 }
            )
            :Play()
    end)

    if self.description then
        self.descriptor = require(script.Parent.descriptor).new(self.tab, { description = self.description })
    end

    return self
end

-- Search bar: collapsed it's just the icon (centred, no bar); tapping expands it into a
-- full field. It's always in the card's layout - only its height/fills animate - so the
-- list below just flexes down as it grows.
-- what the dev's callback receives. multiSelect hands out a copy: the live table is our
-- selection state, and a dev who keeps or mutates it would corrupt the dropdown.
function Dropdown:_callbackValue()
    if self.multiSelect then
        return table.clone(self.value)
    end
    return self.value[1]
end

function Dropdown:_buildSearch()
    self._searchOpen = false

    self.searchbar = self.window:Create("Frame", {
        Name = "Search",
        Size = UDim2.new(1, -12, 0, searchCollapsedHeight),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1, -- expanded = 0.92
        LayoutOrder = 1,
        ClipsDescendants = false,
        ZIndex = 1,

        Parent = self.panel,
    })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(0, 12),
        Parent = self.searchbar,
    })

    self.searchStroke = self.window:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 1, -- expanded = 0.86
        Parent = self.searchbar,
    })

    self.searchShadow = self.window:CreateGlow(self.searchbar, Color3.fromRGB(255, 255, 255), 20, 1) -- expanded = 0.92

    -- Full-bar tap target: expands the bar while it's collapsed. Kept above the option
    -- hit-targets (ZIndex 50) so taps here never bleed through to an option under them.
    self.searchToggle = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        TextTransparency = 1,
        ZIndex = 51,
        Parent = self.searchbar,
    })

    self.searchInput = self.window:Create("TextBox", {
        Text = "",
        PlaceholderText = locale.t("Search..."),
        Size = UDim2.new(1, -58, 0, 16),
        Position = UDim2.new(0, 44, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        TextEditable = false, -- enabled on expand
        Interactable = false, -- collapsed: let taps fall through to the toggle
        ZIndex = 52,

        TextTransparency = 1, -- expanded = 0.3

        Parent = self.searchbar,
    }, { TextColor3 = "ContentColor", FontFace = "Font", PlaceholderColor3 = "PlaceholderColor" })

    self.searchIcon = self.window:Create("ImageButton", {
        Image = "rbxassetid://" .. tostring(searchIconAsset),
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.new(0, 24, 0.5, 0), -- left-aligned (centre at x=24, edge at 14)
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        AutoButtonColor = false,
        ZIndex = 53,

        ImageTransparency = 1, -- In = 0.5

        Parent = self.searchbar,
    }, { ImageColor3 = "ContentColor" })

    self.window:ConnectFor(self, self.searchToggle.MouseButton1Click, function()
        if not self._searchOpen then
            self:_expandSearch()
        end
    end)
    self.window:ConnectFor(self, self.searchIcon.MouseButton1Click, function()
        if self._searchOpen then
            self:_collapseSearch()
        else
            self:_expandSearch()
        end
    end)
    self.window:ConnectFor(self, self.searchInput:GetPropertyChangedSignal("Text"), function()
        self:_applyFilter(self.searchInput.Text)
    end)
    self.window:ConnectFor(self, self.searchInput.FocusLost, function()
        if self.searchInput.Text == "" then
            self:_collapseSearch()
        end
    end)
end

function Dropdown:_expandSearch()
    if self._searchOpen then
        return
    end
    self._searchOpen = true
    self.searchInput.TextEditable = true
    self.searchInput.Interactable = true

    variables.tweenService
        :Create(
            self.searchbar,
            searchTween,
            { Size = UDim2.new(1, -12, 0, searchExpandedHeight), BackgroundTransparency = 0.92 }
        )
        :Play()
    variables.tweenService:Create(self.searchStroke, searchTween, { Transparency = 0.86 }):Play()
    variables.tweenService:Create(self.searchShadow, searchTween, { Transparency = 0.92 }):Play()
    variables.tweenService:Create(self.searchInput, searchTween, { TextTransparency = 0.3 }):Play()

    self:_resizeToOptions() -- the bar is taller now, so the card owes it the difference
    self.searchInput:CaptureFocus()
end

function Dropdown:_collapseSearch()
    if not self._searchOpen then
        return
    end
    self._searchOpen = false
    self.searchInput.TextEditable = false
    self.searchInput.Interactable = false
    self.searchInput:ReleaseFocus()
    self.searchInput.Text = "" -- fires the filter, showing everything again

    variables.tweenService
        :Create(
            self.searchbar,
            searchTween,
            { Size = UDim2.new(1, -12, 0, searchCollapsedHeight), BackgroundTransparency = 1 }
        )
        :Play()
    variables.tweenService:Create(self.searchStroke, searchTween, { Transparency = 1 }):Play()
    variables.tweenService:Create(self.searchShadow, searchTween, { Transparency = 1 }):Play()
    variables.tweenService:Create(self.searchInput, searchTween, { TextTransparency = 1 }):Play()

    self:_resizeToOptions()
end

function Dropdown:_applyFilter(query)
    query = string.lower(query or "")
    local shown = 0
    for _, data in self._optionFrames do
        local visible = query == "" or string.find(string.lower(data.name), query, 1, true) ~= nil
        data.frame.Visible = visible
        if visible then
            shown += 1
        end
    end

    self.emptyLabel.Visible = shown == 0
    self:_updateCorners()
    self:_resizeToOptions()
    self:_syncFade()
end

-- Show the soft edge only while there is list left underneath it. Measured rather than assumed,
-- because a filter can take a list that was scrolling down to two rows that are not.
function Dropdown:_syncFade()
    if not self.listFade then
        return
    end

    -- a list that has not been laid out yet has nothing to measure, and nothing to hide either
    local canvasSize, windowSize, at =
        self.list.AbsoluteCanvasSize, self.list.AbsoluteWindowSize, self.list.CanvasPosition
    if not canvasSize or not windowSize or not at then
        return
    end

    local more = self._isOpen and windowSize.Y > 0 and canvasSize.Y - (at.Y + windowSize.Y) > 1

    self.listFade.Visible = more == true
    variables.tweenService:Create(self.listFade, fadeTween, { BackgroundTransparency = if more then 0 else 1 }):Play()
end

-- Every option the search is currently letting through, which is what a bulk action applies to:
-- selecting all of a filtered list should not quietly take the ones it is hiding as well.
function Dropdown:_visibleOptions(): { string }
    local names = {}
    for _, data in self._optionFrames do
        if data.frame.Visible then
            table.insert(names, data.name)
        end
    end
    return names
end

function Dropdown:_buildActions()
    if not self.multiSelect then
        return -- one choice at a time has nothing to select all of
    end

    self.actions = self.window:Create("Frame", {
        Name = "Actions",
        Size = UDim2.new(1, -12, 0, actionsHeight),
        BackgroundTransparency = 1,
        LayoutOrder = 2,

        Parent = self.panel,
    })

    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 12),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.actions,
    })

    local function action(label: string, order: number, apply: () -> ())
        local button = self.window:Create("TextButton", {
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, actionsHeight),
            BackgroundTransparency = 1,
            Text = locale.t(label),
            TextSize = 13,
            TextTransparency = 0.45, -- hovered = 0.15
            LayoutOrder = order,

            Parent = self.actions,
        }, { TextColor3 = "ContentColor", FontFace = "Font" })

        self.window:ConnectFor(self, button.MouseEnter, function()
            variables.tweenService:Create(button, fadeTween, { TextTransparency = 0.15 }):Play()
        end)
        self.window:ConnectFor(self, button.MouseLeave, function()
            variables.tweenService:Create(button, fadeTween, { TextTransparency = 0.45 }):Play()
        end)
        self.window:ConnectFor(self, button.MouseButton1Click, function()
            apply()
            self:_afterBulkChange()
        end)

        return button
    end

    action("Select all", 1, function()
        self.value = self:_visibleOptions()
    end)
    action("Clear", 2, function()
        self.value = {}
    end)
end

-- The tail every bulk action shares: repaint the rows, say what is selected, tell the dev, save.
function Dropdown:_afterBulkChange()
    for _, data in self._optionFrames do
        self._renderOptionState(data, true)
    end
    self:_updateSelectedLabel()
    self:_updateCorners()
    self.window:_runGuarded(self, self.callback, self:_callbackValue())
    self.window:_persist(self)
    hapticEngine.click()
end

-- match the panel to whats visible. only while open: closed height is the header alone.
function Dropdown:_resizeToOptions()
    if not self._isOpen then
        return
    end
    variables.tweenService:Create(self.main, searchTween, { Size = UDim2.new(1, -20, 0, self:_openHeight()) }):Play()
end

-- Per-corner rounding: an option's top corners round off only when nothing sits above it,
-- and its bottom corners only when nothing sits below - so a run of options reads as one
-- grouped block with rounded outer edges and sharp seams (a lone option is fully rounded).
-- Runs over the currently VISIBLE options, so it re-groups correctly while searching.
function Dropdown:_updateCorners()
    local visible = {}
    for _, data in self._optionFrames do
        if data.frame.Visible then
            table.insert(visible, data)
        end
    end

    for i, data in visible do
        local topR = if i == 1 then roundRadius else flatRadius
        local botR = if i == #visible then roundRadius else flatRadius
        data.corner.TopLeftRadius = topR
        data.corner.TopRightRadius = topR
        data.corner.BottomLeftRadius = botR
        data.corner.BottomRightRadius = botR
    end
end

-- Open height sized to the options (header + search + paddings + rows), capped so long lists
-- scroll instead of running off the window. Short lists open just tall enough, no dead space.
-- sized from the options actually on screen, so a search filter (or an Add/Remove while
-- open) grows and shrinks the panel to fit rather than leaving dead space
function Dropdown:_openHeight()
    local n = 0
    for _, data in self._optionFrames do
        if data.frame.Visible then
            n += 1
        end
    end
    local function listHeight(count: number): number
        return count * optionHeight + math.max(0, count - 1) * optionGap + listPadding * 2
    end

    -- a search that matches nothing still has a line to say so, so the card keeps one row of room
    local rows = math.max(n, 1)

    -- the search bar grows when it takes focus, and the card has to grow with it. It did not, so
    -- opening the search pushed the list down by the difference and the last row went over the
    -- card's own edge, where the clip took it.
    local searchHeight = if self._searchOpen then searchExpandedHeight else searchCollapsedHeight
    local overhead = headerHeight
        + headerGap
        + cardPadding
        + searchHeight
        + optionGap
        + (if self.actions then actionsHeight + optionGap else 0)

    return math.min(overhead + listHeight(maxVisibleOptions), overhead + listHeight(rows))
end

function Dropdown:_open()
    if self._isOpen then
        return
    end
    self._isOpen = true

    if self._outsideClickConn then
        self.window:Disconnect(self._outsideClickConn)
    end
    self._outsideClickConn = self.window:Connect(variables.userInputService.InputBegan, function(input)
        if
            input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end

        local pos = input.Position
        local mainPos = self.main.AbsolutePosition
        local mainSize = self.main.AbsoluteSize
        if
            pos.X < mainPos.X
            or pos.X > mainPos.X + mainSize.X
            or pos.Y < mainPos.Y
            or pos.Y > mainPos.Y + mainSize.Y
        then
            self:_close()
        end
    end)

    variables.tweenService
        :Create(
            self.main,
            TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
            { Size = UDim2.new(1, -20, 0, self:_openHeight()) }
        )
        :Play()
    variables.tweenService
        :Create(
            self.chevron,
            TweenInfo.new(0.7, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
            { Rotation = 0 }
        )
        :Play()
    variables.tweenService
        :Create(
            self.panel,
            TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { BackgroundTransparency = self.window.theme.ElementTransparency or 0 }
        )
        :Play()
    variables.tweenService
        :Create(
            self.panelStroke,
            TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { Transparency = self.window.theme.ElementStrokeTransparency }
        )
        :Play()
    variables.tweenService
        :Create(
            self.searchIcon,
            TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { ImageTransparency = 0.5 }
        )
        :Play()

    for _, data in self._optionFrames do
        self._renderOptionState(data, true)
    end

    self:_syncFade()
    self:_bringIntoView()
end

-- A card low down a page opens into whatever is below the fold, and the options it just showed
-- are off screen. Rather than flip it above the header, which only moves the problem to the top
-- edge, the page comes to it: scroll just far enough that the open card ends inside the view.
function Dropdown:_bringIntoView()
    local page = self.tab and self.tab.tabPage
    if not page then
        return
    end

    -- a page that has not been laid out has no view to fit anything into yet
    local view, at, pageAt, cardAt =
        page.AbsoluteWindowSize, page.CanvasPosition, page.AbsolutePosition, self.main.AbsolutePosition
    if not view or not at or not pageAt or not cardAt or view.Y <= 0 then
        return
    end

    -- measured against the canvas, not the screen, so it does not matter where the window is
    local top = cardAt.Y - pageAt.Y + at.Y
    local bottom = top + self:_openHeight()
    local overflow = bottom - (at.Y + view.Y)
    if overflow <= 0 then
        return -- it already ends inside the view
    end

    -- never past the card's own top: pushing it off the top edge to fit the bottom is not a fix
    local target = math.min(at.Y + overflow + 8, top)
    variables.tweenService
        :Create(page, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            CanvasPosition = Vector2.new(at.X, target),
        })
        :Play()
end

function Dropdown:_close()
    if not self._isOpen then
        return
    end
    self._isOpen = false

    if self._outsideClickConn then
        self.window:Disconnect(self._outsideClickConn)
        self._outsideClickConn = nil
    end

    self:_collapseSearch()
    self:_syncFade()

    variables.tweenService
        :Create(
            self.chevron,
            TweenInfo.new(0.7, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
            { Rotation = 180 }
        )
        :Play()
    variables.tweenService
        :Create(
            self.panel,
            TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 }
        )
        :Play()
    variables.tweenService
        :Create(
            self.panelStroke,
            TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { Transparency = 1 }
        )
        :Play()
    variables.tweenService
        :Create(
            self.searchIcon,
            TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { ImageTransparency = 1 }
        )
        :Play()

    for _, data in self._optionFrames do
        self._renderOptionState(data, true)
    end

    variables.tweenService
        :Create(
            self.main,
            TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
            { Size = UDim2.new(1, -20, 0, 41) }
        )
        :Play()
end

-- tear an option down through the window registries, so rebuild churn doesnt leak tracked
-- instances (which would slow ChangeTheme forever) or dead connections
function Dropdown:_destroyOption(data)
    if data.connections then
        for _, connection in data.connections do
            local idx = table.find(self.connections, connection)
            if idx then
                table.remove(self.connections, idx)
            end
            self.window:Disconnect(connection)
        end
        data.connections = nil
    end
    self.window:DestroySubtree(data.frame)
end

-- re-derive the visible selection from the full intent: an option that loads now (or
-- comes back) re-selects, one that's genuinely gone drops out. self.value only ever holds
-- real options, so the saved config never carries a stale selection across sessions.
function Dropdown:_deriveSelection()
    local previous = self.value
    self.value = intersectWithOptions(self._desiredValue or self.value, self.options)
    return not sameSelection(self.value, previous)
end

function Dropdown:Refresh(newOptions)
    self.options = dedupStrings(newOptions or {})

    for _, data in self._optionFrames do
        self:_destroyOption(data)
    end
    table.clear(self._optionFrames)

    local selectionChanged = self:_deriveSelection()

    for _, opt in self.options do
        local data = self._buildOption(opt)
        table.insert(self._optionFrames, data)
        -- fresh frames default to the closed look, so paint the open state if the
        -- panel is already open (otherwise they'd sit blank until hovered)
        if self._isOpen then
            self._renderOptionState(data, false)
        end
    end

    self._updateSelectedLabel()
    -- reconcile with any active search (also refreshes corners); empty query shows all
    self:_applyFilter(if self._searchOpen then self.searchInput.Text else "")

    -- the visible selection changed (options arrived or dropped): tell the dev and save it
    if selectionChanged then
        self.window:_runGuarded(self, self.callback, self:_callbackValue())
        self.window:_persist(self)
    end
end

function Dropdown:Add(option)
    if typeof(option) ~= "string" or option == "" then
        return
    end
    if table.find(self.options, option) then
        return
    end

    table.insert(self.options, option)
    local data = self._buildOption(option)
    table.insert(self._optionFrames, data)

    -- the new option may satisfy pending intent from an earlier Set or config load
    local selectionChanged = self:_deriveSelection()

    if self._isOpen then
        self._renderOptionState(data, true)
    end

    -- reconcile with any active search rather than showing an option the query excludes,
    -- and resize for the new row (also refreshes corners)
    self:_applyFilter(if self._searchOpen then self.searchInput.Text else "")

    -- the visible selection changed (the pending option arrived): tell the dev and save it
    if selectionChanged then
        self._updateSelectedLabel()
        self.window:_runGuarded(self, self.callback, self:_callbackValue())
        self.window:_persist(self)
    end
end

function Dropdown:Remove(option)
    local idx = table.find(self.options, option)
    if not idx then
        return
    end

    table.remove(self.options, idx)

    for i, data in self._optionFrames do
        if data.name == option then
            self:_destroyOption(data)
            table.remove(self._optionFrames, i)
            break
        end
    end

    -- drop the removed option from the pending intent too, but leave intent for options
    -- that just aren't present right now so they can still restore later
    if self._desiredValue then
        local desiredIdx = table.find(self._desiredValue, option)
        if desiredIdx then
            table.remove(self._desiredValue, desiredIdx)
        end
    end

    local valueIdx = table.find(self.value, option)
    if valueIdx then
        table.remove(self.value, valueIdx)
        self._updateSelectedLabel()
        -- removing a selected option changes the selection; surface and save that
        self.window:_runGuarded(self, self.callback, self:_callbackValue())
        self.window:_persist(self)
    end

    -- one row shorter; resize and re-corner around whats left
    self:_applyFilter(if self._searchOpen then self.searchInput.Text else "")
end

function Dropdown:Set(value, skipCallback)
    local newValue = normalizeValue(value, self.multiSelect)
    -- keep the full request so options that arrive later can restore it (see Refresh)
    self._desiredValue = newValue
    self.value = intersectWithOptions(newValue, self.options)

    for _, data in self._optionFrames do
        self._renderOptionState(data, true)
    end
    self._updateSelectedLabel()

    if not skipCallback then
        self.window:_runGuarded(self, self.callback, self:_callbackValue())
        self.window:_persist(self) -- skipCallback means apply quietly, so dont autosave either
    end
end

function Dropdown:_setShown(shown, animate)
    -- Custom reveal: main is a transparent wrapper, so reveal the header card (self.top)
    -- rather than main. The options card fades in on open, not here.
    local w = self.window
    w:_reveal(self.stroke, { Transparency = if shown then w.theme.ElementStrokeTransparency else 1 }, animate)
    w:_reveal(self.title, { TextTransparency = if shown then 0 else 1 }, animate)
    w:_reveal(self.top, { BackgroundTransparency = if shown then (w.theme.ElementTransparency or 0) else 1 }, animate)
    if self.iconLabel then
        w:_reveal(self.iconLabel, { ImageTransparency = if shown then 0 else 1 }, animate)
    end
    if self.descriptor then
        w:_reveal(self.descriptor.titleLabel, { TextTransparency = if shown then 0.7 else 1 }, animate)
    end
    w:_reveal(self.selectedLabel, { TextTransparency = if shown then 0.5 else 1 }, animate)
    w:_reveal(self.chevron, { ImageTransparency = if shown then 0.5 else 1 }, animate)

    -- if the window hides while we're open, collapse so we dont reopen mid-air
    if not shown and self._isOpen then
        self:_close()
    end
end

function Dropdown:MoveTo(index)
    self.tab:_moveElement(self, index)
end

function Dropdown:MoveToTop()
    self.tab:_moveElement(self, 1)
end

function Dropdown:MoveToBottom()
    self.tab:_moveElement(self, #self.tab.elements)
end

function Dropdown:MoveUp()
    local idx = table.find(self.tab.elements, self)
    if idx then
        self.tab:_moveElement(self, idx - 1)
    end
end

function Dropdown:MoveDown()
    local idx = table.find(self.tab.elements, self)
    if idx then
        self.tab:_moveElement(self, idx + 1)
    end
end

return Dropdown
