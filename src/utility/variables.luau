--!nocheck


local fileSystemManager = require(script.Parent.filesystemManager)
local assetResolver = require(script.Parent.assetResolver)
local fontManager = require(script.Parent.fontManager)
local services = require(script.Parent.services)


local variables = {}

variables.rayfieldHidden = false -- flipped while the menu is hidden

variables.secureMode = (function()
    local _getgenv = rawget(_G, "getgenv")
    if not _getgenv then
        return false
    end
    local ok, val = pcall(function()
        return _getgenv().RAYFIELD_SECURE
    end)
    return ok and val == true
end)()

variables.coreGui = services.getService("CoreGui")
variables.workspace = services.getService("Workspace") -- where HapticEngine parents its effects
variables.runService = services.getService("RunService")
variables.userInputService = services.getService("UserInputService")
variables.guiService = services.getService("GuiService")
variables.localPlayer = services.getService("Players").LocalPlayer
variables.tweenService = services.getService("TweenService")
variables.httpService = services.getService("HttpService")
variables.textService = services.getService("TextService")
variables.replicatedStorage = services.getService("ReplicatedStorage")
variables.localizationService = services.getService("LocalizationService")
variables.guiContainer = if variables.runService:IsStudio()
    then variables.localPlayer.PlayerGui
    elseif gethui then gethui()
    else variables.coreGui
variables.fileSystemManager = fileSystemManager.new()
variables.assetResolver = assetResolver.new(true, assetResolver.Enum.AssetDownloadUrl.RoProxyDownloadUrl)
variables.fontManager = fontManager.new(variables.fileSystemManager:getAssetsFolder("fonts"), false, true, assetResolver.Enum.AssetDownloadUrl.RoProxyDownloadUrl, {
    saveToDisk = true,
    skipCache = false,
    fallbackFont = Font.fromEnum(Enum.Font.SourceSans)
})

return variables
