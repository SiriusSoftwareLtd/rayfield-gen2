--!nocheck

local variables = require(script.Parent.variables)
local filesystem = require(script.Parent.filesystem)
local paths = require(script.Parent.persistencePaths)

local persistenceSettings = {}

function persistenceSettings.getSettingsPath()
    return paths.getSettingsPath()
end

function persistenceSettings.saveSettings(window)
    local dir, fullPath = persistenceSettings.getSettingsPath()

    local data = {
        toggleKeybind = { tostring(window.settings.toggleKeybind.EnumType), window.settings.toggleKeybind.Value },
        mouseOverride = window.settings.mouseOverride,
        keepOnScreen = window.settings.keepOnScreen,
        welcomeToast = window.settings.welcomeToast,
        haptics = window.settings.haptics,
    }

    local ok, encoded = pcall(variables.httpService.JSONEncode, variables.httpService, data)
    if not ok then
        return false
    end

    local writeOk, _err = pcall(function()
        filesystem.ensureDir(dir)
        filesystem.writefile(fullPath, encoded)
    end)

    if not writeOk then
        return false
    end

    return true
end

function persistenceSettings.loadSettings(window)
    local _, fullPath = persistenceSettings.getSettingsPath()

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

    if type(parsed.welcomeToast) == "boolean" then
        window.settings.welcomeToast = parsed.welcomeToast
    end

    if type(parsed.haptics) == "boolean" then
        window.settings.haptics = parsed.haptics
    end

    return true
end

return persistenceSettings
