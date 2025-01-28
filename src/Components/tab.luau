local Tab = {}
Tab.__index = Tab
Tab.__type = "Tab"

function Tab.new(window, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        name = properties.name or properties.Name or "Tab",
    }, Tab)

    -- Topbar Item
    self.topbarItem = self.window:Create("Frame", {

        Size = UDim2.fromOffset(0, 17),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.XY,
        Name = self.name,

        Parent = self.window.tabList,
    })

    self.topbarItemContainer = self.window:Create("Frame", {

        Size = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.XY,

        Parent = self.topbarItem,
    })

    self.topbarItemContainerListLayout = self.window:Create('UIListLayout', {
        Padding = UDim.new(0, 6),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.topbarItemContainer
    })

    if properties.icon then
        self.topbarItemIcon = self.window:Create("ImageLabel", {
            -- Configurables
            Image = 'rbxassetid://'..tostring(properties.icon),
    
            -- Theming
            ImageColor3 = Color3.fromRGB(255, 255, 255),
    
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ImageTransparency = 0.65,
           
            Parent = self.topbarItemContainer
        })
    end

    self.topbarItemTitle = self.window:Create("TextLabel", {
        -- Configurables
        Text = self.name, -- tab name

        -- Theming
        TextColor3 = Color3.fromRGB(255, 255, 255),
        FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium),

        Size = UDim2.fromOffset(0, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextTransparency = 0.65,
        AutomaticSize = Enum.AutomaticSize.X,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
       
        Parent = self.topbarItemContainer
    })


    return self
end

function Tab:CreateButton(properties)

end

return Tab
