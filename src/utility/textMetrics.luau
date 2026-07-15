--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local variables = require(script.Parent.variables)
local textService = variables.textService

local textMetrics = {}

-- Width (px) a string renders at for a given font+size, cached since GetTextBoundsAsync
-- yields. Elements use this to report how much room they need before they'd overlap,
-- so a horizontal group can decide how many fit per row.
local widthCache: { [string]: number } = {}
local widthCacheCount = 0
local widthCacheCap = 1024 -- dynamic labels (a live stat) would otherwise grow this forever

local function getTextBounds(params: GetTextBoundsParams): unknown
    local ok, bounds = pcall(function()
        return textService:GetTextBoundsAsync(params)
    end)
    return if ok then bounds else nil
end

local function boundAxis(bounds: unknown, axis: "X" | "Y"): number?
    if typeof(bounds) == "Vector2" then
        return if axis == "X" then bounds.X else bounds.Y
    end
    if type(bounds) == "table" and type((bounds :: any)[axis]) == "number" then
        return (bounds :: any)[axis]
    end
    return nil
end

function textMetrics.textWidth(font: Font, size: number, text: any): number
    text = tostring(text)
    -- Style is part of the key: italic and normal measure differently
    local key = tostring(font.Family)
        .. "|"
        .. tostring(font.Weight)
        .. "|"
        .. tostring(font.Style)
        .. "|"
        .. tostring(size)
        .. "|"
        .. text
    local cached = widthCache[key]
    if cached then
        return cached
    end

    local params = Instance.new("GetTextBoundsParams")
    params.Text = text
    params.Font = font
    params.Size = size
    params.Width = math.huge

    local measuredWidth = boundAxis(getTextBounds(params), "X")
    if not measuredWidth then
        -- rough fallback for this call only. never cached, so a transient failure doesnt
        -- lock in a wrong width for the string forever. count characters, not bytes, or
        -- anything non-ascii measures far too wide. utf8.len is nil on malformed input.
        local length = utf8.len(text) or #text
        return math.ceil(size * 0.55 * length)
    end

    local width = math.ceil(measuredWidth)
    if widthCacheCount >= widthCacheCap then
        widthCache = {}
        widthCacheCount = 0
    end
    widthCache[key] = width
    widthCacheCount += 1
    return width
end

-- Height (px) wrapped text needs at a fixed width. The vertical counterpart to textWidth,
-- used by notifications to size their card. Not cached: notification copy is one-shot.
function textMetrics.textHeight(font: Font, size: number, text: any, width: number): number
    local params = Instance.new("GetTextBoundsParams")
    params.Text = tostring(text)
    params.Font = font
    params.Size = size
    params.Width = width

    local measuredHeight = boundAxis(getTextBounds(params), "Y")
    return if measuredHeight then math.ceil(measuredHeight) else size
end

return textMetrics
