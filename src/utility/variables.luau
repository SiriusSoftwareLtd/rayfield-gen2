local function getService(name)
    local service = game:GetService(name)
    return if cloneref then cloneref(service) else service
end

local variables = {}

variables.coreGui = getService("CoreGui")
variables.runService = getService("RunService")
variables.localPlayer = getService("Players").LocalPlayer
variables.tweenService = getService('TweenService')
variables.guiContainer =
    if variables.runService:IsStudio() then variables.localPlayer.PlayerGui
    elseif gethui then gethui()
    else variables.coreGui

return variables
