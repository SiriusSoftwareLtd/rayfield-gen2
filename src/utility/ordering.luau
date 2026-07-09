-- Shared layout ordering. Tabs and groups both space children by tens so a descriptor can
-- slot in right after its element (order + 1) without colliding with the next one.

local function assignOrder(element, order)
    element.main.LayoutOrder = order
    if element.descriptor then
        element.descriptor.main.LayoutOrder = order + 1
    end
end

return assignOrder
