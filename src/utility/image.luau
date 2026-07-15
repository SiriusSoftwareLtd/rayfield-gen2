--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local imageCache = require(script.Parent.imageCache)
local variables = require(script.Parent.variables)

type AvatarCallback = imageCache.AvatarCallback
type PreloadCallback = imageCache.PreloadCallback

local image = {}

image.rewrites = imageCache.rewrites
image.onBlock = nil :: ((unknown) -> ())?

-- images that resolve blank in secure mode (their icon isnt cached yet) register here, so the real
-- texture can be dropped in once the background download lands instead of leaving a blank
type PendingImage = {
    instance: Instance,
    property: string,
}

image.pending = {} :: { [number]: { PendingImage } }

local imageProperties: { [string]: boolean } = {
    Image = true,
    HoverImage = true,
    PressedImage = true,
}

local function idOf(value: unknown): number?
    if type(value) == "number" then
        return value
    elseif type(value) == "string" then
        return tonumber(string.match(value, "^rbxassetid://(%d+)$"))
    end
    return nil
end

local function blocked(value: unknown): string
    if image.onBlock then
        image.onBlock(value)
    end
    return ""
end

function image.preload(onSettled: PreloadCallback?): (boolean, number)
    return imageCache.preload(function(failed)
        -- ids that never cached will never fire onCached; drop their pending lists so they
        -- dont grow all session and pin destroyed instances
        for id in image.pending do
            if not image.rewrites[id] then
                image.pending[id] = nil
            end
        end
        if onSettled then
            onSettled(failed)
        end
    end)
end

function image.avatar(userId: number, onReady: AvatarCallback?): string
    if not variables.secureMode then
        return `rbxthumb://type=AvatarHeadShot&id={userId}&w=48&h=48`
    end

    return imageCache.avatar(userId, onReady)
end

function image.assign(instance: Instance, property: string, value: unknown)
    local target = instance :: any
    if not imageProperties[property] then
        target[property] = value
        return
    end
    target[property] = image.resolve(value)
    -- in secure mode an un-cached icon resolves blank; remember it so it appears once cached
    if variables.secureMode then
        local id = idOf(value)
        if id and not image.rewrites[id] then
            local list = image.pending[id]
            if not list then
                list = {}
                image.pending[id] = list
            end
            table.insert(list, { instance = instance, property = property })
        end
    end
end

-- imageCache calls this when a background icon download lands: drop the real texture into every
-- instance that resolved blank waiting for it
imageCache.onCached = function(id: number)
    local list = image.pending[id]
    if not list then
        return
    end
    local uri = image.rewrites[id]
    for _, entry in list do
        if uri and entry.instance and entry.instance.Parent then
            local target = entry.instance :: any
            target[entry.property] = uri
        end
    end
    image.pending[id] = nil
end

function image.resolve(value: unknown): string
    if value == nil or value == 0 or value == "" then
        return ""
    end

    if type(value) == "string" then
        if string.sub(value, 1, 11) == "rbxasset://" then
            return value
        end
        if string.sub(value, 1, 11) == "rbxthumb://" then
            return if variables.secureMode then blocked(value) else value
        end
    end

    local id: number? = nil
    if type(value) == "number" then
        id = value
    elseif type(value) == "string" then
        id = tonumber(string.match(value, "^rbxassetid://(%d+)$"))
    end

    local rewrite = if id then image.rewrites[id] else nil
    if rewrite then
        return rewrite
    end

    if variables.secureMode then
        return blocked(value)
    end

    if type(value) == "number" then
        return "rbxassetid://" .. value
    end
    if type(value) == "string" then
        return value
    end

    return blocked(value)
end

return image
