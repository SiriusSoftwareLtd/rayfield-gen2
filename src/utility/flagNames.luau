--!nocheck

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local flagNames = {}

-- Derives a suitable config flag key from element name.
function flagNames.deriveFlagFromName(name)
    return (name:gsub("(%S+)", function(w)
        return w:sub(1, 1):upper() .. w:sub(2)
    end):gsub("[^%w]", ""))
end

return flagNames
