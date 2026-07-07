local Descriptor = {}
Descriptor.__index = Descriptor
Descriptor.__type = "Descriptor"

function Descriptor.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        description = properties.description or properties.Description or "",
    }, Descriptor)

    self.main = self.window:Create("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -30, 0, 0),

        Parent = self.tab.tabPage,
    })

    self.window:Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = self.main,
    })

    self.titleLabel = self.window:Create("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        RichText = true,
        Size = UDim2.new(1, -90, 0, 0),
        Text = self.description,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,

        -- Animation
        TextTransparency = 1, -- In = 0.7

        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    -- Bottom spacing
    self.window:Create("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        Size = UDim2.fromOffset(0, 15),
        Parent = self.main,
    })

    return self
end

return Descriptor
