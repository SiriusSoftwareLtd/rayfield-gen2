--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Shared layout ordering. Tabs and groups both space children by tens so a descriptor can
-- slot in right after its element (order + 1) without colliding with the next one.

type OrderedElement = {
    main: GuiObject,
    descriptor: { main: GuiObject }?,
    _slot: GuiObject?,
}

local function assignOrder(element: OrderedElement, order: number)
    element.main.LayoutOrder = order
    -- a row child is laid out by its slot rather than by itself, so the order has to reach that
    -- too, or a Move* call would reorder something the layout never looks at
    if element._slot then
        element._slot.LayoutOrder = order
    end
    if element.descriptor then
        element.descriptor.main.LayoutOrder = order + 1
    end
end

return assignOrder
