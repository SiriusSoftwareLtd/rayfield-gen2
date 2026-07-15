-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local Statistic = {}
Statistic.__index = Statistic
Statistic.__type = "Statistic"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local functions = require(utility.functions)
local odometer = require(utility.odometer)
local moveable = require(utility.moveable)
local constants = require(utility.constants)
local locale = require(utility.locale)
local log = require(utility.log)

-- Accent gradients per direction (fill drives the card + glow, stroke is the brighter edge)
local accents = constants.statAccents

local accentTransparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.85),
    NumberSequenceKeypoint.new(1, 0),
})

local compactHeight = 41

local accentTweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Exponential)

-- UIShadow glows take one colour, so the halo uses the brightest stop of the direction's fill.
local function glowColor(accent)
    return accent.fill.Keypoints[1].Value
end

local function formatPct(pct)
    if pct > 0 then
        return string.format("+%.1f%%", pct)
    elseif pct < 0 then
        return string.format("%.1f%%", pct)
    else
        return "0%"
    end
end

local function formatValue(value)
    if typeof(value) ~= "number" then
        return tostring(value)
    end
    local s = tostring(math.floor(math.abs(value)))
    local result = s:reverse():gsub("%d%d%d", "%0,"):reverse()
    if result:sub(1, 1) == "," then
        result = result:sub(2)
    end
    return if value < 0 then "-" .. result else result
end

local function formatChange(delta)
    if delta > 0 then
        return "+" .. formatValue(math.round(delta))
    elseif delta < 0 then
        return formatValue(math.round(delta))
    else
        return "0"
    end
end

function Statistic.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or "Statistic",
        icon = properties.icon or properties.Icon,
        description = properties.description or properties.Description,

        value = if (properties.value or properties.Value) ~= nil then (properties.value or properties.Value) else 0,
        -- did we start with a real value, or is the displayed number just a placeholder?
        -- the first Set on a placeholder establishes the baseline instead of showing a change
        _hasValue = (properties.value or properties.Value) ~= nil,

        numberEasing = if (properties.numberEasing ~= nil)
            then properties.numberEasing
            elseif properties.NumberEasing ~= nil then properties.NumberEasing
            else true,

        changeMode = properties.changeMode or properties.ChangeMode or "percentage", -- "percentage" | "absolute"
        changeBaseline = properties.changeBaseline or properties.ChangeBaseline or "previous",

        prefix = properties.prefix or properties.Prefix or "",
        suffix = properties.suffix or properties.Suffix or "",

        -- 41px single-readout card. config opt-in, forced on in a row. only room for
        -- one number, so `display` picks value or % change.
        compact = properties.compact or properties.Compact or tab.compact or false,
        display = (properties.display or properties.Display or "value"), -- "value" | "change"

        _initialValue = if (properties.value or properties.Value) ~= nil
            then (properties.value or properties.Value)
            else nil,
        _lastChange = 0,
    }, Statistic)

    if self.compact then
        self:_buildCompact()
    else
        self:_buildFull()
    end

    if self.description then
        if self.compact then
            log.warn(`Rayfield: a compact stat has no room for a description, ignoring it on '{self.name}'.`)
        else
            self.descriptor = require(script.Parent.descriptor).new(self.tab, { description = self.description })
        end
    end

    return self
end

-- full 90px card: title, value bottom-left, % change bottom-right
function Statistic:_buildFull()
    local window = self.window

    self.main = window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 90),
        BorderSizePixel = 0,
        Name = self.name,
        ZIndex = 5,

        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    }, { BackgroundColor3 = "StatBackground", BackgroundTransparency = "ElementTransparency" })

    window:Create("UICorner", {
        Parent = self.main,
    }, { CornerRadius = "ElementCornerRadius" })

    self.stroke = window:Create("UIStroke", {
        Transparency = 1, -- Animation In = 0
        Color = Color3.fromRGB(255, 255, 255),

        Parent = self.main,
    }, { Transparency = "ElementStrokeTransparency" })

    self.strokeGradient = window:Create("UIGradient", {
        Rotation = 2,
        Offset = Vector2.new(0, 0.5),
        Color = accents.neutral.stroke,
        Transparency = accentTransparency,

        Parent = self.stroke,
    })

    self.titleContainer = window:Create("Frame", {
        Size = UDim2.new(1, -40, 0, 32),
        Position = UDim2.fromOffset(20, 15),
        BorderSizePixel = 0,
        LayoutOrder = -1,
        BackgroundTransparency = 1,
        ZIndex = 5,

        Parent = self.main,
    })

    self.gradientContainer = window:Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0),
        BorderSizePixel = 0,
        BackgroundTransparency = 1, -- In 0
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        ZIndex = 5,

        Parent = self.main,
    })

    -- Soft accent halo behind the card. UIShadow (no image) is our glow standard; its colour
    -- follows the stat direction and it reveals from hidden to 0.7 like the rest of the card.
    self.glow = window:CreateGlow(self.main, glowColor(accents.neutral), 10, 1)

    self.title = window:Create("TextLabel", {
        Text = locale.t(self.name),

        Size = UDim2.fromOffset(300, 19),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 19,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 1,
        ZIndex = 10,

        TextTransparency = 1, -- In = 0

        Parent = self.titleContainer,
    }, { TextColor3 = "ContentColor", FontFace = "TitleFont" })

    self.mainGradient = window:Create("UIGradient", {
        Rotation = 2,
        Offset = Vector2.new(0, 0.5),
        Color = accents.neutral.fill,
        Transparency = accentTransparency,

        Parent = self.gradientContainer,
    })

    window:Create("UICorner", {
        Parent = self.gradientContainer,
    }, { CornerRadius = "ElementCornerRadius" })

    if self.icon then
        self.iconLabel = window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(32, 32),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ZIndex = 10,

            ImageTransparency = 1, -- In = 0

            Parent = self.titleContainer,
        }, { ImageColor3 = "ContentColor" })
    end

    self.containerLayout = window:Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.titleContainer,
    })

    -- Value (bottom-left) + change (bottom-right) odometer readouts.
    self.valueHost = window:Create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 20, 1, -15),
        Size = UDim2.fromOffset(200, 20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 10,

        Parent = self.main,
    })

    self.changeHost = window:Create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -20, 1, -15),
        Size = UDim2.fromOffset(200, 15),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 10,

        Parent = self.main,
    })

    self.valueOdo = odometer.new(window, self.valueHost, {
        textSize = 20,
        alignment = Enum.HorizontalAlignment.Left,
        transparency = 1, -- revealed to 0 on show
    })
    self.valueOdo:snap(self:_formatValue(self.value))

    self.changeOdo = odometer.new(window, self.changeHost, {
        textSize = 15,
        alignment = Enum.HorizontalAlignment.Right,
        transparency = 1,
    })
    self.changeOdo:snap(self:_formatChange(0))

    self._accentGradients = { self.strokeGradient, self.mainGradient }
end

-- compact 41px card: icon+title left, one readout right. accent gradient sits on
-- the card (the flexed child), not a separate overlay
function Statistic:_buildCompact()
    local window = self.window

    -- in a row it's content-sized and flexes; standalone it's full-width, no flex item
    local inRow = self.tab.compact or false

    self.main = window:Create("Frame", {
        Name = self.name,
        Size = if inRow then UDim2.fromOffset(0, compactHeight) else UDim2.new(1, -20, 0, compactHeight),
        AutomaticSize = if inRow then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
        ClipsDescendants = true,
        BorderSizePixel = 0,
        ZIndex = 5,

        BackgroundTransparency = 1, -- In = ElementTransparency

        Parent = self.tab.tabPage,
    }, { BackgroundColor3 = "StatBackground", BackgroundTransparency = "ElementTransparency" })

    window:Create("UICorner", {
        Parent = self.main,
    }, { CornerRadius = "ElementCornerRadius" })

    self.stroke = window:Create("UIStroke", {
        Transparency = 1, -- In = ElementStrokeTransparency
        Color = Color3.fromRGB(255, 255, 255),

        Parent = self.main,
    }, { Transparency = "ElementStrokeTransparency" })

    self.strokeGradient = window:Create("UIGradient", {
        Rotation = 2,
        Offset = Vector2.new(0, 0.5),
        Color = accents.neutral.stroke,
        Transparency = accentTransparency,

        Parent = self.stroke,
    })

    if inRow then
        window:Create("UIFlexItem", {
            FlexMode = Enum.UIFlexMode.Fill,
            Parent = self.main,
        })
    end

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,

        Parent = self.main,
    })

    -- accent surface + content: white base + accent gradient, title left, readout right
    self.card = window:Create("Frame", {
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, compactHeight),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 5,

        BackgroundTransparency = 1, -- In = 0

        Parent = self.main,
    })

    window:Create("UICorner", {
        Parent = self.card,
    }, { CornerRadius = "ElementCornerRadius" })

    self.mainGradient = window:Create("UIGradient", {
        Rotation = 2,
        Offset = Vector2.new(0, 0.5),
        Color = accents.neutral.fill,
        Transparency = accentTransparency,

        Parent = self.card,
    })

    window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 15),
        PaddingRight = UDim.new(0, 15),

        Parent = self.card,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
        Padding = UDim.new(0, 10),

        Parent = self.card,
    })

    -- icon + title (left)
    self.titleContainer = window:Create("Frame", {
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 0,
        ZIndex = 6,

        Parent = self.card,
    })

    -- title gives up room to the readout when tight
    window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Shrink,
        Parent = self.titleContainer,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.titleContainer,
    })

    if self.icon then
        self.iconLabel = window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(20, 20), -- smaller than the full 32
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            LayoutOrder = 0,
            ZIndex = 6,

            ImageTransparency = 1, -- In = 0

            Parent = self.titleContainer,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = window:Create("TextLabel", {
        Text = locale.t(self.name),
        Size = UDim2.fromOffset(0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        ZIndex = 6,

        TextTransparency = 1, -- In = 0

        Parent = self.titleContainer,
    }, { TextColor3 = "ContentColor", FontFace = "Font" }) -- Medium, like the other row elements

    -- grows to its text, shrinks + ellipsizes when tight
    window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Shrink,
        Parent = self.title,
    })

    -- single readout (right)
    self.readoutHost = window:Create("Frame", {
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 18),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        ZIndex = 6,

        Parent = self.card,
    })

    self.readoutOdo = odometer.new(window, self.readoutHost, {
        textSize = 17,
        alignment = Enum.HorizontalAlignment.Right,
        transparency = 1,
    })
    self.readoutOdo:snap(self.display == "change" and self:_formatChange(0) or self:_formatValue(self.value))

    self._accentGradients = { self.strokeGradient, self.mainGradient }
end

function Statistic:_setAccent(key, direction)
    local accent = accents[key]
    self.strokeGradient.Color = accent.stroke
    self.mainGradient.Color = accent.fill
    if self.glow then
        self.glow.Color = glowColor(accent)
    end

    -- Subtle rotation + offset shift to give the gradient a bit of life
    local rotation = if direction == 1 then 14 elseif direction == -1 then -10 else 2
    local offset = if direction == 1
        then Vector2.new(0.04, 0.5)
        elseif direction == -1 then Vector2.new(-0.04, 0.5)
        else Vector2.new(0, 0.5)
    for _, gradient in self._accentGradients do
        variables.tweenService:Create(gradient, accentTweenInfo, { Rotation = rotation, Offset = offset }):Play()
    end
end

function Statistic:_formatValue(value)
    return self.prefix .. formatValue(value) .. self.suffix
end

function Statistic:_formatChange(delta)
    if self.changeMode == "absolute" then
        return formatChange(delta)
    else
        return formatPct(delta)
    end
end

-- full: roll value + change independently
function Statistic:_updateFullReadouts(value, previousValue, targetChange, noChange, infinityText, hasNoHistory)
    if self.numberEasing and not hasNoHistory then
        self.valueOdo:to(self:_formatValue(value), value >= previousValue)
    else
        self.valueOdo:snap(self:_formatValue(value))
    end

    if infinityText then
        self.changeOdo:snap(infinityText)
        self._lastChange = 0
    elseif self.numberEasing and not noChange then
        self.changeOdo:to(self:_formatChange(targetChange), targetChange >= self._lastChange)
        self._lastChange = targetChange
    else
        self.changeOdo:snap(self:_formatChange(targetChange or 0))
        self._lastChange = targetChange or 0
    end
end

-- compact: roll the one readout
function Statistic:_updateCompactReadout(value, previousValue, targetChange, noChange, infinityText, hasNoHistory)
    if self.display == "change" then
        if infinityText then
            self.readoutOdo:snap(infinityText)
            self._lastChange = 0
        elseif self.numberEasing and not noChange then
            self.readoutOdo:to(self:_formatChange(targetChange), targetChange >= self._lastChange)
            self._lastChange = targetChange
        else
            self.readoutOdo:snap(self:_formatChange(targetChange or 0))
            self._lastChange = targetChange or 0
        end
    else -- "value"
        if self.numberEasing and not hasNoHistory then
            self.readoutOdo:to(self:_formatValue(value), value >= previousValue)
        else
            self.readoutOdo:snap(self:_formatValue(value))
        end
    end
end

function Statistic:Set(value)
    assert(typeof(value) == "number", "Statistic:Set() - value must be a number, got " .. typeof(value))

    local previousValue = self.value
    local hasNoHistory = not self._hasValue
    self.value = value
    self._hasValue = true

    if hasNoHistory then
        self._initialValue = value
    end

    local refValue = if self.changeBaseline == "initial" then self._initialValue else previousValue
    local noChange = hasNoHistory or refValue == value

    -- Determine target change, accent, and direction
    local targetChange, infinityText, accentKey, direction
    if noChange then
        targetChange = 0
        accentKey = "neutral"
        direction = 0
    elseif refValue == 0 then
        local sign = if value > 0 then "+" else "-"
        local suffix = if self.changeMode == "percentage" then "∞%" else "∞"
        infinityText = sign .. suffix
        accentKey = if value > 0 then "positive" else "negative"
        direction = if value > 0 then 1 else -1
    elseif self.changeMode == "percentage" then
        targetChange = ((value - refValue) / math.abs(refValue)) * 100
        direction = if targetChange > 0 then 1 elseif targetChange < 0 then -1 else 0
        accentKey = if direction == 1 then "positive" elseif direction == -1 then "negative" else "neutral"
    else
        targetChange = value - refValue
        direction = if targetChange > 0 then 1 elseif targetChange < 0 then -1 else 0
        accentKey = if direction == 1 then "positive" elseif direction == -1 then "negative" else "neutral"
    end

    self:_setAccent(accentKey, direction)

    if self.compact then
        self:_updateCompactReadout(value, previousValue, targetChange, noChange, infinityText, hasNoHistory)
    else
        self:_updateFullReadouts(value, previousValue, targetChange, noChange, infinityText, hasNoHistory)
    end
end

function Statistic:ResetBaseline(newBaseline)
    local baseline = if typeof(newBaseline) == "number" then newBaseline else self.value
    self._initialValue = baseline
    self.value = baseline
    self._hasValue = true
    self._lastChange = 0

    -- change-display card resets to 0; a value card is unaffected
    if self.compact then
        if self.display == "change" then
            self.readoutOdo:snap(self:_formatChange(0))
        end
    else
        self.changeOdo:snap(self:_formatChange(0))
    end

    self:_setAccent("neutral", 0)
end

function Statistic:_setShown(shown, animate)
    local w = self.window

    if self.compact then
        w:_reveal(
            self.main,
            { BackgroundTransparency = if shown then (self.window.theme.ElementTransparency or 0) else 1 },
            animate
        )
        w:_reveal(
            self.stroke,
            { Transparency = if shown then self.window.theme.ElementStrokeTransparency else 1 },
            animate
        )
        w:_reveal(self.card, { BackgroundTransparency = if shown then 0 else 1 }, animate)
        w:_reveal(self.title, { TextTransparency = if shown then 0 else 1 }, animate)
        if self.iconLabel then
            w:_reveal(self.iconLabel, { ImageTransparency = if shown then 0 else 1 }, animate)
        end
        self.readoutOdo:reveal(if shown then 0 else 1, animate)
        return
    end

    if shown then
        w:_revealCommon(self, animate)
        w:_reveal(self.gradientContainer, { BackgroundTransparency = 0 }, animate)
        w:_reveal(self.glow, { Transparency = 0.7 }, animate)
        self.valueOdo:reveal(0, animate)
        self.changeOdo:reveal(0, animate)
    else
        w:_hideCommon(self, animate)
        w:_reveal(self.gradientContainer, { BackgroundTransparency = 1 }, animate)
        w:_reveal(self.glow, { Transparency = 1 }, animate)
        self.valueOdo:reveal(1, animate)
        self.changeOdo:reveal(1, animate)
    end
end

-- Room the compact card needs: padding + icon (and gap) if shown + title text + the gap
-- to the readout + the readout number itself. Lets a horizontal group wrap sensibly.
function Statistic:_minWidth()
    local w = 30 + 10 -- 15+15 card padding, 10 gap between title and readout
    if self.icon then
        w += 22 -- 16 icon + 6 gap
    end
    w += functions.textWidth(self.window.theme.Font, 16, self.name)
    local readout = if self.display == "change" then self:_formatChange(0) else self:_formatValue(self.value)
    w += functions.textWidth(self.window.theme.Font, 17, readout)
    return w
end

moveable(Statistic)

return Statistic
