local Tab = {}
Tab.__index = Tab
Tab.__type = "Tab"

-- Utility
local utility = script.Parent.Parent.utility
local SignalEngine = require(utility.SignalEngine)

-- Variables
local variables = require(utility.variables)

-- Pill transparencies per state. Gradient stays constant (theme TabBackground/TabStroke), selection is just transparency.
local tabStates = {
    selected   = { background = 0,   stroke = 0,   content = 0 },
    hover      = { background = 0.4, stroke = 0.3, content = 0.3 },
    unselected = { background = 0.8, stroke = 0.65, content = 0.5 },
    hidden     = { background = 1,   stroke = 1,   content = 1 },
}

local selectTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local hoverTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

function Tab.new(window, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        name = properties.name or properties.Name,
        icon = properties.icon or properties.Icon,
        neglectSelector = properties.neglectSelector or properties.NeglectSelector or false,
        customOrder = properties.customOrder or properties.CustomOrder or 0, -- make this maybe not 0.

        elements = {}
    }, Tab)

    -- fix this message.
    -- this adds support for nameless/iconless tabs
    assert(self.name or self.icon, 'Missing Icon or Name.')

    if not self.neglectSelector then -- Allow for tabs to be hidden from the tab selector, for Rayfield Settings.
        -- Topbar Item
        self.topbarItem = self.window:Create("Frame", {
            Name = self.name,
            Size = UDim2.fromOffset(0, 34), -- min size, grows with content
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel = 0,

            -- Animation
            BackgroundTransparency = 1, -- In = 0 / 0.8
            Visible = false, -- In = true

            LayoutOrder = self.customOrder or 0,

            Parent = self.window.tabList,
        })

        self.topbarItemInteract = self.window:Create("TextButton", {
            Active = false,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            BorderSizePixel = 0,
            Text = "",
            TextTransparency = 1,

            Parent = self.topbarItem,
        })

        self.window:Create("UICorner", {
            CornerRadius = UDim.new(1, 0),

            Parent = self.topbarItem,
        })

        self.topbarItemGradient = self.window:Create("UIGradient", {
            Rotation = 90,

            Parent = self.topbarItem,
        }, {Color = {'TabBackground', function(color)
            if typeof(color) == 'ColorSequence' then
                return color
            else
                return ColorSequence.new(color)
            end
        end}})

        self.topbarItemStroke = self.window:Create("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Color = Color3.fromRGB(255, 255, 255),

            -- Animation
            Transparency = 1, -- In = 0 / 0.5

            Parent = self.topbarItem,
        })

        self.topbarItemStrokeGradient = self.window:Create("UIGradient", {
            Rotation = 90,

            Parent = self.topbarItemStroke,
        }, {Color = {'TabStroke', function(color)
            if typeof(color) == 'ColorSequence' then
                return color
            else
                return ColorSequence.new(color)
            end
        end}})

        self.topbarItemContainer = self.window:Create("Frame", {
            Size = UDim2.fromOffset(0, 34),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,

            Parent = self.topbarItem,
        })

        self.window:Create("UIPadding", {
            PaddingLeft = UDim.new(0, 13),
            PaddingRight = UDim.new(0, 14),

            Parent = self.topbarItemContainer,
        })

        self.topbarItemLayout = self.window:Create('UIListLayout', {
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
                ImageTransparency = 1, -- In = 0 / 0.5

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
                AutomaticSize = Enum.AutomaticSize.XY,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                LayoutOrder = 1,

                -- Animation
                TextTransparency = 1, -- In = 0 / 0.5

                Parent = self.topbarItemContainer
            }, {TextColor3 = 'TabColor', FontFace = 'Font'})
        end

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

    self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 33),

        Parent = self.tabPage
    })

    if not self.neglectSelector then
        self.window:Connect(self.topbarItemInteract.MouseButton1Click, function()
           self:Select()
        end)

        self.window:Connect(self.topbarItemInteract.MouseEnter, function()
            if self.window.selectedTab ~= self then
                self:_applyVisual('hover', hoverTweenInfo)
            end
        end)

        self.window:Connect(self.topbarItemInteract.MouseLeave, function()
            if self.window.selectedTab ~= self then
                self:_applyVisual('unselected', hoverTweenInfo)
            end
        end)
    end

    -- Auto-select is handled by Window:CreateTab after insertion

    self.window:Connect(self.window.signal, function(command)
        if command == 'hide' then
            if not self.neglectSelector and self.topbarItem then
                self.topbarItem.Visible = false
            end
        elseif command == 'show' then
            task.wait(0.75)
            if not self.neglectSelector and self.topbarItem then
                self.topbarItem.Visible = true
                self:_applyVisual(if self.window.selectedTab == self then 'selected' else 'unselected', selectTweenInfo)
            end
        end
    end)

    return self
end


function Tab:_applyVisual(stateName, tweenInfo)
    if self.neglectSelector or not self.topbarItem then return end

    local state = tabStates[stateName]
    if not state then return end

    if tweenInfo then
        variables.tweenService:Create(self.topbarItem, tweenInfo, { BackgroundTransparency = state.background }):Play()
        variables.tweenService:Create(self.topbarItemStroke, tweenInfo, { Transparency = state.stroke }):Play()
        if self.topbarItemIcon then
            variables.tweenService:Create(self.topbarItemIcon, tweenInfo, { ImageTransparency = state.content }):Play()
        end
        if self.topbarItemTitle then
            variables.tweenService:Create(self.topbarItemTitle, tweenInfo, { TextTransparency = state.content }):Play()
        end
    else
        self.topbarItem.BackgroundTransparency = state.background
        self.topbarItemStroke.Transparency = state.stroke
        if self.topbarItemIcon then self.topbarItemIcon.ImageTransparency = state.content end
        if self.topbarItemTitle then self.topbarItemTitle.TextTransparency = state.content end
    end
end


function Tab:Select(noAnimation)
    self.window.selectedTab = self
    self.window:Navigate(self.tabPage)

    -- noAnimation = initial selection; the pill is still hidden and the window reveal shows it.
    if not self.neglectSelector and not noAnimation then
        self:_applyVisual('selected', selectTweenInfo)
    end

    for _, tab in self.window.tabs do
        if tab ~= self.window.selectedTab then
            tab:Deselect(noAnimation)
        end
    end

    if self ~= self.window.rfSettings and self.window.settingsAction and not noAnimation then
        variables.tweenService:Create(self.window.settingsAction.iconLabel, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0.6}):Play()
    end
end

function Tab:Deselect(noAnimation)
    if not self.neglectSelector and not noAnimation then
        self:_applyVisual('unselected', selectTweenInfo)
    end
end

local function assignOrder(element, order)
    element.main.LayoutOrder = order
    if element.descriptor then
        element.descriptor.main.LayoutOrder = order + 1
    end
end

-- Button
function Tab:CreateButton(properties)
    local newElement = require(script.Parent.button).new(self, properties)
    table.insert(self.elements, newElement)
    assignOrder(newElement, #self.elements * 10)

    return newElement
end


-- Switch/Toggle
function Tab:CreateToggle(properties)
    local newElement = require(script.Parent.toggle).new(self, properties)
    table.insert(self.elements, newElement)
    assignOrder(newElement, #self.elements * 10)

    return newElement
end

function Tab:CreateSwitch(properties)
    return self:CreateToggle(properties)
end

-- Section
function Tab:CreateSection(properties)
    local newElement = require(script.Parent.section).new(self, properties)
    table.insert(self.elements, newElement)
    assignOrder(newElement, #self.elements * 10)

    return newElement
end

-- Stat
function Tab:CreateStat(properties)
    local newElement = require(script.Parent.stat).new(self, properties)
    table.insert(self.elements, newElement)
    assignOrder(newElement, #self.elements * 10)

    return newElement
end

-- Slider
function Tab:CreateSlider(properties)
    local newElement = require(script.Parent.slider).new(self, properties)
    table.insert(self.elements, newElement)
    assignOrder(newElement, #self.elements * 10)

    return newElement
end

-- Dropdown
function Tab:CreateDropdown(properties)
    local newElement = require(script.Parent.dropdown).new(self, properties)
    table.insert(self.elements, newElement)
    assignOrder(newElement, #self.elements * 10)

    return newElement
end

-- Row (packs up to 3 compact elements side by side; add to it via row:CreateX)
function Tab:CreateRow(properties)
    local newElement = require(script.Parent.row).new(self, properties)
    table.insert(self.elements, newElement)
    assignOrder(newElement, #self.elements * 10)

    return newElement
end


function Tab:_moveElement(element, targetIndex)
    local idx = table.find(self.elements, element)
    if not idx then return end
    table.remove(self.elements, idx)
    targetIndex = math.clamp(targetIndex, 1, #self.elements + 1)
    table.insert(self.elements, targetIndex, element)
    for i, el in self.elements do
        assignOrder(el, i * 10)
    end
end

function Tab:Remove()
    local window = self.window

    local idx = table.find(window.tabs, self)
    if idx then table.remove(window.tabs, idx) end

    -- If this was the active tab, hand selection to the next visible tab
    if window.selectedTab == self then
        window.selectedTab = nil
        for _, tab in ipairs(window.tabs) do
            if not tab.neglectSelector then
                tab:Select()
                break
            end
        end
    end

    -- Tear down the UI; nil the refs so the lingering show/hide signal handler
    -- and _applyVisual (which guard on self.topbarItem) no-op instead of touching
    -- a destroyed instance.
    if self.topbarItem then self.topbarItem:Destroy() end
    if self.tabPage then self.tabPage:Destroy() end
    self.topbarItem = nil
    self.tabPage = nil
    self.elements = {}
end

return Tab
