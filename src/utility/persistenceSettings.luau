--!nocheck

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local variables = require(script.Parent.variables)
local filesystem = require(script.Parent.filesystem)
local paths = require(script.Parent.persistencePaths)

local persistenceSettings = {}

local function enumItemFromValue(enumType, value)
    local ok, enumItem = pcall(function()
        return enumType:FromValue(value)
    end)
    if ok and enumItem then
        return enumItem
    end

    local itemsOk, items = pcall(function()
        return enumType:GetEnumItems()
    end)
    if not itemsOk then
        return nil
    end

    for _, item in items do
        if item.Value == value then
            return item
        end
    end

    return nil
end

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
            local enumName = tostring(parsed.toggleKeybind[1]):gsub("^Enum%.", "")
            local enumType = Enum[enumName]
            if enumType then
                local enumItem = enumItemFromValue(enumType, parsed.toggleKeybind[2])
                if enumItem then
                    window.settings.toggleKeybind = enumItem
                end
            end
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
