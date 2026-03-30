local functions = {}

-- Derives a suitable config flag key from element name.
function functions.deriveFlagFromName(name)
    return (name:gsub("(%S+)", function(w) return w:sub(1,1):upper()..w:sub(2) end):gsub("[^%w]", ""))
end

return functions
