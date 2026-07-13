--!nocheck

local filesystem = require(script.Parent.filesystem)
local path = require(script.Parent.path)
local variables = require(script.Parent.variables)
local constants = require(script.Parent.constants)

local imageCache = {}

local cacheRoot = variables.fileSystemManager:getRootFolder()
local cacheFolder = variables.fileSystemManager:getAssetsFolder()
local assetResolver = variables.assetResolver

local assetBase = "https://github.com/SiriusSoftwareLtd/rayfield-gen2/blob/main/assets/"
local headshotPx = 48
local thumbEndpoint =
    "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%d&size=%dx%d&format=Png&isCircular=false"

local manifest = {}
for _, id in constants.icons do
    manifest[id] = assetBase .. id .. ".png?raw=true"
end
local manifestSize = 0
for _ in manifest do
    manifestSize += 1
end

imageCache.rewrites = {}

local function cacheFile(filePath, url)
    if type(getfenv().getcustomasset) ~= "function" then
        return nil
    end
    if not filesystem.isfile(filePath) then
        pcall(filesystem.ensureFolder, cacheRoot)
        pcall(filesystem.ensureFolder, cacheFolder)
        local body = assetResolver:getAssetContentFromUrl(url, filePath, false)
        if not body or not pcall(filesystem.writefile, filePath, body) then
            return nil
        end
    end
    local ok, uri = pcall(getfenv().getcustomasset, filePath)
    return ok and uri or nil
end

local function avatarPath(userId)
    return path.join(cacheFolder, "avatar_" .. tostring(userId) .. ".png")
end

local function fetchAvatar(userId)
    local cdnUrl
    for _ = 1, 4 do
        local body = assetResolver:getAssetContentFromUrl(
            string.format(thumbEndpoint, userId, headshotPx, headshotPx),
            "avatar:" .. tostring(userId),
            false
        )
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

function imageCache.preload()
    local env = getfenv()
    if type(env.getcustomasset) ~= "function" then
        return false, manifestSize
    end

    local rewrites = imageCache.rewrites
    for key in rewrites do
        rewrites[key] = nil
    end

    local pending = 0
    for id, url in manifest do
        pending += 1
        task.spawn(function()
            rewrites[id] = cacheFile(path.join(cacheFolder, id .. ".png"), url)
            pending -= 1
        end)
    end

    local deadline = os.clock() + 10
    while pending > 0 and os.clock() < deadline do
        task.wait(0.05)
    end

    local cached = 0
    for _ in rewrites do
        cached += 1
    end
    return cached == manifestSize, manifestSize - cached
end

function imageCache.avatar(userId, onReady)
    if type(userId) ~= "number" then
        return ""
    end

    local filePath = avatarPath(userId)
    if filesystem.isfile(filePath) then
        local ok, uri = pcall(getfenv().getcustomasset, filePath)
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

return imageCache
