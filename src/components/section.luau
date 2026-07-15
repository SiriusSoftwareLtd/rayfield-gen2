--!nonstrict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local Section = {}
Section.__index = Section
Section.__type = "Section"

local moveable = require(script.Parent.Parent.utility.moveable)
local locale = require(script.Parent.Parent.utility.locale)

function Section.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or "Section",
        icon = properties.icon or properties.Icon,
    }, Section)

    -- first element in a tab shouldn't get extra space above it, only sections that
    -- follow something. this section isn't registered yet so an empty list means first.
    local topSpace = if #self.tab.elements == 0 then 0 else 13

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -40, 0, 20 + topSpace),
        BorderSizePixel = 0,
        Name = self.name,
        BackgroundTransparency = 1,
        Parent = self.tab.tabPage,
    })

    if topSpace > 0 then
        self.window:Create("UIPadding", {
            PaddingTop = UDim.new(0, topSpace),
            Parent = self.main,
        })
    end

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
            ImageTransparency = 1, -- In = 0.65

            Parent = self.main,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = self.window:Create("TextLabel", {
        -- Configurables
        Text = locale.t(self.name),

        Size = UDim2.fromOffset(0, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 15,
        AutomaticSize = Enum.AutomaticSize.X,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 1,

        -- Animation
        TextTransparency = 1, -- In = 0.6

        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    return self
end

function Section:_setShown(shown, animate)
    local w = self.window
    w:_reveal(self.title, { TextTransparency = if shown then 0.6 else 1 }, animate)
    if self.iconLabel then
        w:_reveal(self.iconLabel, { ImageTransparency = if shown then 0.65 else 1 }, animate)
    end
end

moveable(Section)

return Section
