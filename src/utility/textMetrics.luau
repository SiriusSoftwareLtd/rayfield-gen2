--!nocheck

local variables = require(script.Parent.variables)
local textService = variables.textService

local textMetrics = {}

-- Width (px) a string renders at for a given font+size, cached since GetTextBoundsAsync
-- yields. Elements use this to report how much room they need before they'd overlap,
-- so a horizontal group can decide how many fit per row.
local widthCache = {}
local widthCacheCount = 0
local widthCacheCap = 1024 -- dynamic labels (a live stat) would otherwise grow this forever

function textMetrics.textWidth(font, size, text)
    text = tostring(text)
    local key = tostring(font.Family) .. "|" .. tostring(font.Weight) .. "|" .. tostring(size) .. "|" .. text
    local cached = widthCache[key]
    if cached then
        return cached
    end

    local params = Instance.new("GetTextBoundsParams")
    params.Text = text
    params.Font = font
    params.Size = size
    params.Width = math.huge

    local ok, bounds = pcall(textService.GetTextBoundsAsync, textService, params)
    if not ok then
        -- rough fallback for this call only. never cached, so a transient failure doesnt
        -- lock in a wrong width for the string forever.
        return math.ceil(size * 0.55 * #text)
    end

    local width = math.ceil(bounds.X)
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
function textMetrics.textHeight(font, size, text, width)
    local params = Instance.new("GetTextBoundsParams")
    params.Text = tostring(text)
    params.Font = font
    params.Size = size
    params.Width = width

    local ok, bounds = pcall(textService.GetTextBoundsAsync, textService, params)
    return if ok then math.ceil(bounds.Y) else size
end

return textMetrics
