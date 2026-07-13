--!nocheck

local runtime = require(script.Parent.runtime)
local fileSystemManager = require(script.Parent.filesystemManager)
local assetResolver = require(script.Parent.assetResolver)
local fontManager = require(script.Parent.fontManager)


local variables = {}

for key, value in runtime do
    variables[key] = value
end

variables.fileSystemManager = fileSystemManager.new()
variables.assetResolver = assetResolver.new(true, assetResolver.Enum.AssetDownloadUrl.RoProxyDownloadUrl)
variables.fontManager = fontManager.new(variables.fileSystemManager:getAssetsFolder("fonts"), false, true, assetResolver.Enum.AssetDownloadUrl.RoProxyDownloadUrl, {
    saveToDisk = true,
    skipCache = false,
    fallbackFont = Font.fromEnum(Enum.Font.SourceSans)
})

return variables
