--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local network = require(script.Parent.network)
local log = require(script.Parent.log)
local encoding = require(script.Parent.encoding)

export type AssetId = number | string
export type AssetDownloadUrl = string
export type CacheKey = AssetId
export type ResolvedAsset = AssetId
export type AssetRequestPayload = {
    Url: string,
    Method: string,
    Headers: { [string]: string }?,
    Body: string?,
}
export type AssetContentResult = {
    assetId: string?,
    content: string?,
    status: unknown?,
    error: unknown?,
    cacheStatus: unknown?,
    cacheHit: boolean?,
}

local assetResolver = {
    Enum = {
        AssetDownloadUrl = {
            AssetProxyDownloadUrl = "https://proxy.sirius.menu/assets/%s" :: AssetDownloadUrl,
            AssetProxyBatchDownloadUrl = "https://proxy.sirius.menu/assets/batch" :: AssetDownloadUrl,
            RobloxDownloadUrl = "https://assetdelivery.roblox.com/v1/asset/?id=%s" :: AssetDownloadUrl,
            RoProxyDownloadUrl = "https://assetdelivery.roproxy.com/v1/asset?id=%s" :: AssetDownloadUrl,
        },
    },
}
assetResolver.__index = assetResolver
assetResolver.__type = "assetResolver"

type AssetResolverState = {
    contentCache: { [CacheKey]: string }?,
    contentCacheOrder: { CacheKey }?,
    contentDownloadUrl: AssetDownloadUrl,
    batchContentDownloadUrl: AssetDownloadUrl,
}
export type AssetResolver = AssetResolverState & {
    resolve: (self: AssetResolver, value: unknown) -> ResolvedAsset?,
    getAssetContentFromUrl: (self: AssetResolver, url: string, cacheKey: CacheKey?, forced: boolean?) -> string?,
    getAssetContentFromId: (self: AssetResolver, id: AssetId, forced: boolean?) -> string?,
    getAssetContentsFromIds: (
        self: AssetResolver,
        ids: { AssetId },
        forced: boolean?
    ) -> { AssetContentResult },
}

local contentCacheLimit = 8
local batchLimit = 25
local secureHeaders = {
    ["X-Rayfield-Secure-Mode"] = "true",
}

function assetResolver.new(
    useCache: boolean?,
    assetContentDownloadUrl: AssetDownloadUrl?,
    batchAssetContentDownloadUrl: AssetDownloadUrl?
): AssetResolver
    local contentCache: { [CacheKey]: string }? = if useCache then {} else nil
    local self = setmetatable(
        {
            contentCache = contentCache,
            contentCacheOrder = if useCache then {} :: { CacheKey } else nil,
            contentDownloadUrl = assetContentDownloadUrl or assetResolver.Enum.AssetDownloadUrl.AssetProxyDownloadUrl,
            batchContentDownloadUrl = batchAssetContentDownloadUrl
                or assetResolver.Enum.AssetDownloadUrl.AssetProxyBatchDownloadUrl,
        } :: AssetResolverState,
        assetResolver
    ) :: any
    return self
end

function assetResolver.resolve(_self: AssetResolver, value: unknown): ResolvedAsset?
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

local function normalizeAssetId(value: AssetId): string?
    local decimal: string?
    if type(value) == "number" then
        if value ~= value or value == math.huge or value == -math.huge or value < 0 or value % 1 ~= 0 then
            return nil
        end
        decimal = string.format("%.0f", value)
    elseif type(value) == "string" then
        decimal = string.match(value, "^rbxassetid://(%d+)$") or string.match(value, "^(%d+)$")
    end

    if not decimal or #decimal == 0 or #decimal > 20 then
        return nil
    end
    return decimal
end

local function isGoodResponse(response: unknown): boolean
    if type(response) ~= "table" then
        return false
    end
    local shaped = response :: { Body: unknown, StatusCode: unknown, Success: unknown }
    local body = shaped.Body
    if type(body) ~= "string" or #body == 0 then
        return false
    end
    if type(shaped.StatusCode) == "number" then
        local statusCode = shaped.StatusCode :: number
        return statusCode >= 200 and statusCode < 300
    end
    if type(shaped.Success) == "boolean" then
        return shaped.Success :: boolean
    end
    return false
end

local function cacheContent(self: AssetResolver, cacheKey: CacheKey, body: string)
    local contentCache = self.contentCache
    if not contentCache or #body == 0 then
        return
    end

    local order = self.contentCacheOrder
    if order and contentCache[cacheKey] == nil then
        table.insert(order, cacheKey)
        local oldest = if #order > contentCacheLimit then table.remove(order, 1) else nil
        if oldest ~= nil then
            contentCache[oldest] = nil
        end
    end
    contentCache[cacheKey] = body
end

local function request(payload: AssetRequestPayload): unknown?
    local requestFn = network.getRequestFn()
    if not requestFn then
        log.warn("No request function available to download asset content.")
        return nil
    end

    local success, response = pcall(requestFn, payload)
    return if success then response else nil
end

function assetResolver.getAssetContentFromUrl(
    self: AssetResolver,
    url: string,
    cacheKey: CacheKey?,
    forced: boolean?
): string?
    local contentCache = self.contentCache
    if cacheKey ~= nil and contentCache and not forced then
        local cachedContent = contentCache[cacheKey]
        if cachedContent then
            return cachedContent
        end
    end

    local response = request({
        Url = url,
        Method = "GET",
    })
    if isGoodResponse(response) then
        local body = (response :: { Body: string }).Body
        if cacheKey ~= nil then
            cacheContent(self, cacheKey, body)
        end
        return body
    elseif not forced then
        log.warn("Failed to download asset content for url: " .. tostring(url))
    end
    return nil
end

function assetResolver.getAssetContentFromId(self: AssetResolver, id: AssetId, forced: boolean?): string?
    local normalizedId = normalizeAssetId(id)
    if not normalizedId then
        log.warn("Invalid asset id: " .. tostring(id))
        return nil
    end

    local contentCache = self.contentCache
    if contentCache and not forced then
        local cachedContent = contentCache[normalizedId]
        if cachedContent then
            return cachedContent
        end
    end

    local url = string.format(self.contentDownloadUrl, normalizedId)
    local response = request({
        Url = url,
        Method = "GET",
        Headers = secureHeaders,
    })
    if isGoodResponse(response) then
        local body = (response :: { Body: string }).Body
        cacheContent(self, normalizedId, body)
        return body
    elseif not forced then
        log.warn("Failed to download asset content for url: " .. url)
    end
    return nil
end

function assetResolver.getAssetContentsFromIds(
    self: AssetResolver,
    ids: { AssetId },
    forced: boolean?
): { AssetContentResult }
    local results: { AssetContentResult } = {}
    local pendingIds: { string } = {}
    local pendingIndexes: { [string]: { number } } = {}
    local contentCache = self.contentCache

    for index, id in ipairs(ids) do
        local normalizedId = normalizeAssetId(id)
        if not normalizedId then
            results[index] = {
                error = "Invalid asset id",
            }
        elseif contentCache and not forced and contentCache[normalizedId] then
            results[index] = {
                assetId = normalizedId,
                content = contentCache[normalizedId],
                cacheStatus = "session",
                cacheHit = true,
            }
        else
            results[index] = {
                assetId = normalizedId,
            }
            local indexes = pendingIndexes[normalizedId]
            if indexes then
                table.insert(indexes, index)
            else
                table.insert(pendingIds, normalizedId)
                pendingIndexes[normalizedId] = { index }
            end
        end
    end

    for chunkStart = 1, #pendingIds, batchLimit do
        local chunk = {}
        for index = chunkStart, math.min(chunkStart + batchLimit - 1, #pendingIds) do
            table.insert(chunk, pendingIds[index])
        end

        local body = encoding.json.encode({ assetIds = chunk })
        local response = if body
            then request({
                Url = self.batchContentDownloadUrl,
                Method = "POST",
                Headers = secureHeaders,
                Body = body,
            })
            else nil
        local decoded: any = nil
        if isGoodResponse(response) then
            decoded = encoding.json.decode((response :: { Body: string }).Body)
        end
        local items = if type(decoded) == "table" then decoded.results or decoded.data or decoded else nil

        for chunkIndex, normalizedId in ipairs(chunk) do
            local item = if type(items) == "table" then items[chunkIndex] else nil
            local content = if type(item) == "table" then encoding.base64.decode(item.dataBase64) else nil
            local itemStatus = if type(item) == "table" then item.status else nil
            local itemSucceeded = type(item) == "table"
                and item.error == nil
                and (
                    itemStatus == nil
                    or (type(itemStatus) == "number" and itemStatus >= 200 and itemStatus < 300)
                    or itemStatus == "ok"
                    or itemStatus == "success"
                )
            local result: AssetContentResult = {
                assetId = normalizedId,
                status = itemStatus,
                error = if type(item) == "table" then item.error else "Invalid batch response",
                cacheStatus = if type(item) == "table" then item.cacheStatus else nil,
                cacheHit = if type(item) == "table" and type(item.cacheHit) == "boolean" then item.cacheHit else nil,
            }
            if itemSucceeded and content and #content > 0 then
                result.content = content
                cacheContent(self, normalizedId, content)
            elseif result.error == nil then
                result.error = "Missing or invalid asset data"
            end

            for _, originalIndex in ipairs(pendingIndexes[normalizedId]) do
                results[originalIndex] = table.clone(result)
            end
        end
    end

    return results
end

return assetResolver
