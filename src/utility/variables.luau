--!nocheck

local runtime = require(script.Parent.runtime)
local constants = require(script.Parent.constants)
local fileSystemManager = require(script.Parent.filesystemManager)
local assetResolver = require(script.Parent.assetResolver)
local fontManager = require(script.Parent.fontManager)

local variables = table.clone(runtime)

-- built-in stand-in until the real brand faces download (secure mode)
local builderSans = Font.fromEnum(Enum.Font.BuilderSans)

variables.fileSystemManager = fileSystemManager.new()
variables.assetResolver = assetResolver.new(true, assetResolver.Enum.AssetDownloadUrl.RoProxyDownloadUrl)
variables.fontManager = fontManager.new(
    variables.fileSystemManager:getAssetsFolder("fonts"),
    false,
    true,
    assetResolver.Enum.AssetDownloadUrl.RoProxyDownloadUrl,
    {
        saveToDisk = true,
        skipCache = false,
        fallbackFont = builderSans,
    }
)

-- brand font at a weight, non-blocking. normal mode streams the family id direct; secure mode
-- shows BuilderSans until the real faces download and swap in (see init).
function variables.brandFont(weight)
    if variables.secureMode then
        return Font.new(builderSans.Family, weight)
    end
    return Font.new(constants.fontAsset, weight)
end

return variables
