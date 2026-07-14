--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local variables = require(script.Parent.variables)
local path = require(script.Parent.path)

local paths = {}

type ConfigWindow = {
    configuration: {
        fileName: string?,
        customFolder: string?,
    },
    name: string,
}

function paths.getConfigPath(window: ConfigWindow, name: unknown?): (string, string)
    local dir = variables.fileSystemManager:getPath("Configurations")
    if window.configuration.customFolder then
        dir = path.join(dir, path.sanitizeFolder(window.configuration.customFolder))
    end
    local base = name or window.configuration.fileName or window.name
    local safe = path.sanitizeFile(base)
    if safe == "" then
        safe = path.sanitizeFile(window.name)
    end
    if safe == "" then
        safe = "Configuration"
    end
    return dir, path.join(dir, safe .. ".rfld")
end

function paths.getSettingsPath(): (string, string)
    local dir = variables.fileSystemManager:getPath("Settings")
    return dir, path.join(dir, "rayfield.rfld")
end

return paths
