--!nocheck

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local runtime = require(script.Parent.runtime)
local constants = require(script.Parent.constants)
local fileSystemManager = require(script.Parent.filesystemManager)
local assetResolver = require(script.Parent.assetResolver)
local fontManager = require(script.Parent.fontManager)

local variables = table.clone(runtime)

-- built-in stand-in shown in secure mode until the real brand faces download. a dev can override
-- it per window with the FallbackFont prop (see setFallbackFont); defaults to BuilderSans.
variables.fallbackFont = Font.fromEnum(Enum.Font.BuilderSans)

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
        fallbackFont = variables.fallbackFont,
    }
)

-- let a dev pick the stand-in font, as an Enum.Font or a ready Font. keeps the font managers
-- own fallback in step so the swap check in init still lines up.
function variables.setFallbackFont(font)
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
function variables.brandFont(weight)
    if variables.secureMode then
        return Font.new(variables.fallbackFont.Family, weight)
    end
    return Font.new(constants.fontAsset, weight)
end

return variables
