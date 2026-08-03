--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local runtime = require(script.Parent.runtime)
local motion = require(script.Parent.motion)
local constants = require(script.Parent.constants)
local log = require(script.Parent.log)
local fileSystemManager = require(script.Parent.filesystemManager)
local assetResolver = require(script.Parent.assetResolver)
local fontManager = require(script.Parent.fontManager)

type RuntimeState = runtime.RuntimeState
type FileSystemManager = fileSystemManager.FileSystemManager
type AssetResolver = assetResolver.AssetResolver
type FontManager = fontManager.FontManager

export type VariablesState = RuntimeState & {
    fallbackFont: Font,
    fileSystemManager: FileSystemManager,
    assetResolver: AssetResolver,
    fontManager: FontManager,
    setFallbackFont: (font: Enum.Font | Font) -> (),
    brandFont: (weight: Enum.FontWeight?) -> Font,
}

local variables = table.clone(runtime) :: VariablesState

-- Every animation in the library is created through this one handle, so scaling the duration
-- here is what lets a single speed setting reach all of them without each of the hundred or so
-- call sites having to know it exists. Create is the only method any of them use; anything else
-- falls through to the real service untouched.
local realTweenService = runtime.tweenService
variables.tweenService = setmetatable({
    Create = function(_, instance: Instance, info: TweenInfo, goals: { [string]: any })
        return realTweenService:Create(instance, motion.info(info), goals)
    end,
}, {
    __index = function(_, key)
        local value = (realTweenService :: any)[key]
        if type(value) == "function" then
            return function(_, ...)
                return value(realTweenService, ...)
            end
        end
        return value
    end,
}) :: any
log.setSecureModeSource(function()
    return variables.secureMode
end)

-- built-in stand-in shown in secure mode until the real brand faces download. a dev can override
-- it per window with the FallbackFont prop (see setFallbackFont); defaults to BuilderSans.
variables.fallbackFont = Font.fromEnum(Enum.Font.BuilderSans)

variables.fileSystemManager = fileSystemManager.new()
variables.assetResolver =
    assetResolver.new(true, assetResolver.Enum.AssetDownloadUrl.RoProxyDownloadUrl) :: AssetResolver
variables.fontManager = fontManager.new(
    variables.fileSystemManager:getAssetsFolder("fonts"),
    false,
    true,
    assetResolver.Enum.AssetDownloadUrl.RoProxyDownloadUrl,
    {
        saveToDisk = true,
        skipCache = false,
        fallbackFont = variables.fallbackFont,
    }
) :: FontManager

-- let a dev pick the stand-in font, as an Enum.Font or a ready Font. keeps the font managers
-- own fallback in step so the swap check in init still lines up.
function variables.setFallbackFont(font: Enum.Font | Font)
    if typeof(font) == "EnumItem" then
        font = Font.fromEnum(font)
    end
    if typeof(font) == "Font" then
        variables.fallbackFont = font
        variables.fontManager.defaultOptions.fallbackFont = font
    end
end

-- brand font at a weight, non-blocking. normal mode streams the family id direct; secure mode
-- shows the fallback until the real faces download and swap in (see init).
function variables.brandFont(weight: Enum.FontWeight?): Font
    if variables.secureMode then
        return Font.new(variables.fallbackFont.Family, weight)
    end
    return Font.new(constants.fontAsset, weight)
end

return variables
