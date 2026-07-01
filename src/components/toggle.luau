local Toggle = {}
Toggle.__index = Toggle
Toggle.__type = "Toggle"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local functions = require(utility.functions)

function Toggle.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or "Switch",
        icon = properties.icon or properties.Icon,
        description = properties.description or properties.Description,
        forgetState = properties.forgetState or properties.ForgetState, -- dont save config for this element if true.

        flag = properties.flag or properties.Flag or (not (properties.forgetState or properties.ForgetState) and functions.deriveFlagFromName(properties.name or properties.Name or "Switch") or nil),

        callback = properties.callback or properties.Callback or function() end,

        value = if (properties.value or properties.Value) ~= nil then (properties.value or properties.Value) else false,

        locked = false,
    }, Toggle)

    -- Register as a saveable control if flagged
    if self.flag and self.flag ~= "" and not self.forgetState then
        self.window.controls[self.flag] = self
    end

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 41),
        BorderSizePixel = 0,
        Name = self.name,

        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    }, {BackgroundColor3 = 'ElementColor', BackgroundTransparency = 'ElementTransparency'})

    self.window:Create("UICorner", {
        Parent = self.main,
    }, {CornerRadius = 'ElementCornerRadius'})

    self.stroke = self.window:Create("UIStroke", {
        Transparency = 1,

        Parent = self.main
    }, {Color = 'ElementStroke', Transparency = 'ElementStrokeTransparency'})
    
    self.container = self.window:Create("Frame", {
        BorderSizePixel = 0,

        Parent = self.main,
        Size = UDim2.new(0, 170, 0, 16),
        Position = UDim2.new(0, 20, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1
    })

    self.containerLayout = self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,

        Parent = self.container
    })

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            -- Configurables
            Image = 'rbxassetid://'..tostring(self.icon),
            
            -- Theming
            ImageColor3 = Color3.fromRGB(255, 255, 255),

            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,

            -- Animation
            ImageTransparency = 1, -- In = 0
       
            Parent = self.container
        }, {ImageColor3 = 'ContentColor'})
    end

    self.title = self.window:Create("TextLabel", {
        -- Configurables
        Text = self.name, -- tab name

        Size = UDim2.fromOffset(250, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        AutomaticSize = Enum.AutomaticSize.X,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 1,

        -- Animation
        TextTransparency = 1, -- In = 0
    
        Parent = self.container
    }, {TextColor3 = 'ContentColor', FontFace = 'Font'})

    self.interact = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(1, 0.5),
        AnchorPoint = Vector2.new(1, 0.5),
        TextTransparency = 1,
        ZIndex = 10,

        Parent = self.main,
    })

    self.functionContainer = self.window:Create("Frame", {
        BorderSizePixel = 0,

        Size = UDim2.fromOffset(50, 21),
        Position = UDim2.new(1, -15, 0, 20),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),

        -- Animation
        BackgroundTransparency = 1, -- In = 0.9

        Parent = self.main
    })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(0, 15),

        Parent = self.functionContainer,
    })

    self.containerStroke = self.window:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),

        -- Animation
        Transparency = 1, -- In = 0.85

        Parent = self.functionContainer,
    })

    self.indicator = self.window:Create("Frame", {
        BorderSizePixel = 0,

        Size = UDim2.fromOffset(25, 17),
        Position = self.value and UDim2.new(1, -28, 0.5, 0) or UDim2.new(1, -47, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        
        BackgroundColor3 = self.value and Color3.fromRGB(23, 153, 110) or Color3.fromRGB(255, 255, 255),

        -- Animation
        BackgroundTransparency = 1, -- In = 0.8


        Parent = self.functionContainer
    })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),

        Parent = self.indicator,
    })

    self.indicatorStroke = self.window:Create("UIStroke", {
        Color = self.value and Color3.fromRGB(32, 201, 144) or Color3.fromRGB(255, 255, 255),

        -- Animation
        Transparency = 1, -- In = 0.7

        Parent = self.indicator,
    })

    self.overlay = self.window:Create("Frame", {
        BorderSizePixel = 0,

        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 0),
        AnchorPoint = Vector2.new(0, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),

        -- Animation
        BackgroundTransparency = 1, -- In = 0

        Parent = self.functionContainer
    }, {Visible = 'DarkToggleOverlay'})

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(0, 15),

        Parent = self.overlay,
    })

    self.overlayGradient = self.window:Create("UIGradient", {
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



    -- Element lock overlay
    self.elementLock = self.window:Create("Frame", {
        Name = "ElementLock",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 10,

        Parent = self.main,
    })

    self.window:Create("UICorner", {
        Parent = self.elementLock,
    }, {CornerRadius = 'ElementCornerRadius'})

    local lockContent = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, -20, 0, 20),
        BackgroundTransparency = 1,
        ZIndex = 15,

        Parent = self.elementLock,
    })

    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = lockContent,
    })

    self.window:Create("ImageLabel", {
        Image = 'rbxassetid://78137979054938',
        Size = UDim2.fromOffset(20, 20),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ImageTransparency = 0.2,
        ZIndex = 15,

        Parent = lockContent,
    })

    self.lockLabel = self.window:Create("TextLabel", {
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

    -- Function
    self.window:Connect(self.interact.MouseButton1Click, function()

        if self.locked then return end

        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = 1}):Play()
        variables.tweenService:Create(self.main, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(1, -26, 0, 41)}):Play()
  
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
                variables.tweenService:Create(self.main, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {BackgroundColor3 = self.window.theme.ElementColor}):Play()
                variables.tweenService:Create(self.stroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = self.window.theme.ElementStroke}):Play()
            end
        end)

        if self.flag and not self.forgetState and self.window.configuration.autoSave then
            task.spawn(self.window.Save, self.window)
        end

        task.wait(0.11)

        variables.tweenService:Create(self.main, TweenInfo.new(0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(1, -20, 0, 41)}):Play()
        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeTransparency}):Play()
    end)

    self.window:Connect(self.main.MouseEnter, function()
        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeHoverTransparency, Color = self.window.theme.ElementStrokeHover}):Play()
        variables.tweenService:Create(self.title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextColor3 = self.window.theme.ElementTextHoverColor}):Play()
        variables.tweenService:Create(self.main, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = self.window.theme.ElementHoverTransparency, BackgroundColor3 = self.window.theme.ElementHoverColor}):Play()
    end)

    self.window:Connect(self.main.MouseLeave, function()
        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeTransparency, Color = self.window.theme.ElementStroke}):Play()
        variables.tweenService:Create(self.title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextColor3 = self.window.theme.ContentColor}):Play()
        variables.tweenService:Create(self.main, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = self.window.theme.ElementTransparency, BackgroundColor3 = self.window.theme.ElementColor}):Play()
    end)

    self.window:Connect(self.window.signal, function(command)
        if command == 'hide' then

        elseif command == 'show' then
            task.wait(0.7)
            variables.tweenService:Create(self.stroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeTransparency}):Play()
            variables.tweenService:Create(self.title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
            variables.tweenService:Create(self.main, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
            if self.icon then variables.tweenService:Create(self.iconLabel, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = 0}):Play() end
        end
    end)

    if self.description then
        self.descriptor = require(script.Parent.descriptor).new(self.tab, { description = self.description })
    end

    return self
end


function Toggle:_animateIndicator()
    local info = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    if self.value then
        variables.tweenService:Create(self.indicator, info, {Position = UDim2.new(1, -28, 0.5, 0), BackgroundColor3 = Color3.fromRGB(23, 153, 110), BackgroundTransparency = 0}):Play()
        variables.tweenService:Create(self.indicatorStroke, info, {Color = Color3.fromRGB(32, 201, 144), Transparency = 0}):Play()
    else
        variables.tweenService:Create(self.indicator, info, {Position = UDim2.new(1, -47, 0.5, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.8}):Play()
        variables.tweenService:Create(self.indicatorStroke, info, {Color = Color3.fromRGB(255, 255, 255), Transparency = 0.7}):Play()
    end
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
    if message then self.lockLabel.Text = message end
    self.elementLock.Visible = true
end

function Toggle:Unlock()
    self.locked = false
    self.elementLock.Visible = false
end

return Toggle
