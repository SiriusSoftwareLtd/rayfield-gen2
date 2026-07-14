--!nocheck

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local services = require(script.Parent.services)
local httpService = services.getService("HttpService")
local runService = services.getService("RunService")
local fileSystem = require(script.Parent.filesystem)
local assetResolver = require(script.Parent.assetResolver)
local log = require(script.Parent.log)

local function jsonEncode(data)
    local success, result = pcall(function()
        return httpService:JSONEncode(data)
    end)
    if success then
        return result
    else
        log.warn("Failed to encode JSON:", result)
        return nil
    end
end

local function jsonDecode(jsonString)
    local success, result = pcall(function()
        return httpService:JSONDecode(jsonString)
    end)
    if success then
        return result
    else
        log.warn("Failed to decode JSON:", result)
        return nil
    end
end

local fontManager = {}
fontManager.__type = "fontManager"

type FontFace = {
    name: string,
    family: string,
    weight: number,
    style: string,
    assetId: string,
}

type FontManifest = {
    name: string,
    faces: { FontFace },
}

type CachedFont = {
    customId: string,
    manifest: FontManifest,
    loadedFromDisk: boolean,
    variants: { [string]: Font },
}

export type FontResolverOptions = {
    fallbackFont: Font?,
    saveToDisk: boolean?,
    skipCache: boolean?,
}
export type fontManager = {
    _debug: boolean,
    rootFolder: string,
    assetResolver: assetResolver,
    defaultOptions: FontResolverOptions,
    fontCache: { [number]: CachedFont }?,
    new: (
        rootFolder: string,
        useDebug: boolean?,
        useCache: boolean?,
        assetContentDownloadUrl: assetContentDownloadUrl?,
        defaultOptions: FontResolverOptions?
    ) -> fontManager,
    resolve: (self: fontManager, id: number | string) -> Font?,
    loadFont: (
        id: (number | string)?,
        fontWeight: Enum.FontWeight?,
        fontStyle: Enum.FontStyle?,
        saveToDisk: boolean?,
        skipCache: boolean?
    ) -> Font?,
    getFontFromId: (self: fontManager, id: number | string) -> Font?,
}

--local DEFAULT_FALLBACK_FONT = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)

local env = getfenv()

local function variantKey(fontWeight: Enum.FontWeight, fontStyle: Enum.FontStyle): string
    return tostring(fontWeight) .. "|" .. tostring(fontStyle)
end

local function resolveId(id: number | string): number?
    if type(id) == "number" then
        return id
    end

    if type(id) == "string" then
        return tonumber(id)
    end

    return nil
end

function fontManager.__index(self, key)
    local classMember = fontManager[key]
    if classMember ~= nil then
        return classMember
    end

    local resolvedId = resolveId(key)
    if not resolvedId then
        return nil
    end

    if self.fontCache then
        local cached = self.fontCache[resolvedId]
        if cached then
            local regularKey = variantKey(Enum.FontWeight.Regular, Enum.FontStyle.Normal)
            local regularFont = cached.variants and cached.variants[regularKey]
            if regularFont then
                return regularFont
            end

            for _, font in pairs(cached.variants or {}) do
                return font
            end
        end
    end

    return nil
end

function fontManager.new(
    rootFolder: string,
    useDebug: boolean?,
    useCache: boolean?,
    assetContentDownloadUrl: assetContentDownloadUrl?,
    defaultOptions: FontResolverOptions?
): fontManager
    local self = setmetatable({}, fontManager)
    self.rootFolder = rootFolder
    fileSystem.ensureFolder(rootFolder)
    self.fontCache = useCache and {} or nil
    self.assetResolver = assetResolver.new(useCache, assetContentDownloadUrl)
    self.defaultOptions = defaultOptions
        or {
            saveToDisk = true,
            skipCache = not useCache or false,
            fallbackFont = Font.fromEnum(Enum.Font.SourceSans),
        }
    self._debug = useDebug or runService:IsStudio() or false
    return self
end

function fontManager:loadFont(
    id: (number | string)?,
    fontWeight: Enum.FontWeight?,
    fontStyle: Enum.FontStyle?,
    saveToDisk: boolean?,
    skipCache: boolean?
): Font?
    if saveToDisk == nil then
        saveToDisk = self.defaultOptions.saveToDisk
    end
    if skipCache == nil then
        skipCache = self.defaultOptions.skipCache
    end
    fontWeight = fontWeight or Enum.FontWeight.Regular
    fontStyle = fontStyle or Enum.FontStyle.Normal
    local cacheKey = variantKey(fontWeight, fontStyle)
    local rawId = self.assetResolver:resolve(id)
    local resolvedId = resolveId(rawId)
    if not resolvedId then
        log.warn("Invalid font id: " .. tostring(id))
        return self.defaultOptions.fallbackFont
    end
    -- if the font is already cached, return it
    if self.fontCache and not skipCache then
        local cachedFont = self.fontCache[resolvedId]
        if cachedFont then
            local cachedVariant = cachedFont.variants and cachedFont.variants[cacheKey]
            if cachedVariant then
                if self._debug then
                    log.print("Loaded font from cache for id: " .. tostring(resolvedId))
                end
                return cachedVariant
            end

            local ok, loadedFont = pcall(Font.new, cachedFont.customId, fontWeight, fontStyle)
            if ok and loadedFont then
                cachedFont.variants = cachedFont.variants or {}
                cachedFont.variants[cacheKey] = loadedFont
                if self._debug then
                    log.print("Loaded font variant from cache for id: " .. tostring(resolvedId))
                end
                return loadedFont
            else
                if self._debug then
                    log.warn("Failed to load font from cache for id: " .. tostring(resolvedId))
                end
                self.fontCache[resolvedId] = nil
                return self.defaultOptions.fallbackFont
            end
        end
    end

    -- if saveToDisk is false, we cannot load the font from disk, so we return the default font
    if not saveToDisk then
        if self._debug then
            log.warn("Font loading without saving to disk can be detected by Anti-cheats.")
        end

        return self.defaultOptions.fallbackFont
    end

    -- if the font is not cached, we need to load it from the asset resolver
    local manifestPath = self.rootFolder .. "/" .. resolvedId .. ".json"
    local possibleFontManifest: string? = nil
    if runService:IsStudio() and self._debug then
        log.warn("Font manifest loading is not supported in Studio. Using default font manifest for testing.")
        possibleFontManifest =
            '{"name":"Inter","faces":[{"name":"Thin","weight":100,"style":"normal","assetId":"rbxassetid://12187277209"},{"name":"Extra Light","weight":200,"style":"normal","assetId":"rbxassetid://12187293441"},{"name":"Light","weight":300,"style":"normal","assetId":"rbxassetid://12187268450"},{"name":"Regular","weight":400,"style":"normal","assetId":"rbxassetid://12187266066"},{"name":"Medium","weight":500,"style":"normal","assetId":"rbxassetid://12187336822"},{"name":"Semi Bold","weight":600,"style":"normal","assetId":"rbxassetid://12187254443"},{"name":"Bold","weight":700,"style":"normal","assetId":"rbxassetid://12187275575"},{"name":"Extra Bold","weight":800,"style":"normal","assetId":"rbxassetid://12187267750"},{"name":"Black","weight":900,"style":"normal","assetId":"rbxassetid://12187359223"}]}'
    elseif fileSystem.isfile(manifestPath) then
        local ok, contents = pcall(fileSystem.readfile, manifestPath)
        possibleFontManifest = ok and contents or nil
    else
        possibleFontManifest = self.assetResolver:getAssetContentFromId(resolvedId, false)
        if possibleFontManifest then
            pcall(fileSystem.writefile, manifestPath, possibleFontManifest)
        end
    end
    local fontManifest: FontManifest? = nil
    if possibleFontManifest then
        local ok, parsedManifest = pcall(jsonDecode, possibleFontManifest)
        if ok and parsedManifest then
            fontManifest = parsedManifest
        else
            if self._debug then
                log.warn(
                    "Failed to parse font manifest for font id: "
                        .. tostring(resolvedId)
                        .. ". Error: "
                        .. tostring(parsedManifest)
                )
            end
        end
    else
        return self.defaultOptions.fallbackFont
    end
    if not fontManifest then
        if self._debug then
            log.warn("Font manifest is nil for font id: " .. tostring(resolvedId))
        end
        return self.defaultOptions.fallbackFont
    end
    local fontDirectory = self.rootFolder .. "/" .. fontManifest.name
    local madeAllFontsLocal = true
    -- create folder for the font
    fileSystem.ensureFolder(fontDirectory)

    -- iterate over each face, caching each to disk like we do images: a face only downloads once,
    -- later sessions reuse the local file and just re-resolve it
    for i, face in ipairs(fontManifest and fontManifest.faces or {}) do
        local fontFacePath = fontDirectory .. "/" .. face.name:gsub(" ", "-") .. ".ttf"
        if not fileSystem.isfile(fontFacePath) then
            local fontFaceId = self.assetResolver:resolve(face.assetId)
            local fontFaceContent = self.assetResolver:getAssetContentFromId(fontFaceId, false)
            if fontFaceContent then
                fileSystem.writefile(fontFacePath, fontFaceContent)
            elseif self._debug then
                log.warn("Font face content is nil for font id: " .. tostring(resolvedId) .. ", face: " .. face.name)
            end
        end
        local ok, uri = pcall(env.getcustomasset, fontFacePath)
        if ok and uri then
            fontManifest.faces[i].assetId = uri
            if self._debug then
                log.print("Loaded font face for id: " .. tostring(resolvedId) .. ", face: " .. face.name)
            end
        else
            madeAllFontsLocal = false
            if self._debug then
                log.warn("Failed to load font face for id: " .. tostring(resolvedId) .. ", face: " .. face.name)
            end
        end
    end
    local fontManifestId = id
    -- if all font faces were successfully loaded, write the font manifest to disk
    if madeAllFontsLocal and fontManifest then
        local encodedManifest = jsonEncode(fontManifest)
        fileSystem.writefile(fontDirectory .. "/manifest.json", encodedManifest)
        local ok, uri = pcall(env.getcustomasset, fontDirectory .. "/manifest.json")
        if ok and uri then
            fontManifestId = uri
        else
            if self._debug then
                log.warn("Failed to load font manifest for id: " .. tostring(resolvedId))
            end
            return self.defaultOptions.fallbackFont
        end
    end
    -- load the font using the manifest
    local ok, loadedFont = pcall(Font.new, fontManifestId, fontWeight, fontStyle)
    if not ok or not loadedFont then
        if self._debug then
            log.warn("Failed to load font for id: " .. tostring(resolvedId))
        end
        return self.defaultOptions.fallbackFont
    end

    -- write the font manifest to the disk
    if self.fontCache then
        self.fontCache[resolvedId] = {
            customId = fontManifestId,
            manifest = fontManifest,
            loadedFromDisk = true,
            variants = {
                [cacheKey] = loadedFont,
            },
        }
        if self._debug then
            log.print("Cached font for id: " .. tostring(resolvedId))
        end
    end
    return loadedFont
end

function fontManager:resolve(id: number | string): Font?
    local resolvedId = resolveId(id)
    if not resolvedId then
        return nil
    end

    if self.fontCache then
        local cached = self.fontCache[resolvedId]
        if cached then
            if self._debug then
                log.print("Resolved font for id: " .. tostring(resolvedId))
            end
            for _, font in pairs(cached.variants or {}) do
                return font
            end
        end
    end

    return nil
end

function fontManager:getFontFromId(id: number | string): Font?
    return self:resolve(id)
end

return fontManager
