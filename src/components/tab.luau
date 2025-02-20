local Tab = {}
Tab.__index = Tab
Tab.__type = "Tab"

-- Utility
local utility = script.Parent.Parent.utility
local SignalEngine = require(utility.SignalEngine)

-- Variables
local variables = require(utility.variables)

function Tab.new(window, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        name = properties.name or properties.Name,
        icon = properties.icon or properties.Icon,
        neglectSelector = properties.neglectSelector or properties.NeglectSelector or false,
        customOrder = properties.customOrder or properties.CustomOrder or 0 -- make this maybe not 0.
    }, Tab)

    -- fix this message.
    -- this adds support for nameless/iconless tabs
    assert(self.name or self.icon, 'Missing Icon or Name.')

    if not self.neglectSelector then -- Allow for tabs to be hidden from the tab selector, for Rayfield Settings.
        -- Topbar Item
        self.topbarItem = self.window:Create("Frame", {

            Size = UDim2.fromScale(0, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.XY,
            Name = self.name,

            LayoutOrder = self.customOrder or 0,

            Parent = self.window.tabList,
        })

        self.topbarItemContainer = self.window:Create("Frame", {

            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.fromScale(0, 0.5),
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
                
                Size = UDim2.fromOffset(16, 16),
                BorderSizePixel = 0,
                BackgroundTransparency = 1,

                -- Animation
                ImageTransparency = 1, -- In = 0.65
           
                Parent = self.topbarItemContainer
            }, {ImageColor3 = 'TabColor'})
        end

        if self.name then
            self.topbarItemTitle = self.window:Create("TextLabel", {
                -- Configurables
                Text = self.name, -- tab name

                Size = UDim2.fromOffset(0, 16),
                BorderSizePixel = 0,
                BackgroundTransparency = 1,
                TextSize = 16,
                AutomaticSize = Enum.AutomaticSize.X,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,

                -- Animation
                TextTransparency = 1, -- In = 0.65
            
                Parent = self.topbarItemContainer
            }, {TextColor3 = 'TabColor', FontFace = 'Font'})
        end

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
        self.window:Connect(self.topbarItemInteract.MouseButton1Click, function() 
           self:Select()
        end)

        self.window:Connect(self.topbarItemInteract.MouseEnter, function() 
            if self.window.selectedTab ~= self then
                if self.icon then
                    variables.tweenService:Create(self.topbarItemIcon, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0.45}):Play()
                end

                if self.name then
                    variables.tweenService:Create(self.topbarItemTitle, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0.45}):Play()
                end
            end
        end)

        self.window:Connect(self.topbarItemInteract.MouseLeave, function() 
            if self.window.selectedTab ~= self then
                if self.icon then
                    variables.tweenService:Create(self.topbarItemIcon, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0.65}):Play()
                end
                
                if self.name then
                    variables.tweenService:Create(self.topbarItemTitle, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0.65}):Play()
                end
            end
        end)
    end

    if #self.window.tabs == 1 then
        self:Select(true)
    end

    self.window:Connect(self.window.signal, function(command)
        if command == 'hide' then
            if not self.neglectSelector then
                self.topbarItem.Visible = false
            end
        elseif command == 'show' then
            task.wait(0.75)
            if not self.neglectSelector then
                self.topbarItem.Visible = true

                if self.icon then
                    variables.tweenService:Create(self.topbarItemIcon, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = if self.window.selectedTab == self then 0.1 else 0.65}):Play()
                end
                
                if self.name then
                    variables.tweenService:Create(self.topbarItemTitle, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = if self.window.selectedTab == self then 0.1 else 0.65}):Play()
                end
            end
        end
    end)

    return self
end



function Tab:Select(noAnimation)
    self.window.selectedTab = self
    self.window:Navigate(self.tabPage)

    if not self.neglectSelector and not noAnimation then
        if self.icon then
            variables.tweenService:Create(self.topbarItemIcon, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0.1}):Play()
        end

        if self.name then
            variables.tweenService:Create(self.topbarItemTitle, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0.1}):Play()
        end
    end

    for _, tab in self.window.tabs do
        if tab ~= self.window.selectedTab then
            tab:Deselect()
        end
    end 
end

function Tab:Deselect()
    if not self.neglectSelector then
        if self.icon then
            variables.tweenService:Create(self.topbarItemIcon, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0.65}):Play()
        end
        
        if self.name then
            variables.tweenService:Create(self.topbarItemTitle, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0.65}):Play()
        end
    end
end

function Tab:CreateButton(properties)
    return require(script.Parent.button).new(self, properties)
end

function Tab:CreateToggle(properties)
    return require(script.Parent.toggle).new(self, properties)
end

function Tab:CreateSwitch(properties)
    return require(script.Parent.toggle).new(self, properties)
end


function Tab:Remove()
    -- remove tab
end

return Tab
