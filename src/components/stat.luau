local Statistic = {}
Statistic.__index = Statistic
Statistic.__type = "Statistic"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)

function Statistic.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or "Stat",
        icon = properties.icon or properties.Icon,

        callback = properties.callback or properties.Callback or function() end,

        value = if (properties.value or properties.Value) ~= nil then (properties.value or properties.Value) else false,
    }, Statistic)

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 90),
        BorderSizePixel = 0,
        Name = self.name,

        LayoutOrder = 0,
        BackgroundColor3 = Color3.fromRGB(25, 25, 25),

        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    }, {BackgroundTransparency = 'ElementTransparency'})

    self.window:Create("UICorner", {
        Parent = self.main,
    }, {CornerRadius = 'ElementCornerRadius'})

    self.stroke = self.window:Create("UIStroke", {
        Transparency = 1, -- Animation In = 0
        Color = Color3.fromRGB(255, 255, 255),

        Parent = self.main,
    }, {Transparency = 'ElementStrokeTransparency'})

    self.strokeGradient = self.window:Create("UIGradient", {
        Rotation = 80,
        Offset = Vector2.new(0, 0.5),
        Color = ColorSequence.new(Color3.fromRGB(0, 170, 127)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.85),
            NumberSequenceKeypoint.new(1, 0),
          }),


        Parent = self.stroke
    })

    self.titleContainer = self.window:Create("Frame", {
        Size = UDim2.new(1, -40, 0, 32),
        Position = UDim2.fromOffset(20, 15),
        BorderSizePixel = 0,
        LayoutOrder = -1,
        BackgroundTransparency = 1,

        Parent = self.main,
    }, {BackgroundColor3 = 'ElementColor', BackgroundTransparency = 'ElementTransparency'})

    self.gradientContainer = self.window:Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0),
        BorderSizePixel = 0,
        LayoutOrder = -1,
        BackgroundTransparency = 0.7,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),

        Parent = self.main,
    })

    self.glowContainer = self.window:Create("Frame", {
        Size = UDim2.new(1, 35, 1, 35),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
        LayoutOrder = -1,
        BackgroundTransparency = 1,

        Parent = self.main,
    }, {BackgroundColor3 = 'ElementColor', BackgroundTransparency = 'ElementTransparency'})

    self.glowImage = self.window:Create("ImageLabel", {
        Image = 'rbxassetid://5587865193',
        ImageColor3 = Color3.fromRGB(255, 255, 255),
        Size = UDim2.fromScale(1.15, 1),
        
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 0,

        -- Animations
        ImageTransparency = 1, -- In = 0.6
       
        Parent = self.glowContainer
    })

    self.title = self.window:Create("TextLabel", {
        -- Configurables
        Text = self.name, -- tab name

        Size = UDim2.fromOffset(300, 19),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 19,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 1,

        -- Animation
        TextTransparency = 1, -- In = 0
    
        Parent = self.titleContainer
    }, {TextColor3 = 'ContentColor', FontFace = 'Font'})

    self.mainGradient = self.window:Create("UIGradient", {
        Rotation = 80,
        Offset = Vector2.new(0, 0.5),
        Color = ColorSequence.new(Color3.fromRGB(0, 170, 127)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.85),
            NumberSequenceKeypoint.new(1, 0),
          }),


        Parent = self.gradientContainer
    })

    self.glowGradient = self.window:Create("UIGradient", {
        Rotation = 80,
        Offset = Vector2.new(0, 0.5),
        Color = ColorSequence.new(Color3.fromRGB(0, 170, 127)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.85),
            NumberSequenceKeypoint.new(1, 0),
          }),


        Parent = self.glowImage
    })


    self.window:Create("UICorner", {
        Parent = self.gradientContainer,
    }, {CornerRadius = 'ElementCornerRadius'})

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            -- Configurables
            Image = 'rbxassetid://'..tostring(self.icon),
            
            -- Theming
            ImageColor3 = Color3.fromRGB(255, 255, 255),

            Size = UDim2.fromOffset(32, 32),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,

            -- Animation
            ImageTransparency = 1, -- In = 0
       
            Parent = self.titleContainer
        }, {ImageColor3 = 'ContentColor'})
    end

    self.containerLayout = self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.titleContainer
    })

    -- Function

    self.window:Connect(self.window.signal, function(command)
        if command == 'hide' then
            if not self.neglectSelector then
                self.topbarItem.Visible = false
            end
        elseif command == 'show' then
            task.wait(0.7)
            variables.tweenService:Create(self.stroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeTransparency}):Play()
            variables.tweenService:Create(self.title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
            variables.tweenService:Create(self.main, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
            if self.icon then variables.tweenService:Create(self.icon, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = 0}):Play() end
        end
    end)

    return self
end

return Statistic
