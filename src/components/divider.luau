--!nonstrict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- A rule across the page. A Section groups by naming what follows it, so breaking a page into
-- parts meant giving every part a heading whether it wanted one or not. This breaks without
-- saying anything, takes a word in the middle when there is one worth saying, and with no line at
-- all is simply room, which nothing else offered either.

local Divider = {}
Divider.__index = Divider
Divider.__type = "Divider"

local moveable = require(script.Parent.Parent.utility.moveable)
local locale = require(script.Parent.Parent.utility.locale)

local lineThickness = 1
local defaultSpacing = 12
local labelGap = 10
local textSize = 12

-- Faint on purpose. A rule is there to be noticed only when looked for; anything heavier reads as
-- a border and starts competing with the element strokes either side of it.
local lineShown = 0.88
local labelShown = 0.55

function Divider.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local spacing = properties.spacing or properties.Spacing
    local text = properties.text or properties.Text or properties.name or properties.Name

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        text = if text ~= nil and text ~= "" then tostring(text) else nil,
        spacing = if type(spacing) == "number" then math.max(spacing, 0) else defaultSpacing,
        -- no line is a divider that only takes room, which is the other thing people reach a
        -- divider for and the only way to get it
        line = properties.line ~= false and properties.Line ~= false,
    }, Divider)

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -40, 0, self.spacing * 2 + (if self.line then lineThickness else 0)),
        BorderSizePixel = 0,
        Name = "Divider",
        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    })

    if not self.line then
        return self -- room and nothing else
    end

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, labelGap),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,

        Parent = self.main,
    })

    -- the halves either side of a label share whatever the label leaves, so the rule stays
    -- centred whatever the word in the middle is
    local function half(order)
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

    self.left = half(1)

    if self.text then
        self.title = self.window:Create("TextLabel", {
            Text = locale.t(self.text),
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 14),
            BackgroundTransparency = 1,
            TextSize = textSize,
            TextXAlignment = Enum.TextXAlignment.Center,
            LayoutOrder = 2,

            -- Animation
            TextTransparency = 1, -- In = labelShown

            Parent = self.main,
        }, { TextColor3 = "ContentColor", FontFace = "Font" })

        self.right = half(3)
    end

    return self
end

-- Swap the word in the middle. A divider built without one has no label to put it in, since the
-- rule is a single span in that case rather than two halves with a gap between them.
--
-- It rebinds rather than writing the label directly: the window remembers the source each
-- localised property was built from and re-resolves them all on SetLocale, so a direct write
-- would be undone by the next language change.
function Divider:Set(text)
    if not self.title then
        return
    end

    self.text = if text ~= nil and text ~= "" then tostring(text) else ""
    self.window:_bindLocale(self.title, "Text", self.text)

    -- clearing the word has to close the rule back up. The halves are laid out either side of
    -- the label with a gap between them, so hiding the label alone leaves that gap sitting in
    -- the middle of the line. The layout skips what it cannot see, so dropping the far half
    -- leaves the near one to fill the width on its own, which is the plain rule again.
    local named = self.text ~= ""
    self.title.Visible = named
    self.right.Visible = named
end

function Divider:_setShown(shown, animate)
    local w = self.window

    for _, rule in { self.left, self.right } do
        if rule then
            w:_reveal(rule, { BackgroundTransparency = if shown then lineShown else 1 }, animate)
        end
    end

    if self.title then
        w:_reveal(self.title, { TextTransparency = if shown then labelShown else 1 }, animate)
    end
end

moveable(Divider)

return Divider
