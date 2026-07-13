--!nocheck

local variables = require(script.Parent.variables)

local paths = {}

local function sanitizeFolder(value)
    return (tostring(value):gsub("\\", "/"):gsub("%.%.", ""))
end

local function sanitizeFile(value)
    return (tostring(value):gsub("[/\\]", ""):gsub("%.%.", ""))
end

function paths.getConfigPath(window, name)
    local dir = variables.fileSystemManager:getPath("Configurations")
    if window.configuration.customFolder then
        dir = dir .. "/" .. sanitizeFolder(window.configuration.customFolder)
    end
    local base = name or window.configuration.fileName or window.name
    local safe = sanitizeFile(base)
    if safe == "" then
        safe = sanitizeFile(window.name)
    end
    if safe == "" then
        safe = "Configuration"
    end
    return dir, dir .. "/" .. safe .. ".rfld"
end

function paths.getSettingsPath()
    local dir = variables.fileSystemManager:getPath("Settings")
    return dir, dir .. "/rayfield.rfld"
end

return paths
