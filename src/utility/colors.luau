--!nocheck

local colors = {}

-- black or white, whichever reads better on the bg
function colors.contrastColor(color)
    local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
    return if luminance > 0.5 then Color3.fromRGB(0, 0, 0) else Color3.fromRGB(255, 255, 255)
end

-- Coerce a Color3 to a ColorSequence (pass a ColorSequence through). UIGradient.Color
-- only accepts a sequence, so theme transforms feed colours through this.
function colors.toColorSequence(color)
    return if typeof(color) == "ColorSequence" then color else ColorSequence.new(color)
end

-- Pick near-black or white text for whatever colour it sits on, by perceived luminance.
-- Used for text on a solid fill whose colour comes from the theme (e.g. popup buttons).
function colors.contrastText(color)
    local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
    return if luminance > 0.6 then Color3.fromRGB(20, 20, 20) else Color3.fromRGB(255, 255, 255)
end

return colors
