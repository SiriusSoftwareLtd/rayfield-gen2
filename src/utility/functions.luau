local functions = {}

-- Derives a suitable config flag key from element name.
function functions.deriveFlagFromName(name)
    return (name:gsub("(%S+)", function(w) return w:sub(1,1):upper()..w:sub(2) end):gsub("[^%w]", ""))
end

-- black or white, whichever reads better on the bg
function functions.contrastColor(color)
    local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
    return if luminance > 0.5 then Color3.fromRGB(0, 0, 0) else Color3.fromRGB(255, 255, 255)
end

return functions
