-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local enums = {}

-- FromValue with a manual scan fallback for executors whose Enum sandbox lacks it
function enums.itemFromValue(enumType, value)
    local ok, item = pcall(function()
        return enumType:FromValue(value)
    end)
    if ok and item then
        return item
    end

    local itemsOk, items = pcall(function()
        return enumType:GetEnumItems()
    end)
    if not itemsOk then
        return nil
    end

    for _, enumItem in items do
        if enumItem.Value == value then
            return enumItem
        end
    end

    return nil
end

return enums
