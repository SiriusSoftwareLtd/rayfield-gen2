local functions = {}

local variables = require(script.Parent.variables)
local textService = variables.textService

-- Width (px) a string renders at for a given font+size, cached since GetTextBoundsAsync
-- yields. Elements use this to report how much room they need before they'd overlap,
-- so a horizontal stack can decide how many fit per row.
local widthCache = {}
function functions.textWidth(font, size, text)
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
    local width = if ok then math.ceil(bounds.X) else math.ceil(size * 0.55 * #text)
    widthCache[key] = width
    return width
end

-- Derives a suitable config flag key from element name.
function functions.deriveFlagFromName(name)
    return (name:gsub("(%S+)", function(w)
        return w:sub(1, 1):upper() .. w:sub(2)
    end):gsub("[^%w]", ""))
end

-- black or white, whichever reads better on the bg
function functions.contrastColor(color)
    local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
    return if luminance > 0.5 then Color3.fromRGB(0, 0, 0) else Color3.fromRGB(255, 255, 255)
end

-- Coerce a Color3 to a ColorSequence (pass a ColorSequence through). UIGradient.Color
-- only accepts a sequence, so theme transforms feed colours through this.
function functions.toColorSequence(color)
    return if typeof(color) == "ColorSequence" then color else ColorSequence.new(color)
end

return functions
