--!nocheck

local imageCache = require(script.Parent.imageCache)
local variables = require(script.Parent.variables)

local image = {}

image.rewrites = imageCache.rewrites
image.onBlock = nil

local imageProperties = {
    Image = true,
    HoverImage = true,
    PressedImage = true,
}

local function blocked(value)
    if image.onBlock then
        image.onBlock(value)
    end
    return ""
end

function image.preload()
    return imageCache.preload()
end

function image.avatar(userId, onReady)
    if not variables.secureMode then
        return `rbxthumb://type=AvatarHeadShot&id={userId}&w=48&h=48`
    end

    return imageCache.avatar(userId, onReady)
end

function image.assign(instance, property, value)
    if imageProperties[property] then
        instance[property] = image.resolve(value)
    else
        instance[property] = value
    end
end

function image.resolve(value)
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

    local id
    if type(value) == "number" then
        id = value
    elseif type(value) == "string" then
        id = tonumber(string.match(value, "^rbxassetid://(%d+)$"))
    end

    if id and image.rewrites[id] then
        return image.rewrites[id]
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
