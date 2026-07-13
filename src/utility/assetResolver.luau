--!nocheck

local network = require(script.Parent.network)

export type AssetDownloadUrl = string
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
type assetResolver = {
    contentCache: { [number]: string }?,
    contentDownloadUrl: AssetDownloadUrl?,

    new: (useCache: boolean?, assetContentDownloadUrl: AssetDownloadUrl?) -> assetResolver,
    resolve: (self: assetResolver, value: any) -> string | number | nil,
    getAssetContentFromUrl: (
        self: assetResolver,
        url: string,
        cacheKey: number | string?,
        forced: boolean?
    ) -> string | nil,
    getAssetContentFromId: (self: assetResolver, id: number | string, forced: boolean?) -> string | nil,
}
-- example asset ids:
--[[
rbxassetid://12187277209,
rbxassetid://12187293441
]]

function assetResolver.new(useCache: boolean?, assetContentDownloadUrl: AssetDownloadUrl?): assetResolver
    return setmetatable({
        contentCache = useCache and {} or nil,
        contentDownloadUrl = assetContentDownloadUrl or assetResolver.Enum.AssetDownloadUrl.RobloxDownloadUrl,
    }, assetResolver)
end

function assetResolver:resolve(value)
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

function assetResolver:getAssetContentFromUrl(url: string, cacheKey: number | string?, forced: boolean?): string?
    if cacheKey ~= nil and self.contentCache then
        local cachedContent = self.contentCache[cacheKey :: any]
        if cachedContent then
            return cachedContent
        end
    end

    local requestFn = network.getRequestFn()
    if not requestFn then
        warn("No request function available to download asset content.")
        return nil
    end

    local success, response = pcall(requestFn, {
        Url = url,
        Method = "GET",
    })
    local content = nil
    if success and response and response.Body then
        content = response.Body
        if cacheKey ~= nil and self.contentCache then
            self.contentCache[cacheKey :: any] = content
        end
    elseif not forced then
        warn("Failed to download asset content for url: " .. tostring(url))
    end
    return content
end

function assetResolver:getAssetContentFromId(id, forced): string?
    id = self:resolve(id)
    -- we can only download content for valid asset ids
    if not id or type(id) ~= "number" then
        warn("Invalid asset id: " .. tostring(id))
        return nil
    end

    local downloadUrl = string.format(self.contentDownloadUrl, id)
    return self:getAssetContentFromUrl(downloadUrl, id, forced)
end

return assetResolver
