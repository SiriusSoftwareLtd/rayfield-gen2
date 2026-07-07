-- config + settings persistence. each fn takes the window

local variables = require(script.Parent.variables)
local filesystem = require(script.Parent.filesystem)

local persistence = {}

-- strip path escapes so a folder/file name cant break out of Rayfield/Configurations
local function sanitizeFolder(value)
    return (tostring(value):gsub("\\", "/"):gsub("%.%.", ""))
end

local function sanitizeFile(value)
    return (tostring(value):gsub("[/\\]", ""):gsub("%.%.", ""))
end

-- make each folder in a / joined path
local function ensureDir(dir)
    local built = ""
    for part in string.gmatch(dir, "[^/]+") do
        built = if built == "" then part else built .. "/" .. part
        if not filesystem.isfolder(built) then
            filesystem.makefolder(built)
        end
    end
end

-- config -----------------------------------------------------------------

function persistence.getPath(window)
    local dir = "Rayfield/Configurations"
    if window.configuration.customFolder then
        dir = dir .. "/" .. sanitizeFolder(window.configuration.customFolder)
    end
    local fileName = sanitizeFile(window.configuration.fileName or window.name) .. ".rfld"
    return dir, dir .. "/" .. fileName
end

function persistence.save(window)
    local dir, fullPath = persistence.getPath(window)

    local flags = {}
    for flag, control in window.controls do
        -- one bad control shouldnt abort the rest
        local ok, value = pcall(function()
            local v = control.value
            if control.__type == "ColorPicker" then
                return v:ToHex()
            elseif control.__type == "Keybind" then
                return { tostring(v.EnumType), v.Value }
            end
            return v
        end)
        if ok then
            flags[flag] = value
        else
            warn("Rayfield: Failed to serialize flag '" .. tostring(flag) .. "' - " .. tostring(value))
        end
    end

    local encodeSuccess, encoded = pcall(variables.httpService.JSONEncode, variables.httpService, flags)
    if not encodeSuccess then
        warn("Rayfield: Failed to encode configuration - " .. tostring(encoded))
        return false
    end

    local ok, err = pcall(function()
        ensureDir(dir)
        filesystem.writefile(fullPath, encoded)
    end)

    if not ok then
        warn("Rayfield: Failed to save configuration - " .. tostring(err))
        return false
    end

    return true
end

function persistence.load(window)
    local dir, fullPath = persistence.getPath(window)

    if not filesystem.isfile(fullPath) then
        return false
    end

    local readOk, config = pcall(filesystem.readfile, fullPath)
    if not readOk or not config then
        warn("Rayfield: Failed to read configuration file")
        return false
    end

    local decodeOk, parsed = pcall(variables.httpService.JSONDecode, variables.httpService, config)

    if not decodeOk then
        -- Backup the corrupt file and remove the original
        warn("Rayfield: Configuration file has an invalid format, backing up and resetting")
        local backupPath = dir
            .. "/"
            .. sanitizeFile(window.configuration.fileName or window.name)
            .. " (Incorrect Format).rfld"
        pcall(function()
            ensureDir(dir)
            filesystem.writefile(backupPath, config)
            filesystem.delfile(fullPath)
        end)
        return false
    end

    for flag, control in window.controls do
        local value = parsed[flag]
        if value ~= nil or control._canBeNil then
            -- one bad control shouldnt abort the rest
            local ok, err = pcall(function()
                if control.__type == "ColorPicker" and value ~= nil then
                    value = Color3.fromHex(value)
                end
                if control.__type == "Keybind" and value ~= nil then
                    value = Enum[value[1]]:FromValue(value[2])
                end
                control:Set(value, true)
            end)
            if not ok then
                warn("Rayfield: Failed to restore flag '" .. tostring(flag) .. "' - " .. tostring(err))
            end
        end
    end

    return true
end

-- settings ---------------------------------------------------------------

function persistence.getSettingsPath()
    local dir = "Rayfield/Settings"
    return dir, dir .. "/rayfield.rfld"
end

function persistence.saveSettings(window)
    local dir, fullPath = persistence.getSettingsPath()

    local data = {
        toggleKeybind = { tostring(window.settings.toggleKeybind.EnumType), window.settings.toggleKeybind.Value },
        mouseOverride = window.settings.mouseOverride,
        keepOnScreen = window.settings.keepOnScreen,
    }

    local ok, encoded = pcall(variables.httpService.JSONEncode, variables.httpService, data)
    if not ok then
        return false
    end

    local writeOk, err = pcall(function()
        ensureDir(dir)
        filesystem.writefile(fullPath, encoded)
    end)

    if not writeOk then
        warn("Rayfield: Failed to save settings - " .. tostring(err))
        return false
    end

    return true
end

function persistence.loadSettings(window)
    local _, fullPath = persistence.getSettingsPath()

    local fileExists = false
    pcall(function()
        fileExists = filesystem.isfile(fullPath)
    end)
    if not fileExists then
        return false
    end

    local readOk, config = pcall(filesystem.readfile, fullPath)
    if not readOk or not config then
        return false
    end

    local decodeOk, parsed = pcall(variables.httpService.JSONDecode, variables.httpService, config)
    if not decodeOk then
        return false
    end

    if parsed.toggleKeybind then
        pcall(function()
            window.settings.toggleKeybind = Enum[parsed.toggleKeybind[1]]:FromValue(parsed.toggleKeybind[2])
        end)
    end

    if type(parsed.mouseOverride) == "boolean" then
        window.settings.mouseOverride = parsed.mouseOverride
    end

    if type(parsed.keepOnScreen) == "boolean" then
        window.settings.keepOnScreen = parsed.keepOnScreen
    end

    return true
end

return persistence
