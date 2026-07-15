--!nocheck

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local services = require(script.Parent.services)

local runtime = {}

runtime.secureMode = (function()
    -- getgenv lives in the executor's script environment, not _G, same as gethui below
    if typeof(getgenv) ~= "function" then
        return false
    end
    local ok, val = pcall(function()
        return getgenv().RAYFIELD_SECURE
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
-- a gethui stub that returns nil would parent every ScreenGui nowhere, so fall back to CoreGui
runtime.guiContainer = (function()
    if runtime.runService:IsStudio() then
        return runtime.localPlayer.PlayerGui
    end
    if typeof(gethui) == "function" then
        local ok, container = pcall(gethui)
        if ok and container then
            return container
        end
    end
    return runtime.coreGui
end)()

return runtime
