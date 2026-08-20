--!nonstrict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Copy on a page: a title, a body, or both, on a card of its own. A Section names what follows
-- it and a description belongs to the element above it, so anything that simply needs to say
-- something had nowhere to go.

local Text = {}
Text.__index = Text
Text.__type = "Text"

local moveable = require(script.Parent.Parent.utility.moveable)
local locale = require(script.Parent.Parent.utility.locale)

local titleSize = 16
local bodySize = 14

-- the body sits back from the title, the way a description does under an element name
local bodyShown = 0.45

function Text.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = tostring(properties.name or properties.Name or ""),
        text = tostring(properties.text or properties.Text or ""),
        icon = properties.icon or properties.Icon,
    }, Text)

    -- the card grows with its copy rather than being given a height, since the whole point of
    -- it is text of a length nobody knows in advance
    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Name = if self.name ~= "" then self.name else "Text",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),

        -- Animation
        BackgroundTransparency = 1, -- In = ElementTransparency

        Parent = self.tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    self.stroke = self.window:StyleElementBody(self.main)

    self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, 14),
        PaddingBottom = UDim.new(0, 14),
        PaddingLeft = UDim.new(0, 20),
        PaddingRight = UDim.new(0, 20),

        Parent = self.main,
    })

    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.main,
    })

    -- the title and its icon share a row so they sit on one line above the body
    self.titleRow = self.window:Create("Frame", {
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        LayoutOrder = 1,

        Parent = self.main,
    })

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Top,

        Parent = self.titleRow,
    })

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,

            -- Animation
            ImageTransparency = 1, -- In = 0, with the rest of the shared set

            Parent = self.titleRow,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = self.window:Create("TextLabel", {
        Text = locale.t(self.name),
        Size = UDim2.new(1, if self.icon then -22 else 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        RichText = true,
        TextSize = titleSize,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,

        -- Animation
        TextTransparency = 1, -- In = 0, with the rest of the shared set

        Parent = self.titleRow,
    }, { TextColor3 = "TitlingColor", FontFace = "Font" })

    self.body = self.window:Create("TextLabel", {
        Text = locale.t(self.text),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        RichText = true,
        TextSize = bodySize,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,

        -- Animation
        TextTransparency = 1, -- In = bodyShown

        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self:_applyPresence()

    return self
end

-- Hide what isn't there, row and all. A hidden child costs the layout nothing, but a visible
-- row holding an empty label still spends its 6px of padding, which is what left a body on its
-- own sitting 20 from the top of the card and 14 from the bottom.
function Text:_applyPresence()
    self.titleRow.Visible = self.name ~= "" or self.icon ~= nil
    self.body.Visible = self.text ~= ""
end

-- Swap the body. It rebinds rather than writing the label directly: the window remembers the
-- source each localised property was built from and re-resolves them all on SetLocale, so a
-- direct write would be undone by the next language change, replaced by a translation of the
-- copy this element no longer shows.
function Text:Set(text)
    self.text = tostring(text)
    self.window:_bindLocale(self.body, "Text", self.text)
    self:_applyPresence()
end

-- Swap the title, on the same terms.
function Text:SetTitle(title)
    self.name = tostring(title)
    self.window:_bindLocale(self.title, "Text", self.name)
    self:_applyPresence()
end

function Text:_setShown(shown, animate)
    -- the card, its stroke, the title and the icon are the shared set every element has
    if shown then
        self.window:_revealCommon(self, animate)
    else
        self.window:_hideCommon(self, animate)
    end

    self.window:_reveal(self.body, { TextTransparency = if shown then bodyShown else 1 }, animate)
end

moveable(Text)

return Text
