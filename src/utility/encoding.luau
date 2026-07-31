--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local services = require(script.Parent.services)

local httpService = services.getService("HttpService")
local encoding = {
    base64 = {},
    json = {},
}

local base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local base64Values: { [string]: number } = {}
for index = 1, #base64Alphabet do
    base64Values[string.sub(base64Alphabet, index, index)] = index - 1
end

function encoding.base64.decode(encoded: unknown): string?
    if type(encoded) ~= "string" then
        return nil
    end
    encoded = string.gsub(encoded, "%s", "")
    if #encoded == 0 or #encoded % 4 ~= 0 then
        return nil
    end

    local decoded = {}
    for index = 1, #encoded, 4 do
        local a = base64Values[string.sub(encoded, index, index)]
        local b = base64Values[string.sub(encoded, index + 1, index + 1)]
        local cCharacter = string.sub(encoded, index + 2, index + 2)
        local dCharacter = string.sub(encoded, index + 3, index + 3)
        local c = if cCharacter == "=" then 0 else base64Values[cCharacter]
        local d = if dCharacter == "=" then 0 else base64Values[dCharacter]
        if a == nil or b == nil or c == nil or d == nil then
            return nil
        end
        local hasInvalidPadding = (cCharacter == "=" and dCharacter ~= "=")
            or (index + 3 < #encoded and (cCharacter == "=" or dCharacter == "="))
        if hasInvalidPadding then
            return nil
        end

        local combined = a * 262144 + b * 4096 + c * 64 + d
        table.insert(decoded, string.char(math.floor(combined / 65536) % 256))
        if cCharacter ~= "=" then
            table.insert(decoded, string.char(math.floor(combined / 256) % 256))
        end
        if dCharacter ~= "=" then
            table.insert(decoded, string.char(combined % 256))
        end
    end
    return table.concat(decoded)
end

function encoding.json.encode(value: unknown): string?
    local ok, encoded = pcall(function()
        return httpService:JSONEncode(value)
    end)
    return if ok and type(encoded) == "string" then encoded else nil
end

function encoding.json.decode(value: string): unknown?
    local ok, decoded = pcall(function()
        return httpService:JSONDecode(value)
    end)
    return if ok then decoded else nil
end

return encoding
