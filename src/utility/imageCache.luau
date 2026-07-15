--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local filesystem = require(script.Parent.filesystem)
local path = require(script.Parent.path)
local variables = require(script.Parent.variables)
local constants = require(script.Parent.constants)

export type RewriteMap = { [number]: string }
export type CacheSettledCallback = (failed: number) -> ()
export type PreloadCallback = CacheSettledCallback
export type AvatarCallback = (uri: string) -> ()
export type OnCachedCallback = (id: number) -> ()
export type ThumbnailEntry = {
    state: string?,
    imageUrl: string?,
}
export type ThumbnailResponse = {
    data: { ThumbnailEntry }?,
}
export type ImageCache = {
    rewrites: RewriteMap,
    onCached: OnCachedCallback?,
    preload: (onSettled: PreloadCallback?) -> (boolean, number),
    avatar: (userId: unknown, onReady: AvatarCallback?) -> string,
}

local imageCache = {}

local cacheRoot = variables.fileSystemManager:getRootFolder()
local cacheFolder = variables.fileSystemManager:getAssetsFolder()
local assetResolver = variables.assetResolver

-- raw host, not the /blob/ page: that 302s and executors that dont follow redirects
-- would cache the redirect body instead of the png
local assetBase = "https://raw.githubusercontent.com/SiriusSoftwareLtd/rayfield-gen2/main/assets/"
local headshotPx = 48
local thumbEndpoint =
    "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%d&size=%dx%d&format=Png&isCircular=false"

local manifest: { [number]: string } = {}
for _, id in constants.icons do
    manifest[id] = assetBase .. tostring(id) .. ".png"
end
local manifestSize = 0
for _ in manifest do
    manifestSize += 1
end

imageCache.rewrites = {} :: RewriteMap
imageCache.onCached = nil :: OnCachedCallback? -- image sets this to rebind blank instances when a background download lands

local pngMagic = "\137PNG\r\n\26\n"

local function cacheFile(filePath: string, url: string): string?
    if type(getfenv().getcustomasset) ~= "function" then
        return nil
    end
    if not filesystem.isfile(filePath) then
        pcall(filesystem.ensureFolder, cacheRoot)
        pcall(filesystem.ensureFolder, cacheFolder)
        local body = assetResolver:getAssetContentFromUrl(url, filePath, false)
        -- never write a non-png body (error page, redirect html) to disk; a poisoned
        -- cache file would shadow the real asset on every later session
        if not body or string.sub(body, 1, 8) ~= pngMagic then
            return nil
        end
        if not pcall(filesystem.writefile, filePath, body) then
            return nil
        end
    end
    local ok, uri = pcall(getfenv().getcustomasset, filePath)
    return if ok and type(uri) == "string" then uri else nil
end

local function avatarPath(userId: number): string
    return path.join(cacheFolder, "avatar_" .. tostring(userId) .. ".png")
end

local function decodeThumbnailUrl(body: string): string?
    local decodeOk, parsed = pcall(function()
        return variables.httpService:JSONDecode(body)
    end)
    if not decodeOk or type(parsed) ~= "table" then
        return nil
    end

    local data = (parsed :: ThumbnailResponse).data
    if type(data) ~= "table" then
        return nil
    end

    local entry = data[1]
    if type(entry) ~= "table" then
        return nil
    end

    local thumbnail = entry :: ThumbnailEntry
    if thumbnail.state == "Completed" and type(thumbnail.imageUrl) == "string" then
        return thumbnail.imageUrl
    end

    return nil
end

local function fetchAvatar(userId: number): string?
    local cdnUrl: string? = nil
    for attempt = 1, 4 do
        -- retries must bypass the session cache or a cached "Pending" response wins forever
        local body = assetResolver:getAssetContentFromUrl(
            string.format(thumbEndpoint, userId, headshotPx, headshotPx),
            "avatar:" .. tostring(userId),
            attempt > 1
        )
        if body then
            local imageUrl = decodeThumbnailUrl(body)
            if imageUrl then
                cdnUrl = imageUrl
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

-- onSettled(failed) fires once every background download has finished, with the count that never
-- cached (a genuine failure), so callers can surface it without spamming per-icon.
function imageCache.preload(onSettled: PreloadCallback?): (boolean, number)
    local env = getfenv()
    if type(env.getcustomasset) ~= "function" then
        if onSettled then
            -- defer so a caller that assigns state right after calling preload still sees this
            task.defer(onSettled, manifestSize)
        end
        return false, manifestSize
    end

    local rewrites = imageCache.rewrites
    table.clear(rewrites) -- drop stale entries before remapping (no-op on the fixed built-in manifest)

    local function settle()
        if not onSettled then
            return
        end
        local failed = 0
        for id in manifest do
            if not rewrites[id] then
                failed += 1
            end
        end
        onSettled(failed)
    end

    local pending, missing = 0, 0
    local spawning = true -- keep a synchronously-finishing download from settling mid-loop
    for id, url in manifest do
        local filePath = path.join(cacheFolder, tostring(id) .. ".png")
        local uri: string? = nil
        if filesystem.isfile(filePath) then
            local ok, res = pcall(env.getcustomasset, filePath)
            uri = if ok and type(res) == "string" then res else nil
        end
        if uri then
            -- already on disk from a past session: use it right away
            rewrites[id] = uri
        else
            -- not cached yet: fetch it in the background and swap it in once it lands
            missing += 1
            pending += 1
            task.spawn(function()
                local cached = cacheFile(filePath, url)
                if cached then
                    rewrites[id] = cached
                    if imageCache.onCached then
                        imageCache.onCached(id)
                    end
                end
                pending -= 1
                if pending == 0 and not spawning then
                    settle()
                end
            end)
        end
    end

    spawning = false
    if pending == 0 then
        settle()
    end

    return missing == 0, missing
end

function imageCache.avatar(userId: unknown, onReady: AvatarCallback?): string
    if type(userId) ~= "number" then
        return ""
    end

    local filePath = avatarPath(userId)
    if filesystem.isfile(filePath) then
        local ok, uri = pcall(getfenv().getcustomasset, filePath)
        if ok and type(uri) == "string" then
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
