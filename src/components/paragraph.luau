--!nonstrict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- A title with a body under it, on a card of its own. Long-form copy has nowhere to go otherwise:
-- a description hangs off an element and a Label is a single line, so anything that needs to
-- explain itself ends up as a button nobody is meant to press.

local Paragraph = {}
Paragraph.__index = Paragraph
Paragraph.__type = "Paragraph"

local moveable = require(script.Parent.Parent.utility.moveable)
local locale = require(script.Parent.Parent.utility.locale)

local titleSize = 15
local bodySize = 13

-- the body sits back from the title, the way a description does under an element name
local bodyShown = 0.45

function Paragraph.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or properties.title or properties.Title or "",
        text = properties.text or properties.Text or properties.content or properties.Content or "",
        icon = properties.icon or properties.Icon,
    }, Paragraph)

    -- the card grows with its copy rather than being given a height, since the whole point of it
    -- is text of a length nobody knows in advance
    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Name = self.name,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
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

    self.titleRow = self.window:Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
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
        BackgroundTransparency = 1,
        RichText = true,
        TextSize = titleSize,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,

        -- Animation
        TextTransparency = 1, -- In = 0, with the rest of the shared set

        Parent = self.titleRow,
    }, { TextColor3 = "TitlingColor", FontFace = "TitleFont" })

    self.body = self.window:Create("TextLabel", {
        Text = locale.t(self.text),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
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

    -- a title on its own is a Label with a card around it, so the body only takes room when there
    -- is a body to take it
    self.body.Visible = self.text ~= ""
    self.title.Visible = self.name ~= ""

    return self
end

-- Change either half. Both go through the locale the same way the text they were built with did.
function Paragraph:Set(text, title)
    if text ~= nil then
        self.text = tostring(text)
        self.body.Text = locale.resolve(self.text)
        self.body.Visible = self.text ~= ""
    end

    if title ~= nil then
        self.name = tostring(title)
        self.title.Text = locale.resolve(self.name)
        self.title.Visible = self.name ~= ""
    end
end

function Paragraph:_setShown(shown, animate)
    -- the card, its stroke, the title and the icon are the shared set every element has
    if shown then
        self.window:_revealCommon(self, animate)
    else
        self.window:_hideCommon(self, animate)
    end

    self.window:_reveal(self.body, { TextTransparency = if shown then bodyShown else 1 }, animate)
end

moveable(Paragraph)

return Paragraph
