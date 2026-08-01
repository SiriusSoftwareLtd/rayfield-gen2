--!nonstrict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- A line of text on its own. A Section is a heading with an icon that groups what follows it, and
-- a description belongs to the element above it; neither can simply say something. This can.

local Label = {}
Label.__index = Label
Label.__type = "Label"

local moveable = require(script.Parent.Parent.utility.moveable)
local locale = require(script.Parent.Parent.utility.locale)

-- Matched to the description line, since they are the same kind of text and reading one after the
-- other should not feel like two different voices.
local textSize = 14
local shownTransparency = 0.35

function Label.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        text = properties.text or properties.Text or properties.name or properties.Name or "",
        icon = properties.icon or properties.Icon,
    }, Label)

    -- padded and sized like the element rows, so a line of text lines up with the titles above
    -- and below it rather than sitting at its own margin
    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Name = "Label",
        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    })

    self.window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 20),
        PaddingRight = UDim.new(0, 20),
        PaddingBottom = UDim.new(0, 10),

        Parent = self.main,
    })

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Top,

        Parent = self.main,
    })

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,

            -- Animation
            ImageTransparency = 1, -- In = shownTransparency

            Parent = self.main,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = self.window:Create("TextLabel", {
        Text = locale.t(self.text),
        Size = UDim2.new(1, if self.icon then -22 else 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        RichText = true,
        TextSize = textSize,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,

        -- Animation
        TextTransparency = 1, -- In = shownTransparency

        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    return self
end

-- Swap the text. It rebinds rather than writing the label directly: the window remembers the
-- source each localised property was built from and re-resolves them all on SetLocale, so a
-- direct write would be undone by the next language change, replaced by a translation of the
-- text this label no longer shows.
function Label:Set(text)
    self.text = tostring(text)
    self.window:_bindLocale(self.title, "Text", self.text)
end

function Label:_setShown(shown, animate)
    local w = self.window
    w:_reveal(self.title, { TextTransparency = if shown then shownTransparency else 1 }, animate)
    if self.iconLabel then
        w:_reveal(self.iconLabel, { ImageTransparency = if shown then shownTransparency else 1 }, animate)
    end
end

moveable(Label)

return Label
