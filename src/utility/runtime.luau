--!nocheck

local services = require(script.Parent.services)

local runtime = {}

runtime.rayfieldHidden = false -- flipped while the menu is hidden

runtime.secureMode = (function()
    local _getgenv = rawget(_G, "getgenv")
    if not _getgenv then
        return false
    end
    local ok, val = pcall(function()
        return _getgenv().RAYFIELD_SECURE
    end)
    return ok and val == true
end)()

runtime.coreGui = services.getService("CoreGui")
runtime.workspace = services.getService("Workspace") -- where HapticEngine parents its effects
runtime.runService = services.getService("RunService")
runtime.userInputService = services.getService("UserInputService")
runtime.guiService = services.getService("GuiService")
runtime.localPlayer = services.getService("Players").LocalPlayer
runtime.tweenService = services.getService("TweenService")
runtime.httpService = services.getService("HttpService")
runtime.textService = services.getService("TextService")
runtime.replicatedStorage = services.getService("ReplicatedStorage")
runtime.localizationService = services.getService("LocalizationService")
runtime.guiContainer = if runtime.runService:IsStudio()
    then runtime.localPlayer.PlayerGui
    elseif gethui then gethui()
    else runtime.coreGui

return runtime