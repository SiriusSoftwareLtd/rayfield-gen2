--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local filesystem = require(script.Parent.filesystem)
local path = require(script.Parent.path)

-- defaults
local DEFAULT_ROOT_PATH = "Rayfield"

local fileSystemManager = {}
fileSystemManager.__index = fileSystemManager

export type FileSystemManager = {
    root: string,
    assets: string,
    getPath: (self: FileSystemManager, subpath: string?) -> string,
    getAssetsFolder: (self: FileSystemManager, subfolder: string?) -> string,
    getRootFolder: (self: FileSystemManager) -> string,
}

function fileSystemManager.new(name: string?): FileSystemManager
    -- ensure the folder exists
    local root = name or DEFAULT_ROOT_PATH
    local self = setmetatable({
        root = root,
        assets = root .. "/Assets",
    }, fileSystemManager) :: any
    pcall(filesystem.ensureFolder, self.root)
    pcall(filesystem.ensureFolder, self.assets)

    return self
end

function fileSystemManager:getPath(subpath: string?): string
    return path.join(self.root, subpath)
end

function fileSystemManager:getAssetsFolder(subfolder: string?): string
    if subfolder then
        local assetPath = path.join(self.assets, subfolder)
        pcall(filesystem.ensureFolder, assetPath)
        return assetPath
    end
    return self.assets
end

function fileSystemManager:getRootFolder(): string
    return self.root
end

return fileSystemManager
