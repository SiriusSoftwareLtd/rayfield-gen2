--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local path = {}

function path.join(basePath: string, childPath: string?): string
    if not childPath or childPath == "" then
        return basePath
    end

    return basePath .. "/" .. childPath
end

function path.sanitizeFolder(value: unknown): string
    return (tostring(value):gsub("\\", "/"):gsub("%.%.", ""))
end

function path.sanitizeFile(value: unknown): string
    return (tostring(value):gsub("[/\\]", ""):gsub("%.%.", ""))
end

function path.basename(value: unknown): string
    return tostring(value):match("[^/\\]+$") or tostring(value)
end

function path.stripExtension(value: unknown, extension: string?): string
    if extension and extension ~= "" then
        local text = tostring(value)
        if text:sub(-#extension) == extension then
            return text:sub(1, -#extension - 1)
        end
        return text
    end

    local base = tostring(value):match("^(.+)%.%w+$")
    return base or tostring(value)
end

return path
