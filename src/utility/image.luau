--!nocheck

local filesystem = require(script.Parent.filesystem)
local variables = require(script.Parent.variables)
local constants = require(script.Parent.constants)

local image = {}

local cacheRoot = "Rayfield"
local cacheFolder = cacheRoot .. "/Assets"

local assetBase = "https://github.com/SiriusSoftwareLtd/rayfield-gen2/blob/main/assets/"

-- Headshots come in a fixed size ladder (30, 48, 60, ...); 48 is the smallest above the 32px
-- avatar, so it downscales crisp instead of upscaling soft. Both the rbxthumb id and the web API
-- read from here so the two paths always request the same size.
local headshotPx = 48

-- Thumbnail web API: give it a user id, it returns json pointing at the headshot png on the cdn.
-- Secure mode fetches that so a headshot can live as a local file instead of an rbxthumb:// id.
local thumbEndpoint =
    "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%d&size=%dx%d&format=Png&isCircular=false"

-- Built straight from the built-in icon list so it can never drift: every id there gets a
-- cache entry, keyed by id -> download url. Shared ids (e.g. dot + colorpicker) collapse to one.
local manifest = {}
for _, id in constants.icons do
    manifest[id] = assetBase .. id .. ".png?raw=true"
end
local manifestSize = 0
for _ in manifest do
    manifestSize += 1
end

local imageProperties = {
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

-- One GET through whatever request function the executor exposes. Returns the body string, or
-- nil if there's no request fn, the call throws, or the body comes back empty.
local function httpGet(url)
    local httpRequest = getRequestFn()
    if not httpRequest then
        return nil
    end
    local ok, res = pcall(httpRequest, { Url = url, Method = "GET" })
    if ok and type(res) == "table" and type(res.Body) == "string" and #res.Body > 0 then
        return res.Body
    end
    return nil
end

-- The one funnel every cached asset goes through: download url into path (skipped if it's already
-- on disk) and hand back its getcustomasset uri, or nil on any failure.
local function cacheFile(path, url)
    if type(env.getcustomasset) ~= "function" then
        return nil
    end
    if not filesystem.isfile(path) then
        pcall(ensureFolder, cacheRoot)
        pcall(ensureFolder, cacheFolder)
        local body = httpGet(url)
        if not body or not pcall(filesystem.writefile, path, body) then
            return nil
        end
    end
    local ok, uri = pcall(env.getcustomasset, path)
    return ok and uri or nil
end

function image.preload()
    if type(env.getcustomasset) ~= "function" then
        -- no local caching here, so every secureMode asset resolves blank
        return false, manifestSize
    end

    local mapped = {}
    local pending = 0
    for id, url in manifest do
        pending += 1
        task.spawn(function()
            mapped[id] = cacheFile(cacheFolder .. "/" .. id .. ".png", url)
            pending -= 1
        end)
    end

    -- bound the wait so a hung request cant block window creation forever
    local deadline = os.clock() + 10
    while pending > 0 and os.clock() < deadline do
        task.wait(0.05)
    end

    image.rewrites = mapped

    -- whatever reached the cache by now counts; the rest are the failures callers warn about
    local cached = 0
    for _ in mapped do
        cached += 1
    end
    return cached == manifestSize, manifestSize - cached
end

local function avatarPath(userId)
    return cacheFolder .. "/avatar_" .. tostring(userId) .. ".png"
end

-- Resolve a user's headshot to a cdn png url via the thumbnail api, then cache it like any other
-- asset. Returns the local uri or nil. Runs off the caller's thread.
local function fetchAvatar(userId)
    -- roblox can report the thumbnail as "Pending" while it renders, so give it a few tries
    local cdnUrl
    for _ = 1, 4 do
        local body = httpGet(string.format(thumbEndpoint, userId, headshotPx, headshotPx))
        if body then
            local decodeOk, parsed = pcall(function()
                return variables.httpService:JSONDecode(body)
            end)
            local entry = decodeOk and parsed and parsed.data and parsed.data[1]
            if entry and entry.state == "Completed" and type(entry.imageUrl) == "string" then
                cdnUrl = entry.imageUrl
                break
            end
        end
        task.wait(0.3)
    end
    if not cdnUrl then
        return nil
    end

    return cacheFile(avatarPath(userId), cdnUrl)
end

-- Ready-to-use image for a user's headshot. Outside secure mode this is the rbxthumb id. In
-- secure mode it's a locally cached file so nothing remote (or probe-able) ever loads: the cached
-- uri comes back straight away if it exists, otherwise "" now and the real uri to onReady once the
-- download lands.
function image.avatar(userId, onReady)
    if type(userId) ~= "number" then
        return ""
    end

    if not variables.secureMode then
        return `rbxthumb://type=AvatarHeadShot&id={userId}&w={headshotPx}&h={headshotPx}`
    end

    local path = avatarPath(userId)
    if filesystem.isfile(path) then
        local ok, uri = pcall(env.getcustomasset, path)
        if ok and uri then
            return uri
        end
    end

    if onReady then
        task.spawn(function()
            local uri = fetchAvatar(userId)
            if uri then
                onReady(uri)
            end
        end)
    end
    return ""
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
        -- rbxasset:// is a local file (our getcustomasset cache) or a built-in client texture,
        -- never a probe-able marketplace id, so it's always safe to reference.
        if string.sub(value, 1, 11) == "rbxasset://" then
            return value
        end
        -- rbxthumb:// fetches from the thumbnail CDN by id, so ContentProvider:GetAssetFetchStatus
        -- can watch it load. Fine normally; in secure mode we block it like any other remote asset
        -- so nothing loadable can be tied back to us.
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
