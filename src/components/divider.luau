--!nonstrict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- A rule across the page. A Section groups by naming what follows it, so breaking a page into
-- parts meant giving every part a heading whether it wanted one or not. This breaks without
-- saying anything, takes a word in the middle when there is one worth saying, and with no line
-- at all is simply room, which nothing else offered either.

local Divider = {}
Divider.__index = Divider
Divider.__type = "Divider"

local moveable = require(script.Parent.Parent.utility.moveable)
local locale = require(script.Parent.Parent.utility.locale)

local lineThickness = 1
local defaultSpacing = 12
local labelGap = 10
local labelHeight = 14
local textSize = 12

-- Faint on purpose. A rule is there to be noticed only when looked for; anything heavier reads
-- as a border and starts competing with the element strokes either side of it.
local lineShown = 0.88
local labelShown = 0.55

function Divider.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local spacing = properties.spacing or properties.Spacing
    local text = properties.text or properties.Text

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        text = if text ~= nil then tostring(text) else "",
        spacing = if type(spacing) == "number" then math.max(spacing, 0) else defaultSpacing,
        -- no rule is a divider that only takes room, which is the other thing people reach a
        -- divider for and the only way to get it
        line = properties.line ~= false and properties.Line ~= false,
    }, Divider)

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -40, 0, 0),
        BorderSizePixel = 0,
        Name = "Divider",
        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    })

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, labelGap),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,

        Parent = self.main,
    })

    if self.line then
        self.left = self:_buildHalf(1)
    end

    if self.text ~= "" then
        self:_buildLabel()
    end

    self:_applyHeight()

    return self
end

-- One side of the rule. The halves share whatever the label leaves, so the line stays centred
-- whatever the word in the middle is.
function Divider:_buildHalf(order)
    local rule = self.window:Create("Frame", {
        Size = UDim2.new(0, 0, 0, lineThickness),
        BorderSizePixel = 0,
        LayoutOrder = order,

        -- Animation
        BackgroundTransparency = 1, -- In = lineShown

        Parent = self.main,
    }, { BackgroundColor3 = "ContentColor" })

    self.window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Fill,

        Parent = rule,
    })

    return rule
end

-- The word in the middle and the far half it splits the rule into, built the first time one is
-- wanted. A plain rule is a single span with nothing to write to, so a divider that gains a
-- word later grows the parts then rather than every rule carrying ones it never shows.
function Divider:_buildLabel()
    self.title = self.window:Create("TextLabel", {
        Text = locale.t(self.text),
        Size = UDim2.fromOffset(0, labelHeight),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = textSize,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 2,

        -- Animation
        TextTransparency = 1, -- In = labelShown

        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    if self.line then
        self.right = self:_buildHalf(3)
    end
end

-- Spacing is the room above and below, so the height is that twice over plus whatever sits
-- between: a label if there is one, the rule if not, nothing at all on a spacer.
function Divider:_applyHeight()
    local content = if self.text ~= "" then labelHeight elseif self.line then lineThickness else 0
    self.main.Size = UDim2.new(1, -40, 0, self.spacing * 2 + content)
end

-- Swap the word in the middle, or clear it with "". A divider built without one builds its
-- label here on the first call, so this always lands.
--
-- It rebinds rather than writing the label directly: the window remembers the source each
-- localised property was built from and re-resolves them all on SetLocale, so a direct write
-- would be undone by the next language change.
function Divider:Set(text)
    self.text = if text ~= nil then tostring(text) else ""

    if self.text ~= "" and not self.title then
        self:_buildLabel()

        -- built after the page was revealed, so it has to be brought in on its own or it stays
        -- fully transparent
        if not self.window.hidden then
            self:_setShown(true, true)
        end
    end

    -- nothing to write to only when there is nothing to write, which is the state asked for
    if self.title then
        self.window:_bindLocale(self.title, "Text", self.text)

        -- clearing the word closes the rule back up. The halves sit either side of the label
        -- with a gap between them, so hiding the label alone leaves that gap in the middle of
        -- the line. The layout skips what it cannot see, so dropping the far half leaves the
        -- near one filling the width on its own, which is the plain rule again.
        local named = self.text ~= ""
        self.title.Visible = named
        if self.right then
            self.right.Visible = named
        end
    end

    self:_applyHeight()
end

function Divider:_setShown(shown, animate)
    local w = self.window
    local ruleTransparency = if shown then lineShown else 1

    w:_reveal(self.left, { BackgroundTransparency = ruleTransparency }, animate)
    w:_reveal(self.right, { BackgroundTransparency = ruleTransparency }, animate)
    w:_reveal(self.title, { TextTransparency = if shown then labelShown else 1 }, animate)
end

moveable(Divider)

return Divider
