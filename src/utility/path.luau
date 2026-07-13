--!nocheck

local path = {}

function path.join(basePath, childPath)
    if not childPath or childPath == "" then
        return basePath
    end

    return basePath .. "/" .. childPath
end

function path.sanitizeFolder(value)
    return (tostring(value):gsub("\\", "/"):gsub("%.%.", ""))
end

function path.sanitizeFile(value)
    return (tostring(value):gsub("[/\\]", ""):gsub("%.%.", ""))
end

function path.basename(value)
    return tostring(value):match("[^/\\]+$") or tostring(value)
end

function path.stripExtension(value, extension)
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