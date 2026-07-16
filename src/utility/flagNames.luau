--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local flagNames = {}

local offsetBasis = 2166136261
local prime = 16777619

-- FNV-1a over the raw bytes. Same name, same flag, every session, or saved configs stop reloading.
local function hashName(name: string): number
    local hash = offsetBasis
    for index = 1, #name do
        hash = bit32.bxor(hash, string.byte(name, index))
        -- split the multiply so it never runs out of double precision
        local low = hash % 65536
        local high = (hash - low) / 65536
        hash = (((high * prime) % 65536) * 65536 + low * prime) % 4294967296
    end
    return hash
end

-- Derives a suitable config flag key from element name.
function flagNames.deriveFlagFromName(name: string): string
    local flag = name:gsub("(%S+)", function(w: string): string
        return w:sub(1, 1):upper() .. w:sub(2, -1)
    end):gsub("[^%w]", "")

    -- %w is ASCII only, so a name like "音量" strips down to nothing and the element would
    -- silently skip persistence. Hash the name instead and it keeps a stable key.
    if flag == "" and name ~= "" then
        return string.format("Flag%08x", hashName(name))
    end

    return flag
end

return flagNames
