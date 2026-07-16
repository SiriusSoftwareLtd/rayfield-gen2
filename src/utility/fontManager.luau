--!strict

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
local path = require(script.Parent.path)

local function jsonEncode(data: unknown): string?
    local success, result = pcall(function()
        return httpService:JSONEncode(data)
    end)
    if success and type(result) == "string" then
        return result
    else
        log.warn("Failed to encode JSON:", result)
        return nil
    end
end

local function jsonDecode(jsonString: string): unknown?
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

export type FontFace = {
    name: string,
    family: string,
    weight: number,
    style: string,
    assetId: string,
}

export type FontManifest = {
    name: string,
    faces: { FontFace },
}

export type CachedFont = {
    customId: number | string,
    manifest: FontManifest,
    loadedFromDisk: boolean,
    variants: { [string]: Font },
}

export type FontCache = { [number]: CachedFont }

export type FontResolverOptions = {
    fallbackFont: Font?,
    saveToDisk: boolean?,
    skipCache: boolean?,
}

type FontManagerState = {
    _debug: boolean,
    rootFolder: string,
    assetResolver: assetResolver.AssetResolver,
    defaultOptions: FontResolverOptions,
    fontCache: FontCache?,
}

export type FontManager = FontManagerState & {
    resolve: (self: FontManager, id: number | string) -> Font?,
    loadFont: (
        self: FontManager,
        id: (number | string)?,
        fontWeight: Enum.FontWeight?,
        fontStyle: Enum.FontStyle?,
        saveToDisk: boolean?,
        skipCache: boolean?
    ) -> Font?,
    getFontFromId: (self: FontManager, id: number | string) -> Font?,
}

export type fontManager = FontManager

-- the manifest comes off the network, so trust nothing about its shape. names feed straight
-- into disk paths, so sanitize them here too. returns nil for anything we cant use.
local function validateManifest(manifest: unknown): FontManifest?
    local candidate = manifest :: any
    if type(candidate) ~= "table" or type(candidate.name) ~= "string" or type(candidate.faces) ~= "table" then
        return nil
    end
    candidate.name = path.sanitizeFile(candidate.name)
    if #candidate.name == 0 or #candidate.faces == 0 then
        return nil
    end
    for _, face in candidate.faces do
        if type(face) ~= "table" or type(face.name) ~= "string" or type(face.assetId) ~= "string" then
            return nil
        end
        face.name = path.sanitizeFile(face.name)
        if #face.name == 0 then
            return nil
        end
    end
    return candidate :: FontManifest
end

-- a face only downloads when its file is missing, so an error page or a truncated body written to
-- disk would shadow the real font every session after. check the signature like we do for pngs
local fontSignatures = { "\0\1\0\0", "OTTO", "true", "ttcf", "wOFF", "wOF2" }

local function isFontBody(body: string): boolean
    for _, signature in fontSignatures do
        if string.sub(body, 1, #signature) == signature then
            return true
        end
    end
    return false
end

local env = getfenv()

local function variantKey(fontWeight: Enum.FontWeight, fontStyle: Enum.FontStyle): string
    return tostring(fontWeight) .. "|" .. tostring(fontStyle)
end

local function resolveId(id: unknown): number?
    if type(id) == "number" then
        return id
    end

    if type(id) == "string" then
        return tonumber(id)
    end

    return nil
end

function fontManager.__index(self: FontManagerState, key: unknown): unknown
    local classMember = (fontManager :: any)[key]
    if classMember ~= nil then
        return classMember
    end

    local resolvedId = resolveId(key)
    if not resolvedId then
        return nil
    end

    local fontCache = self.fontCache
    if fontCache then
        local cached = fontCache[resolvedId]
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
    assetContentDownloadUrl: assetResolver.AssetDownloadUrl?,
    defaultOptions: FontResolverOptions?
): FontManager
    local defaultResolverOptions = defaultOptions
        or {
            saveToDisk = true,
            skipCache = not useCache or false,
            fallbackFont = Font.fromEnum(Enum.Font.SourceSans),
        }
    local self = setmetatable(
        {
            rootFolder = rootFolder,
            fontCache = if useCache then {} :: FontCache else nil,
            assetResolver = assetResolver.new(useCache, assetContentDownloadUrl),
            defaultOptions = defaultResolverOptions,
            _debug = useDebug or runService:IsStudio() or false,
        } :: FontManagerState,
        fontManager
    ) :: any
    -- executors without filesystem support must degrade to the fallback font, not kill the require
    pcall(fileSystem.ensureFolder, rootFolder)
    return self
end

function fontManager.loadFont(
    self: FontManager,
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
    local requestedFontWeight = fontWeight or Enum.FontWeight.Regular
    local requestedFontStyle = fontStyle or Enum.FontStyle.Normal
    local cacheKey = variantKey(requestedFontWeight, requestedFontStyle)
    local rawId = self.assetResolver:resolve(id)
    local resolvedId = resolveId(rawId)
    if not resolvedId then
        log.warn("Invalid font id: " .. tostring(id))
        return self.defaultOptions.fallbackFont
    end
    -- if the font is already cached, return it
    local fontCache = self.fontCache
    if fontCache and not skipCache then
        local cachedFont = fontCache[resolvedId]
        if cachedFont then
            local cachedVariant = cachedFont.variants and cachedFont.variants[cacheKey]
            if cachedVariant then
                if self._debug then
                    log.print("Loaded font from cache for id: " .. tostring(resolvedId))
                end
                return cachedVariant
            end

            local ok, loadedFont = pcall(Font.new, cachedFont.customId :: any, requestedFontWeight, requestedFontStyle)
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
                fontCache[resolvedId] = nil
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
    -- fonts only load through the disk cache; without a file API there is just the fallback
    if typeof(fileSystem.isfile) ~= "function" then
        return self.defaultOptions.fallbackFont
    end
    local possibleFontManifest: string? = nil
    local downloadedManifest = false
    if runService:IsStudio() and self._debug then
        log.warn("Font manifest loading is not supported in Studio. Using default font manifest for testing.")
        possibleFontManifest =
            '{"name":"Inter","faces":[{"name":"Thin","weight":100,"style":"normal","assetId":"rbxassetid://12187277209"},{"name":"Extra Light","weight":200,"style":"normal","assetId":"rbxassetid://12187293441"},{"name":"Light","weight":300,"style":"normal","assetId":"rbxassetid://12187268450"},{"name":"Regular","weight":400,"style":"normal","assetId":"rbxassetid://12187266066"},{"name":"Medium","weight":500,"style":"normal","assetId":"rbxassetid://12187336822"},{"name":"Semi Bold","weight":600,"style":"normal","assetId":"rbxassetid://12187254443"},{"name":"Bold","weight":700,"style":"normal","assetId":"rbxassetid://12187275575"},{"name":"Extra Bold","weight":800,"style":"normal","assetId":"rbxassetid://12187267750"},{"name":"Black","weight":900,"style":"normal","assetId":"rbxassetid://12187359223"}]}'
    elseif fileSystem.isfile(manifestPath) then
        local ok, contents = pcall(fileSystem.readfile, manifestPath)
        possibleFontManifest = ok and contents or nil
    else
        -- written below only once it validates, so a bad body never poisons the cache
        possibleFontManifest = self.assetResolver:getAssetContentFromId(resolvedId, false)
        downloadedManifest = possibleFontManifest ~= nil
    end
    local fontManifest: FontManifest? = nil
    if possibleFontManifest then
        local ok, parsedManifest = pcall(jsonDecode, possibleFontManifest)
        if ok and parsedManifest then
            fontManifest = validateManifest(parsedManifest)
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
        -- a cached manifest that fails validation would fail forever; drop it
        pcall(fileSystem.delfile, manifestPath)
        return self.defaultOptions.fallbackFont
    end
    if downloadedManifest and possibleFontManifest then
        pcall(fileSystem.writefile, manifestPath, possibleFontManifest)
    end
    local fontDirectory = self.rootFolder .. "/" .. fontManifest.name
    local madeAllFontsLocal = true
    -- create folder for the font
    if not pcall(fileSystem.ensureFolder, fontDirectory) then
        return self.defaultOptions.fallbackFont
    end

    -- iterate over each face, caching each to disk like we do images: a face only downloads once,
    -- later sessions reuse the local file and just re-resolve it
    for i, face in ipairs(fontManifest.faces) do
        local fontFacePath = fontDirectory .. "/" .. face.name:gsub(" ", "-") .. ".ttf"
        if not fileSystem.isfile(fontFacePath) then
            local fontFaceId = self.assetResolver:resolve(face.assetId)
            local fontFaceContent = if fontFaceId ~= nil
                then self.assetResolver:getAssetContentFromId(fontFaceId, false)
                else nil
            if not fontFaceContent or not isFontBody(fontFaceContent) then
                madeAllFontsLocal = false
                if self._debug then
                    log.warn(
                        "Font face content is missing or not a font for font id: "
                            .. tostring(resolvedId)
                            .. ", face: "
                            .. face.name
                    )
                end
                continue
            end
            pcall(fileSystem.writefile, fontFacePath, fontFaceContent)
        end
        local ok, uri = pcall(env.getcustomasset, fontFacePath)
        if ok and type(uri) == "string" then
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
    -- every face must be local before we hand the font over; falling back to the remote id
    -- here would fetch the asset this whole flow exists to keep off the wire
    if not madeAllFontsLocal then
        return self.defaultOptions.fallbackFont
    end

    local encodedManifest = jsonEncode(fontManifest)
    if not encodedManifest or not pcall(fileSystem.writefile, fontDirectory .. "/manifest.json", encodedManifest) then
        return self.defaultOptions.fallbackFont
    end
    local manifestOk, fontManifestId = pcall(env.getcustomasset, fontDirectory .. "/manifest.json")
    if not manifestOk or not fontManifestId then
        if self._debug then
            log.warn("Failed to load font manifest for id: " .. tostring(resolvedId))
        end
        return self.defaultOptions.fallbackFont
    end
    -- load the font using the manifest
    local ok, loadedFont = pcall(Font.new, fontManifestId :: any, requestedFontWeight, requestedFontStyle)
    if not ok or not loadedFont then
        if self._debug then
            log.warn("Failed to load font for id: " .. tostring(resolvedId))
        end
        return self.defaultOptions.fallbackFont
    end

    -- write the font manifest to the disk
    fontCache = self.fontCache
    if fontCache then
        fontCache[resolvedId] = {
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

function fontManager.resolve(self: FontManager, id: number | string): Font?
    local resolvedId = resolveId(id)
    if not resolvedId then
        return nil
    end

    local fontCache = self.fontCache
    if fontCache then
        local cached = fontCache[resolvedId]
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

function fontManager.getFontFromId(self: FontManager, id: number | string): Font?
    return self:resolve(id)
end

return fontManager
