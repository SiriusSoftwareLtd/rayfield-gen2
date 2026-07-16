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
local atomic = require(script.Parent.persistenceWrite)

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
    _loadedConfigPath: string?,
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

    -- carry forward saved values whose elements aren't built yet; without this an early
    -- autosave would permanently drop a late element's saved value. only into the file they
    -- came from though, or Load("A") then Save("B") would smuggle A's flags into B.
    local loadedConfig = window._loadedConfig
    if loadedConfig and window._loadedConfigPath == fullPath then
        for flag, value in loadedConfig do
            if window.controls[flag] == nil then
                flags[flag] = value
            end
        end
    end

    local encodeSuccess, encoded = pcall(variables.httpService.JSONEncode, variables.httpService, flags)
    if not encodeSuccess then
        log.warn("Rayfield: Failed to encode configuration - " .. tostring(encoded))
        return false
    end

    local ok, err = pcall(function()
        atomic.write(dir, fullPath, encoded)
    end)

    if not ok then
        log.warn("Rayfield: Failed to save configuration - " .. tostring(err))
        return false
    end

    return true
end

-- Decode a saved config. Also hands back the raw text, so a file that read fine but isn't a
-- config can be backed up.
local function decodeFile(fullPath: string): ({ [string]: unknown }?, string?)
    if not filesystem.isfile(fullPath) then
        return nil, nil
    end

    local readOk, contents = pcall(filesystem.readfile, fullPath)
    if not readOk or type(contents) ~= "string" then
        log.warn("Rayfield: Failed to read configuration file")
        return nil, nil
    end

    local decodeOk, parsed = pcall(variables.httpService.JSONDecode, variables.httpService, contents)

    -- a scalar root is valid JSON but not a config, so it resets like any other bad file
    if not decodeOk or type(parsed) ~= "table" then
        return nil, contents
    end

    return parsed :: { [string]: unknown }, contents
end

-- Every corrupt file gets its own backup. Reusing one name would let a second corruption
-- destroy the salvageable data the first backup exists to keep.
local function backupPathFor(fullPath: string): string
    -- same path logic as getConfigPath, so the backup lands next to the file it mirrors
    local stem = path.stripExtension(fullPath, ".rfld")
    local candidate = stem .. " (Incorrect Format).rfld"
    local index = 2
    while index <= 100 and filesystem.isfile(candidate) do
        candidate = stem .. " (Incorrect Format " .. index .. ").rfld"
        index += 1
    end
    return candidate
end

function persistenceConfig.load(window: ConfigWindow, name: unknown?): boolean
    local dir, fullPath = persistenceConfig.getPath(window, name)

    -- no file API on this executor: nothing to load, degrade quietly
    if typeof(filesystem.isfile) ~= "function" then
        return false
    end

    local parsedFlags, raw = decodeFile(fullPath)

    -- a save that died mid-overwrite leaves its whole copy parked beside the wreck, so take
    -- that instead. only when the real file is really there, or a deleted config could come back.
    if not parsedFlags and filesystem.isfile(fullPath) then
        local parked, parkedRaw = decodeFile(atomic.tempPathFor(fullPath))
        if parked and parkedRaw then
            parsedFlags = parked
            -- put it back where it belongs so the next load reads it straight
            pcall(atomic.write, dir, fullPath, parkedRaw)
        end
    end

    if not parsedFlags then
        if raw then
            log.warn("Rayfield: Configuration file has an invalid format, backing up and resetting")
            local backupPath = backupPathFor(fullPath)
            pcall(function()
                filesystem.ensureDir(dir)
                filesystem.writefile(backupPath, raw)
                filesystem.delfile(fullPath)
            end)
        end
        return false
    end

    local flags = parsedFlags :: { [string]: unknown }
    local wasLoading = window._loading
    window._loading = true
    -- the reset must survive a throwing restore, or autosave stays suppressed all session
    local applyOk, applyErr = pcall(function()
        for flag, control in window.controls do
            persistenceConfig.applyTo(control, flags[flag])
        end
    end)
    -- back to what it was, not just down: a nested load from a control callback must leave
    -- the outer load's guard standing
    window._loading = wasLoading
    if not applyOk then
        log.warn("Rayfield: Failed to apply configuration - " .. tostring(applyErr))
    end

    -- kept so elements built after this load can still restore themselves (see
    -- Window:_restoreLate). without it a late element shows its default and the next
    -- autosave writes that default over the saved value.
    window._loadedConfig = flags
    window._loadedConfigPath = fullPath

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
            if base and base ~= "" and not base:find(" %(Incorrect Format[^%)]*%)$") then
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
    if typeof(filesystem.isfile) ~= "function" or not filesystem.isfile(fullPath) then
        return false
    end

    -- take the parked copy with it, or a later load could resurrect what was just deleted
    pcall(filesystem.delfile, atomic.tempPathFor(fullPath))

    return (pcall(filesystem.delfile, fullPath))
end

return persistenceConfig
