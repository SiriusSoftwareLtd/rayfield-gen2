--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local variables = require(script.Parent.variables)
local filesystem = require(script.Parent.filesystem)
local log = require(script.Parent.log)
local path = require(script.Parent.path)
local paths = require(script.Parent.persistencePaths)

local persistenceConfig = {}

type PersistedControl = {
    value: unknown,
    flag: string?,
    _canBeNil: boolean?,
    _serialize: ((PersistedControl) -> unknown)?,
    _deserialize: ((PersistedControl, unknown) -> ())?,
    Set: (PersistedControl, unknown) -> (),
}

type ConfigWindow = {
    controls: { [string]: PersistedControl },
    configuration: {
        fileName: string?,
        customFolder: string?,
    },
    name: string,
    _loading: boolean?,
    _loadedConfig: { [string]: unknown }?,
}

function persistenceConfig.getPath(window: ConfigWindow, name: unknown?): (string, string)
    return paths.getConfigPath(window, name)
end

function persistenceConfig.save(window: ConfigWindow, name: unknown?): boolean
    local dir, fullPath = persistenceConfig.getPath(window, name)

    local flags: { [string]: unknown } = {}
    for flag, control in window.controls do
        local ok, value = pcall(function()
            local serialize = control._serialize
            if serialize then
                return serialize(control)
            end
            return control.value
        end)
        if ok then
            flags[flag] = value
        else
            log.warn("Rayfield: Failed to serialize flag '" .. tostring(flag) .. "' - " .. tostring(value))
        end
    end

    local encodeSuccess, encoded = pcall(variables.httpService.JSONEncode, variables.httpService, flags)
    if not encodeSuccess then
        log.warn("Rayfield: Failed to encode configuration - " .. tostring(encoded))
        return false
    end

    local ok, err = pcall(function()
        filesystem.ensureDir(dir)
        filesystem.writefile(fullPath, encoded)
    end)

    if not ok then
        log.warn("Rayfield: Failed to save configuration - " .. tostring(err))
        return false
    end

    return true
end

function persistenceConfig.load(window: ConfigWindow, name: unknown?): boolean
    local dir, fullPath = persistenceConfig.getPath(window, name)

    if not filesystem.isfile(fullPath) then
        return false
    end

    local readOk, config = pcall(filesystem.readfile, fullPath)
    if not readOk or not config then
        log.warn("Rayfield: Failed to read configuration file")
        return false
    end

    local decodeOk, parsed = pcall(variables.httpService.JSONDecode, variables.httpService, config)

    if not decodeOk then
        log.warn("Rayfield: Configuration file has an invalid format, backing up and resetting")
        local backupPath = path.join(
            dir,
            path.sanitizeFile(name or window.configuration.fileName or window.name) .. " (Incorrect Format).rfld"
        )
        pcall(function()
            filesystem.ensureDir(dir)
            filesystem.writefile(backupPath, config)
            filesystem.delfile(fullPath)
        end)
        return false
    end

    local parsedFlags = parsed :: { [string]: unknown }
    window._loading = true
    for flag, control in window.controls do
        persistenceConfig.applyTo(control, parsedFlags[flag])
    end
    window._loading = false

    -- kept so elements built after this load can still restore themselves (see
    -- Window:_restoreLate). without it a late element shows its default and the next
    -- autosave writes that default over the saved value.
    window._loadedConfig = parsedFlags

    return true
end

-- restore one control from a decoded config. callers own the window._loading guard.
function persistenceConfig.applyTo(control: PersistedControl, value: unknown)
    if value == nil and not control._canBeNil then
        return
    end
    local ok, err = pcall(function()
        local deserialize = control._deserialize
        if deserialize then
            deserialize(control, value)
        else
            control:Set(value)
        end
    end)
    if not ok then
        log.warn("Rayfield: Failed to restore flag '" .. tostring(control.flag) .. "' - " .. tostring(err))
    end
end

function persistenceConfig.list(window: ConfigWindow): { string }
    local dir = persistenceConfig.getPath(window)

    local names: { string } = {}
    local ok, files = pcall(filesystem.listfiles, dir)
    if not ok or type(files) ~= "table" then
        return names
    end

    for _, filePath in files do
        local file = path.basename(filePath)
        -- listfiles returns folders and anything else in the dir; only our own configs are
        -- real names, so require the extension rather than listing whatever is lying around
        if file:sub(-5) == ".rfld" then
            local base = path.stripExtension(file, ".rfld")
            if base and base ~= "" and not base:find(" %(Incorrect Format%)$") then
                table.insert(names, base)
            end
        end
    end

    table.sort(names)
    return names
end

function persistenceConfig.delete(window: ConfigWindow, name: unknown): boolean
    if type(name) ~= "string" or name == "" then
        return false
    end

    local _, fullPath = persistenceConfig.getPath(window, name)
    if not filesystem.isfile(fullPath) then
        return false
    end

    return (pcall(filesystem.delfile, fullPath))
end

return persistenceConfig
