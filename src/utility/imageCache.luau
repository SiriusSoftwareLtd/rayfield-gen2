--!nocheck

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local filesystem = require(script.Parent.filesystem)
local path = require(script.Parent.path)
local variables = require(script.Parent.variables)
local constants = require(script.Parent.constants)

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

local manifest = {}
for _, id in constants.icons do
    manifest[id] = assetBase .. id .. ".png"
end
local manifestSize = 0
for _ in manifest do
    manifestSize += 1
end

imageCache.rewrites = {}
imageCache.onCached = nil -- image sets this to rebind blank instances when a background download lands

local pngMagic = "\137PNG\r\n\26\n"

local function cacheFile(filePath, url)
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
    return ok and uri or nil
end

local function avatarPath(userId)
    return path.join(cacheFolder, "avatar_" .. tostring(userId) .. ".png")
end

local function fetchAvatar(userId)
    local cdnUrl
    for attempt = 1, 4 do
        -- retries must bypass the session cache or a cached "Pending" response wins forever
        local body = assetResolver:getAssetContentFromUrl(
            string.format(thumbEndpoint, userId, headshotPx, headshotPx),
            "avatar:" .. tostring(userId),
            attempt > 1
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

-- onSettled(failed) fires once every background download has finished, with the count that never
-- cached (a genuine failure), so callers can surface it without spamming per-icon.
function imageCache.preload(onSettled)
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
        local filePath = path.join(cacheFolder, id .. ".png")
        local uri
        if filesystem.isfile(filePath) then
            local ok, res = pcall(env.getcustomasset, filePath)
            uri = ok and res or nil
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
