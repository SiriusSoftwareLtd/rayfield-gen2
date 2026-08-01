--!nonstrict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local Descriptor = {}
Descriptor.__index = Descriptor
Descriptor.__type = "Descriptor"

local locale = require(script.Parent.Parent.utility.locale)

function Descriptor.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        description = properties.description or properties.Description or "",
    }, Descriptor)

    -- Sized and padded like the element it describes, so the text starts under that element's
    -- title and runs to the same right edge. It used to be a narrower row again inside a
    -- narrower frame, which wrapped a description a good hundred pixels before it had to.
    self.main = self.window:Create("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 0),

        Parent = self.tab.tabPage,
    })

    self.window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 20),
        PaddingRight = UDim.new(0, 20),

        Parent = self.main,
    })

    self.window:Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = self.main,
    })

    self.titleLabel = self.window:Create("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        RichText = true,
        Size = UDim2.new(1, 0, 0, 0),
        Text = locale.t(self.description),
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,

        -- Animation
        TextTransparency = 1, -- In = 0.7

        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    -- Bottom spacing
    self.window:Create("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        Size = UDim2.fromOffset(0, 15),
        Parent = self.main,
    })

    return self
end

return Descriptor
