local Button = {}
Button.__index = Button
Button.__type = "Button"

function Button.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        name = properties.name or properties.Name or "Button",
    }, Button)

    print('creating button')
    
    return self
end

return Button
