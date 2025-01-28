local Tab = {}
Tab.__index = Tab
Tab.__type = "Tab"

function Tab.new(window, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        name = properties.name or properties.Name or "Tab",
    }, Tab)

    self.topbarItem = self.window:Create("Frame", {
        Parent = self.window.tabList,
    })

    return self
end

return Tab
