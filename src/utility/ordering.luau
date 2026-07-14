-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Shared layout ordering. Tabs and groups both space children by tens so a descriptor can
-- slot in right after its element (order + 1) without colliding with the next one.

local function assignOrder(element, order)
    element.main.LayoutOrder = order
    if element.descriptor then
        element.descriptor.main.LayoutOrder = order + 1
    end
end

return assignOrder
