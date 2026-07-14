--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local services = require(script.Parent.services)

export type RuntimeState = {
    rayfieldHidden: boolean,
    secureMode: boolean,
    coreGui: CoreGui,
    workspace: Workspace,
    runService: RunService,
    userInputService: UserInputService,
    guiService: GuiService,
    localPlayer: Player,
    tweenService: TweenService,
    httpService: HttpService,
    textService: TextService,
    replicatedStorage: ReplicatedStorage,
    localizationService: LocalizationService,
    guiContainer: Instance,
}

local runtime = {} :: RuntimeState

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

runtime.coreGui = services.getService("CoreGui") :: CoreGui
runtime.workspace = services.getService("Workspace") :: Workspace -- where HapticEngine parents its effects
runtime.runService = services.getService("RunService") :: RunService
runtime.userInputService = services.getService("UserInputService") :: UserInputService
runtime.guiService = services.getService("GuiService") :: GuiService
runtime.localPlayer = (services.getService("Players") :: Players).LocalPlayer
runtime.tweenService = services.getService("TweenService") :: TweenService
runtime.httpService = services.getService("HttpService") :: HttpService
runtime.textService = services.getService("TextService") :: TextService
runtime.replicatedStorage = services.getService("ReplicatedStorage") :: ReplicatedStorage
runtime.localizationService = services.getService("LocalizationService") :: LocalizationService
runtime.guiContainer = if runtime.runService:IsStudio()
    then runtime.localPlayer.PlayerGui
    elseif gethui then gethui()
    else runtime.coreGui

return runtime
