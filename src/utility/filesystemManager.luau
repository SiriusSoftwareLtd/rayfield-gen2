--!nocheck

local filesystem = require(script.Parent.filesystem)

-- defaults
local DEFAULT_ROOT_PATH = "Rayfield"


local fileSystemManager = {}
fileSystemManager.__index = fileSystemManager

local function joinPath(basePath, childPath)
    if not childPath or childPath == "" then
        return basePath
    end

    return basePath .. "/" .. childPath
end

function fileSystemManager.new(name)
    local self = setmetatable({}, fileSystemManager)
    -- ensure the folder exists
    self.root = name or DEFAULT_ROOT_PATH
    self.assets = self.root .. "/Assets"
    pcall(filesystem.ensureFolder, self.root)
    pcall(filesystem.ensureFolder, self.assets)

    return self
end

function fileSystemManager:getPath(subpath)
    return joinPath(self.root, subpath)
end

function fileSystemManager:getAssetsFolder(subfolder)
    if subfolder then
        local path = joinPath(self.assets, subfolder)
        pcall(filesystem.ensureFolder, path)
        return path
    end
    return self.assets
end

function fileSystemManager:getRootFolder()
    return self.root
end

return fileSystemManager