local Toggle = {}
Toggle.__index = Toggle
Toggle.__type = "Toggle"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local functions = require(utility.functions)

-- Compact (row) sizing.
local compactHeight = 41

function Toggle.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or "Switch",
        icon = properties.icon or properties.Icon,
        description = properties.description or properties.Description,
        forgetState = properties.forgetState or properties.ForgetState, -- dont save config for this element if true.
        compact = tab.compact or false, -- true when the host is a Row

        flag = properties.flag or properties.Flag or (not (properties.forgetState or properties.ForgetState) and functions.deriveFlagFromName(properties.name or properties.Name or "Switch") or nil),

        callback = properties.callback or properties.Callback or function() end,

        value = if (properties.value or properties.Value) ~= nil then (properties.value or properties.Value) else false,

        locked = false,
    }, Toggle)

    -- register as a saveable control if flagged (works in a row too)
    if self.flag and self.flag ~= "" and not self.forgetState then
        self.window.controls[self.flag] = self
    end

    if self.compact then
        self:_buildCompact()
    else
        self:_buildFull()
    end

    if self.description and not self.compact then
        self.descriptor = require(script.Parent.descriptor).new(self.tab, { description = self.description })
    end

    return self
end

-- the pill switch. same in both layouts; caller places it (pinned right / flex item)
function Toggle:_buildSwitch(parent)
    local window = self.window

    self.functionContainer = window:Create("Frame", {
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(50, 21),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),

        BackgroundTransparency = 1, -- In = 0.9

        Parent = parent
    })

    window:Create("UICorner", {
        CornerRadius = UDim.new(0, 15),
        Parent = self.functionContainer,
    })

    self.containerStroke = window:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 1, -- In = 0.85
        Parent = self.functionContainer,
    })

    self.indicator = window:Create("Frame", {
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(25, 17),
        Position = self.value and UDim2.new(1, -28, 0.5, 0) or UDim2.new(1, -47, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = self.value and Color3.fromRGB(23, 153, 110) or Color3.fromRGB(255, 255, 255),

        BackgroundTransparency = 1, -- In = 0.8

        Parent = self.functionContainer
    })

    window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = self.indicator,
    })

    self.indicatorStroke = window:Create("UIStroke", {
        Color = self.value and Color3.fromRGB(32, 201, 144) or Color3.fromRGB(255, 255, 255),
        Transparency = 1, -- In = 0.7
        Parent = self.indicator,
    })

    -- Green glow behind the selector; hidden until on (gated by Transparency: 1 hidden, 0.4 shown)
    self.indicatorGlow = window:CreateGlow(self.indicator, Color3.fromRGB(23, 153, 110), 20, 1)

    self.overlay = window:Create("Frame", {
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 0),
        AnchorPoint = Vector2.new(0, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),

        BackgroundTransparency = 1, -- In = 0

        Parent = self.functionContainer
    }, {Visible = 'DarkToggleOverlay'})

    window:Create("UICorner", {
        CornerRadius = UDim.new(0, 15),
        Parent = self.overlay,
    })

    self.overlayGradient = window:Create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 30)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 30)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0.35),
        }),

        Parent = self.overlay,
    })

    return self.functionContainer
end

-- hover: brighten stroke + title
function Toggle:_wireHover()
    self.window:Connect(self.main.MouseEnter, function()
        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeHoverTransparency, Color = self.window.theme.ElementStrokeHover}):Play()
        variables.tweenService:Create(self.title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextColor3 = self.window.theme.ElementTextHoverColor}):Play()
        if self.hoverOverlay then
            variables.tweenService:Create(self.hoverOverlay, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = 0.97}):Play()
        end
    end)

    self.window:Connect(self.main.MouseLeave, function()
        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeTransparency, Color = self.window.theme.ElementStroke}):Play()
        variables.tweenService:Create(self.title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextColor3 = self.window.theme.ContentColor}):Play()
        if self.hoverOverlay then
            variables.tweenService:Create(self.hoverOverlay, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
        end
    end)
end

-- flip, animate, run callback (error-flash on fail), autosave. press anim is per-layout
function Toggle:_performToggle()
    self.value = not self.value
    self:_animateIndicator()

    task.spawn(function()
        local success, result = pcall(function()
            self.callback(self.value)
        end)

        if not success then
            variables.tweenService:Create(self.main, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = self.window.theme.ErrorColor}):Play()
            variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = self.window.theme.ErrorStrokeColor}):Play()
            self.title.Text = 'Error, log recorded in console.'

            warn(`Rayfield encountered an error, with the callback for a {self.__type} component named '{self.name}':`)
            print(result)

            task.wait(1)

            self.title.Text = self.name
            variables.tweenService:Create(self.main, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            variables.tweenService:Create(self.stroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = self.window.theme.ElementStroke}):Play()
        end
    end)

    if self.flag and not self.forgetState and self.window.configuration.autoSave then
        task.spawn(self.window.Save, self.window)
    end
end

-- full-width: title/icon left, pill pinned right, width-bounce
function Toggle:_buildFull()
    local window = self.window

    self.main = window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 41),
        BorderSizePixel = 0,
        Name = self.name,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),

        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    }, {BackgroundTransparency = 'ElementTransparency'})

    self.stroke = window:StyleElementBody(self.main)
    self.hoverOverlay = window:CreateHoverOverlay(self.main)

    self.container = window:Create("Frame", {
        BorderSizePixel = 0,

        Parent = self.main,
        Size = UDim2.new(0, 170, 0, 16),
        Position = UDim2.new(0, 20, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1
    })

    self.containerLayout = window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,

        Parent = self.container
    })

    if self.icon then
        self.iconLabel = window:Create("ImageLabel", {
            Image = 'rbxassetid://'..tostring(self.icon),
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,

            ImageTransparency = 1, -- In = 0

            Parent = self.container
        }, {ImageColor3 = 'ContentColor'})
    end

    self.title = window:Create("TextLabel", {
        Text = self.name,
        Size = UDim2.fromOffset(250, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        AutomaticSize = Enum.AutomaticSize.X,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 1,

        TextTransparency = 1, -- In = 0

        Parent = self.container
    }, {TextColor3 = 'ContentColor', FontFace = 'Font'})

    self.interact = window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(1, 0.5),
        AnchorPoint = Vector2.new(1, 0.5),
        TextTransparency = 1,
        ZIndex = 10,

        Parent = self.main,
    })

    -- pill pinned to the right edge
    self:_buildSwitch(self.main)
    self.functionContainer.Position = UDim2.new(1, -15, 0, 20)
    self.functionContainer.AnchorPoint = Vector2.new(1, 0.5)

    self:_buildLock()

    self:_wireHover()

    self.window:Connect(self.interact.MouseButton1Click, function()
        if self.locked then return end

        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = 1}):Play()
        variables.tweenService:Create(self.main, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(1, -26, 0, 41)}):Play()

        self:_performToggle()

        task.wait(0.11)

        variables.tweenService:Create(self.main, TweenInfo.new(0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(1, -20, 0, 41)}):Play()
        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeTransparency}):Play()
    end)
end

-- compact (row): title left, pill right (SpaceBetween)
function Toggle:_buildCompact()
    local window = self.window

    self.main = window:Create("Frame", {
        Name = self.name,
        Size = UDim2.fromOffset(0, compactHeight),
        AutomaticSize = Enum.AutomaticSize.X,
        ClipsDescendants = true,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,

        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    }, {BackgroundTransparency = 'ElementTransparency'})

    self.stroke = window:StyleElementBody(self.main)

    window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Fill,
        Parent = self.main,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,

        Parent = self.main,
    })

    -- clickable wrapper, doubles as the hover-brighten surface (see button.luau).
    self.interact = window:Create("TextButton", {
        Text = "",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1, -- hover fades to 0.97
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, compactHeight),
        BorderSizePixel = 0,
        TextTransparency = 1,
        ZIndex = 10,

        Parent = self.main,
    })
    self.hoverOverlay = self.interact

    window:Create("UICorner", {
        Parent = self.interact,
    }, {CornerRadius = 'ElementCornerRadius'})

    window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 15),
        PaddingRight = UDim.new(0, 15),

        Parent = self.interact,
    })

    -- title left, pill right
    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
        Padding = UDim.new(0, 10),

        Parent = self.interact,
    })

    self.container = window:Create("Frame", {
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 0,

        Parent = self.interact,
    })

    -- text gives up room to the pill when tight
    window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Shrink,
        Parent = self.container,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,

        Parent = self.container,
    })

    if self.icon then
        self.iconLabel = window:Create("ImageLabel", {
            Image = 'rbxassetid://'..tostring(self.icon),
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            LayoutOrder = 0,

            ImageTransparency = 1, -- In = 0

            Parent = self.container,
        }, {ImageColor3 = 'ContentColor'})
    end

    self.title = window:Create("TextLabel", {
        Text = self.name,
        Size = UDim2.fromOffset(0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,

        TextTransparency = 1, -- In = 0

        Parent = self.container,
    }, {TextColor3 = 'ContentColor', FontFace = 'Font'})

    -- grows to its text, shrinks + ellipsizes when tight
    window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Shrink,
        Parent = self.title,
    })

    -- pill as the right-hand flex item
    self:_buildSwitch(self.interact)
    self.functionContainer.LayoutOrder = 1

    self:_wireHover()

    self.window:Connect(self.interact.MouseButton1Click, function()
        if self.locked then return end

        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = 1}):Play()

        self:_performToggle()

        task.wait(0.11)

        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeTransparency}):Play()
    end)
end

-- full-only lock overlay
function Toggle:_buildLock()
    local window = self.window

    self.elementLock = window:Create("Frame", {
        Name = "ElementLock",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 10,

        Parent = self.main,
    })

    window:Create("UICorner", {
        Parent = self.elementLock,
    }, {CornerRadius = 'ElementCornerRadius'})

    local lockContent = window:Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, -20, 0, 20),
        BackgroundTransparency = 1,
        ZIndex = 15,

        Parent = self.elementLock,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = lockContent,
    })

    window:Create("ImageLabel", {
        Image = 'rbxassetid://78137979054938',
        Size = UDim2.fromOffset(20, 20),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ImageTransparency = 0.2,
        ZIndex = 15,

        Parent = lockContent,
    })

    self.lockLabel = window:Create("TextLabel", {
        Text = "This element is locked.",
        Size = UDim2.fromScale(0, 1),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        TextSize = 15,
        TextTransparency = 0.2,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 1,
        ZIndex = 15,

        Parent = lockContent,
    }, {TextColor3 = 'ContentColor', FontFace = 'TitleFont'})
end


function Toggle:_animateIndicator()
    local info = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    if self.indicatorGlow then
        variables.tweenService:Create(self.indicatorGlow, info, {Transparency = self.value and 0.4 or 1}):Play()
    end
    if self.value then
        variables.tweenService:Create(self.indicator, info, {Position = UDim2.new(1, -28, 0.5, 0), BackgroundColor3 = Color3.fromRGB(23, 153, 110), BackgroundTransparency = 0}):Play()
        variables.tweenService:Create(self.indicatorStroke, info, {Color = Color3.fromRGB(32, 201, 144), Transparency = 0}):Play()
    else
        variables.tweenService:Create(self.indicator, info, {Position = UDim2.new(1, -47, 0.5, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.8}):Play()
        variables.tweenService:Create(self.indicatorStroke, info, {Color = Color3.fromRGB(255, 255, 255), Transparency = 0.7}):Play()
    end
end

local toggleReveal = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
-- glow delayed so it doesn't bleed through the fill fade-in on window open
local toggleGlowReveal = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0, false, 0.35)

function Toggle:_setShown(animate)
    local w = self.window
    w:_revealCommon(self, animate)
    w:_reveal(self.indicator, {BackgroundTransparency = self.value and 0 or 0.8}, animate, toggleReveal)
    w:_reveal(self.indicatorStroke, {Transparency = self.value and 0 or 0.7}, animate, toggleReveal)
    w:_reveal(self.indicatorGlow, {Transparency = self.value and 0.4 or 1}, animate, toggleGlowReveal)
    w:_reveal(self.overlay, {BackgroundTransparency = 0}, animate, toggleReveal)
    w:_reveal(self.containerStroke, {Transparency = 0.85}, animate, toggleReveal)
    w:_reveal(self.functionContainer, {BackgroundTransparency = 0.9}, animate, toggleReveal)
end

function Toggle:MoveTo(index)
    self.tab:_moveElement(self, index)
end

function Toggle:MoveToTop()
    self.tab:_moveElement(self, 1)
end

function Toggle:MoveToBottom()
    self.tab:_moveElement(self, #self.tab.elements)
end

function Toggle:MoveUp()
    local idx = table.find(self.tab.elements, self)
    if idx then self.tab:_moveElement(self, idx - 1) end
end

function Toggle:MoveDown()
    local idx = table.find(self.tab.elements, self)
    if idx then self.tab:_moveElement(self, idx + 1) end
end

function Toggle:Set(value, skipCallback)
    if self.value == value then return end
    self.value = value

    self:_animateIndicator()

    if not skipCallback then
        task.spawn(self.callback, self.value)
    end
end

function Toggle:Lock(message)
    self.locked = true
    if self.lockLabel and message then self.lockLabel.Text = message end
    if self.elementLock then self.elementLock.Visible = true end
end

function Toggle:Unlock()
    self.locked = false
    if self.elementLock then self.elementLock.Visible = false end
end

return Toggle
