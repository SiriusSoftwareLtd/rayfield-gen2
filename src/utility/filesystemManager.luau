--!nocheck

local filesystem = require(script.Parent.filesystem)
local path = require(script.Parent.path)

-- defaults
local DEFAULT_ROOT_PATH = "Rayfield"

local fileSystemManager = {}
fileSystemManager.__index = fileSystemManager

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
    return path.join(self.root, subpath)
end

function fileSystemManager:getAssetsFolder(subfolder)
    if subfolder then
        local assetPath = path.join(self.assets, subfolder)
        pcall(filesystem.ensureFolder, assetPath)
        return assetPath
    end
    return self.assets
end

function fileSystemManager:getRootFolder()
    return self.root
end

return fileSystemManager
