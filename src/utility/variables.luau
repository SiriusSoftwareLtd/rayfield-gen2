--!nocheck

local function getService(name)
    local service = game:GetService(name)
    return if cloneref then cloneref(service) else service
end

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

variables.coreGui = getService("CoreGui")
variables.workspace = getService("Workspace") -- where HapticEngine parents its effects
variables.runService = getService("RunService")
variables.userInputService = getService("UserInputService")
variables.guiService = getService("GuiService")
variables.localPlayer = getService("Players").LocalPlayer
variables.tweenService = getService("TweenService")
variables.httpService = getService("HttpService")
variables.textService = getService("TextService")
variables.replicatedStorage = getService("ReplicatedStorage")
variables.localizationService = getService("LocalizationService")
variables.guiContainer = if variables.runService:IsStudio()
    then variables.localPlayer.PlayerGui
    elseif gethui then gethui()
    else variables.coreGui

return variables
