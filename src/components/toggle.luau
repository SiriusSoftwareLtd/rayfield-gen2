local Toggle = {}
Toggle.__index = Toggle
Toggle.__type = "Toggle"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)

function Toggle.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or "Switch",
        icon = properties.icon or properties.Icon,
        forgetState = properties.forgetState or properties.ForgetState, -- dont save config for this element if true.

        callback = properties.callback or properties.Callback or function() end,

        value = if (properties.value or properties.Value) ~= nil then (properties.value or properties.Value) else false,
    }, Toggle)

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 43),
        BorderSizePixel = 0,
        Name = self.name,

        LayoutOrder = 0,

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
        Size = UDim2.new(0, 200, 1, 0),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(1, 0.5),
        AnchorPoint = Vector2.new(1, 0.5),
        TextTransparency = 1,

        Parent = self.main,
    })

    self.functionContainer = self.window:Create("Frame", {
        BorderSizePixel = 0,

        Size = UDim2.fromOffset(43, 21),
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

        Size = UDim2.fromOffset(17, 17),
        Position = UDim2.new(1, -40, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),

        -- Animation
        BackgroundTransparency = 1, -- In = 0.8


        Parent = self.functionContainer
    })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),

        Parent = self.indicator,
    })

    self.indicatorStroke = self.window:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),

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



    -- Function
    self.window:Connect(self.interact.MouseButton1Click, function() 

        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = 1}):Play()
        variables.tweenService:Create(self.main, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(1, -26, 0, 43)}):Play()
  
        self.value = not self.value

        if self.value then
            variables.tweenService:Create(self.indicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = UDim2.new(1, -20, 0.5, 0)}):Play()
            variables.tweenService:Create(self.indicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(23, 153, 110)}):Play()
            variables.tweenService:Create(self.indicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
            variables.tweenService:Create(self.indicatorStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Color = Color3.fromRGB(32, 201, 144)}):Play()
            variables.tweenService:Create(self.indicatorStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = 0}):Play()
        else
            variables.tweenService:Create(self.indicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = UDim2.new(1, -40, 0.5, 0)}):Play()
            variables.tweenService:Create(self.indicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            variables.tweenService:Create(self.indicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0.8}):Play()
            variables.tweenService:Create(self.indicatorStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Color = Color3.fromRGB(255, 255, 255)}):Play()
            variables.tweenService:Create(self.indicatorStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = 0.7}):Play()
        end

        task.spawn(function() 
            local success, result = pcall(function()
                self.callback(self.value)
            end) 

            if not success then
                -- LOG ERROR IN WORKSPACE FILE. e.g logs.rfld 

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

        task.wait(0.11)

        variables.tweenService:Create(self.main, TweenInfo.new(0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(1, -20, 0, 43)}):Play()
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

    return self
end

return Toggle
