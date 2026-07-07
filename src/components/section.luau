local Section = {}
Section.__index = Section
Section.__type = "Section"

local moveable = require(script.Parent.Parent.utility.moveable)

function Section.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or "Section",
        icon = properties.icon or properties.Icon,
    }, Section)

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -40, 0, 20),
        BorderSizePixel = 0,
        Name = self.name,
        BackgroundTransparency = 1,
        Parent = self.tab.tabPage,
    })

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        Parent = self.main,
    })

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            -- Configurables
            Image = "rbxassetid://" .. tostring(self.icon),

            -- Theming
            ImageColor3 = Color3.fromRGB(255, 255, 255),

            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,

            -- Animation
            ImageTransparency = 1, -- In = 0.65

            Parent = self.main,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = self.window:Create("TextLabel", {
        -- Configurables
        Text = self.name,

        Size = UDim2.fromOffset(0, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 15,
        AutomaticSize = Enum.AutomaticSize.X,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 1,

        -- Animation
        TextTransparency = 1, -- In = 0.6

        Parent = self.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    return self
end

function Section:_setShown(animate)
    local w = self.window
    w:_reveal(self.title, { TextTransparency = 0.6 }, animate)
    if self.iconLabel then
        w:_reveal(self.iconLabel, { ImageTransparency = 0.65 }, animate)
    end
end

moveable(Section)

return Section
