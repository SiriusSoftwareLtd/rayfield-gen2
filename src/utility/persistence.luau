-- config + settings persistence. each fn takes the window

local variables = require(script.Parent.variables)
local filesystem = require(script.Parent.filesystem)
local log = require(script.Parent.log)

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

-- name picks a specific config; nil falls back to the window's default file. Both live in
-- the same folder so a named config sits right next to the auto-saved one.
function persistence.getPath(window, name)
    local dir = "Rayfield/Configurations"
    if window.configuration.customFolder then
        dir = dir .. "/" .. sanitizeFolder(window.configuration.customFolder)
    end
    local base = name or window.configuration.fileName or window.name
    -- a name of only dots/slashes sanitizes to nothing, which would leave a bare ".rfld";
    -- fall back to the window name, then a constant, so there's always a real filename
    local safe = sanitizeFile(base)
    if safe == "" then
        safe = sanitizeFile(window.name)
    end
    if safe == "" then
        safe = "Configuration"
    end
    return dir, dir .. "/" .. safe .. ".rfld"
end

function persistence.save(window, name)
    local dir, fullPath = persistence.getPath(window, name)

    local flags = {}
    for flag, control in window.controls do
        -- one bad control shouldnt abort the rest
        local ok, value = pcall(function()
            local v = control.value
            if control.__type == "ColorPicker" then
                -- RRGGBB plus an alpha byte (AA), so alpha round-trips; old 6-char configs still load
                return v:ToHex() .. string.format("%02x", math.clamp(math.round((control.alpha or 1) * 255), 0, 255))
            elseif control.__type == "Keybind" then
                return { tostring(v.EnumType), v.Value }
            end
            return v
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
        ensureDir(dir)
        filesystem.writefile(fullPath, encoded)
    end)

    if not ok then
        log.warn("Rayfield: Failed to save configuration - " .. tostring(err))
        return false
    end

    return true
end

function persistence.load(window, name)
    local dir, fullPath = persistence.getPath(window, name)

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
        -- Backup the corrupt file and remove the original
        log.warn("Rayfield: Configuration file has an invalid format, backing up and resetting")
        local backupPath = dir
            .. "/"
            .. sanitizeFile(name or window.configuration.fileName or window.name)
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
                    -- split off the optional alpha byte, restore it, then load the RRGGBB colour
                    local hex = tostring(value)
                    if #hex >= 8 then
                        control:SetAlpha((tonumber(hex:sub(7, 8), 16) or 255) / 255, true)
                        hex = hex:sub(1, 6)
                    end
                    value = Color3.fromHex(hex)
                end
                if control.__type == "Keybind" and value ~= nil then
                    value = Enum[value[1]]:FromValue(value[2])
                end
                control:Set(value, true)
            end)
            if not ok then
                log.warn("Rayfield: Failed to restore flag '" .. tostring(flag) .. "' - " .. tostring(err))
            end
        end
    end

    return true
end

-- list the loadable config names in the window's folder, sorted. skips the corrupt-format
-- backups so only configs a user can actually load show up.
function persistence.list(window)
    local dir = persistence.getPath(window)

    local names = {}
    local ok, files = pcall(filesystem.listfiles, dir)
    if not ok or type(files) ~= "table" then
        return names
    end

    for _, path in files do
        local file = tostring(path):match("[^/\\]+$") or tostring(path)
        local base = file:match("^(.+)%.rfld$")
        if base and not base:find(" %(Incorrect Format%)$") then
            table.insert(names, base)
        end
    end

    table.sort(names)
    return names
end

-- delete a named config. returns false if it wasnt there or the delete failed.
function persistence.delete(window, name)
    if type(name) ~= "string" or name == "" then
        return false
    end

    local _, fullPath = persistence.getPath(window, name)
    if not filesystem.isfile(fullPath) then
        return false
    end

    return (pcall(filesystem.delfile, fullPath))
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
        welcomeToast = window.settings.welcomeToast,
        haptics = window.settings.haptics,
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
        log.warn("Rayfield: Failed to save settings - " .. tostring(err))
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

    if type(parsed.welcomeToast) == "boolean" then
        window.settings.welcomeToast = parsed.welcomeToast
    end

    if type(parsed.haptics) == "boolean" then
        window.settings.haptics = parsed.haptics
    end

    return true
end

return persistence
