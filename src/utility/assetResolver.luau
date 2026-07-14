--!nonstrict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local network = require(script.Parent.network)
local log = require(script.Parent.log)

export type AssetId = number | string
export type AssetDownloadUrl = string
export type CacheKey = AssetId
export type ResolvedAsset = AssetId
export type AssetRequestPayload = {
    Url: string,
    Method: string,
}
export type AssetRequestResponse = {
    Body: string,
}
local assetResolver = {
    Enum = {
        AssetDownloadUrl = {
            RobloxDownloadUrl = "https://assetdelivery.roblox.com/v1/asset/?id=%d" :: AssetDownloadUrl,
            RoProxyDownloadUrl = "https://assetdelivery.roproxy.com/v1/asset?id=%d" :: AssetDownloadUrl,
        },
    },
}
assetResolver.__index = assetResolver
assetResolver.__type = "assetResolver"
type AssetResolverState = {
    contentCache: { [CacheKey]: string }?,
    contentDownloadUrl: AssetDownloadUrl,
}
export type AssetResolver = typeof(setmetatable({} :: AssetResolverState, assetResolver))
-- example asset ids:
--[[
rbxassetid://12187277209,
rbxassetid://12187293441
]]

function assetResolver.new(useCache: boolean?, assetContentDownloadUrl: AssetDownloadUrl?): AssetResolver
    local self = setmetatable(
        {
            contentCache = useCache and {} or nil,
            contentDownloadUrl = assetContentDownloadUrl or assetResolver.Enum.AssetDownloadUrl.RobloxDownloadUrl,
        } :: AssetResolverState,
        assetResolver
    )
    return self
end

function assetResolver:resolve(value: unknown): ResolvedAsset?
    if type(value) == "number" then
        return value
    end

    if type(value) ~= "string" then
        return nil
    end

    if string.sub(value, 1, 11) == "rbxasset://" or string.sub(value, 1, 11) == "rbxthumb://" then
        return value
    end

    local id = tonumber(string.match(value, "^rbxassetid://(%d+)$"))
    if id then
        return id
    end

    return nil
end

function assetResolver:getAssetContentFromUrl(url: string, cacheKey: CacheKey?, forced: boolean?): string?
    if cacheKey ~= nil and self.contentCache then
        local cachedContent = self.contentCache[cacheKey]
        if cachedContent then
            return cachedContent
        end
    end

    local requestFn = network.getRequestFn()
    if not requestFn then
        log.warn("No request function available to download asset content.")
        return nil
    end

    local success, response = pcall(
        requestFn,
        {
            Url = url,
            Method = "GET",
        } :: AssetRequestPayload
    )
    local content: string? = nil
    if success and type(response) == "table" then
        -- Executor request functions are untyped; only trust Body after checking the table shape.
        local responseBody = (response :: { Body: unknown }).Body
        if type(responseBody) == "string" then
            content = responseBody
        end
    end

    if content ~= nil then
        if cacheKey ~= nil and self.contentCache then
            self.contentCache[cacheKey] = content
        end
    elseif not forced then
        log.warn("Failed to download asset content for url: " .. tostring(url))
    end
    return content
end

function assetResolver:getAssetContentFromId(id: AssetId, forced: boolean?): string?
    local resolvedId = self:resolve(id)
    -- we can only download content for valid asset ids
    if not resolvedId or type(resolvedId) ~= "number" then
        log.warn("Invalid asset id: " .. tostring(resolvedId))
        return nil
    end

    local downloadUrl = string.format(self.contentDownloadUrl, resolvedId)
    return self:getAssetContentFromUrl(downloadUrl, resolvedId, forced)
end

return assetResolver
