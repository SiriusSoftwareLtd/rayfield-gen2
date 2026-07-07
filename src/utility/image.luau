--!nocheck

local filesystem = require(script.Parent.filesystem)
local variables = require(script.Parent.variables)

local image = {}

local CACHE_ROOT = "Rayfield"
local CACHE_FOLDER = CACHE_ROOT .. "/Assets"

local ASSET_BASE = "https://github.com/SiriusSoftwareLtd/rayfield-gen2/blob/main/assets/"

local MANIFEST = {
    [5587865193] = ASSET_BASE .. "5587865193.png?raw=true", -- window shadow + stat glow
    [111263549366178] = ASSET_BASE .. "111263549366178.png?raw=true", -- loading banner
    [83277910885129] = ASSET_BASE .. "83277910885129.png?raw=true", -- close action
    [108115485663409] = ASSET_BASE .. "108115485663409.png?raw=true", -- minimise action
    [129180860773723] = ASSET_BASE .. "129180860773723.png?raw=true", -- settings action
    [100604009889706] = ASSET_BASE .. "100604009889706.png?raw=true", -- search action
}

local IMAGE_PROPERTIES = {
    Image = true,
    HoverImage = true,
    PressedImage = true,
}

image.rewrites = {}
image.onBlock = nil

local env = getfenv()

local function blocked(value)
    if image.onBlock then
        image.onBlock(value)
    end
    return ""
end

local function ensureFolder(path)
    if not filesystem.isfolder(path) then
        filesystem.makefolder(path)
    end
end

local function getRequestFn()
    return env.request
        or env.http_request
        or (env.http and env.http.request)
        or (env.syn and env.syn.request)
        or (env.fluxus and env.fluxus.request)
end

function image.preload()
    if type(env.getcustomasset) ~= "function" then
        return false
    end

    pcall(ensureFolder, CACHE_ROOT)
    pcall(ensureFolder, CACHE_FOLDER)

    local httpRequest = getRequestFn()
    local downloaded = {}
    local pending = 0
    local errors = 0

    for id, url in MANIFEST do
        local path = CACHE_FOLDER .. "/" .. id .. ".png"
        if filesystem.isfile(path) then
            downloaded[id] = path
        elseif not httpRequest then
            errors += 1
        else
            pending += 1
            task.spawn(function()
                local ok, body = pcall(function()
                    local res = httpRequest({ Url = url, Method = "GET" })
                    return res and res.Body
                end)
                if ok and body and pcall(filesystem.writefile, path, body) then
                    downloaded[id] = path
                else
                    errors += 1
                end
                pending -= 1
            end)
        end
    end

    -- bound the wait so a hung request cant block window creation forever
    local deadline = os.clock() + 10
    while pending > 0 and os.clock() < deadline do
        task.wait(0.05)
    end

    local mapped = {}
    for id, path in downloaded do
        local ok, uri = pcall(env.getcustomasset, path)
        if ok and uri then
            mapped[id] = uri
        else
            errors += 1
        end
    end

    image.rewrites = mapped
    return errors == 0
end

function image.assign(instance, property, value)
    if IMAGE_PROPERTIES[property] then
        instance[property] = image.resolve(value)
    else
        instance[property] = value
    end
end

function image.resolve(value)
    if value == nil or value == 0 or value == "" then
        return ""
    end

    if
        type(value) == "string"
        and (string.sub(value, 1, 11) == "rbxasset://" or string.sub(value, 1, 11) == "rbxthumb://")
    then
        return value
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
