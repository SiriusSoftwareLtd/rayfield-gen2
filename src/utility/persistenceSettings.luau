--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local variables = require(script.Parent.variables)
local filesystem = require(script.Parent.filesystem)
local paths = require(script.Parent.persistencePaths)
local atomic = require(script.Parent.persistenceWrite)
local enums = require(script.Parent.enums)

local persistenceSettings = {}

type SettingsWindow = {
    settings: {
        toggleKeybind: EnumItem,
        mouseOverride: boolean,
        keepOnScreen: boolean,
        welcomeToast: boolean,
        haptics: boolean,
    },
}

type DecodedSettings = {
    toggleKeybind: { [number]: unknown }?,
    mouseOverride: unknown?,
    keepOnScreen: unknown?,
    welcomeToast: unknown?,
    haptics: unknown?,
}

function persistenceSettings.getSettingsPath(): (string, string)
    return paths.getSettingsPath()
end

function persistenceSettings.saveSettings(window: SettingsWindow): boolean
    local dir, fullPath = persistenceSettings.getSettingsPath()

    local data: { [string]: unknown } = {
        toggleKeybind = {
            tostring(window.settings.toggleKeybind.EnumType),
            window.settings.toggleKeybind.Value,
        } :: { unknown },
        mouseOverride = window.settings.mouseOverride,
        keepOnScreen = window.settings.keepOnScreen,
        welcomeToast = window.settings.welcomeToast,
        haptics = window.settings.haptics,
    }

    local ok, encoded = pcall(variables.httpService.JSONEncode, variables.httpService, data)
    if not ok then
        return false
    end

    local writeOk = pcall(atomic.write, dir, fullPath, encoded)

    if not writeOk then
        return false
    end

    return true
end

-- Decode the settings file. Also hands back the raw text, so a parked copy can be put back.
local function decodeFile(fullPath: string): (DecodedSettings?, string?)
    local fileExists = false
    pcall(function()
        fileExists = filesystem.isfile(fullPath)
    end)
    if not fileExists then
        return nil, nil
    end

    local readOk, contents = pcall(filesystem.readfile, fullPath)
    if not readOk or type(contents) ~= "string" then
        return nil, nil
    end

    local decodeOk, parsed = pcall(variables.httpService.JSONDecode, variables.httpService, contents)
    -- JSONDecode happily returns scalars; a corrupt file must not brick CreateWindow
    if not decodeOk or type(parsed) ~= "table" then
        return nil, contents
    end

    return parsed :: DecodedSettings, contents
end

function persistenceSettings.loadSettings(window: SettingsWindow): boolean
    local dir, fullPath = persistenceSettings.getSettingsPath()

    local settings = decodeFile(fullPath)

    -- a save that died mid-overwrite leaves its whole copy parked beside the wreck, so take that
    if not settings then
        local parked, parkedRaw = decodeFile(atomic.tempPathFor(fullPath))
        if parked and parkedRaw then
            settings = parked
            -- put it back where it belongs so the next load reads it straight
            pcall(atomic.write, dir, fullPath, parkedRaw)
        end
    end

    if not settings then
        return false
    end

    if settings.toggleKeybind then
        pcall(function()
            local enumName = tostring(settings.toggleKeybind[1]):gsub("^Enum%.", "")
            local enumType = (Enum :: any)[enumName]
            if enumType then
                local enumItem = enums.itemFromValue(enumType, settings.toggleKeybind[2])
                if enumItem then
                    window.settings.toggleKeybind = enumItem
                end
            end
        end)
    end

    if type(settings.mouseOverride) == "boolean" then
        window.settings.mouseOverride = settings.mouseOverride
    end

    if type(settings.keepOnScreen) == "boolean" then
        window.settings.keepOnScreen = settings.keepOnScreen
    end

    if type(settings.welcomeToast) == "boolean" then
        window.settings.welcomeToast = settings.welcomeToast
    end

    if type(settings.haptics) == "boolean" then
        window.settings.haptics = settings.haptics
    end

    return true
end

return persistenceSettings
