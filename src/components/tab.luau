local Tab = {}
Tab.__index = Tab
Tab.__type = "Tab"

function Tab.new(window, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        name = properties.name or properties.Name or "Tab",
        icon = properties.icon or properties.Icon or 0,
        neglectSelector = properties.neglectSelector or properties.NeglectSelector or false,
        customOrder = properties.customOrder or properties.CustomOrder or 0 -- make this maybe not 0.
    }, Tab)

    if not self.neglectSelector then -- Allow for tabs to be hidden from the tab selector, for Rayfield Settings.
        -- Topbar Item
        self.topbarItem = self.window:Create("Frame", {

            Size = UDim2.fromOffset(0, 17),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.XY,
            Name = self.name,

            LayoutOrder = self.customOrder or 0,

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

        if self.icon then
            self.topbarItemIcon = self.window:Create("ImageLabel", {
                -- Configurables
                Image = 'rbxassetid://'..tostring(self.icon),
                
                -- Theming
                ImageColor3 = Color3.fromRGB(255, 255, 255),
    
                Size = UDim2.fromOffset(16, 16),
                BorderSizePixel = 0,
                BackgroundTransparency = 1,
                ImageTransparency = 0.65,
           
                Parent = self.topbarItemContainer
            }, {ImageColor3 = 'TabColor'})
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

        self.topbarItemInteract = self.window:Create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            TextTransparency = 1,

            Parent = self.topbarItem,
        })

    end
    
    -- Tab Page
    self.tabPage = self.window:Create("ScrollingFrame", {
        Name = self.name,
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0.5, 0, 0, 68),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,

        LayoutOrder = self.customOrder or 0,

        Parent = self.window.elements
    })

    self.tabPageLayout = self.window:Create('UIListLayout', {
        Padding = UDim.new(0, 7),
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.tabPage
    })

    self.window:Create("Frame", {
        BorderSizePixel = 0,

        Size = UDim2.fromOffset(0, 3),
        BackgroundTransparency = 1,
        LayoutOrder = -1,

        Parent = self.tabPage
    })

    self.window:Create("Frame", {
        BorderSizePixel = 0,

        Size = UDim2.fromOffset(0, 12),
        BackgroundTransparency = 1,
        LayoutOrder = 999999,

        Parent = self.tabPage
    })

    if not self.neglectSelector then
        self.window:Connect(self.topbarItemInteract.MouseButton1Click, function() self.window:Navigate(self.tabPage) end)
    end

    return self
end

function Tab:CreateButton(properties)
    return require(script.Parent.button).new(self, properties)
end

return Tab
