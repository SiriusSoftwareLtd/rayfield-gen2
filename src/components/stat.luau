local Statistic = {}
Statistic.__index = Statistic
Statistic.__type = "Statistic"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)

-- Accent gradients per direction (fill drives the card + glow, stroke is the brighter edge)
local accents = {
    positive = {
        fill = ColorSequence.new(Color3.fromRGB(0, 170, 127), Color3.fromRGB(0, 134, 98)),
        stroke = ColorSequence.new(Color3.fromRGB(0, 213, 156), Color3.fromRGB(0, 189, 135)),
        glow = Color3.fromRGB(23, 153, 110),
    },
    negative = {
        fill = ColorSequence.new(Color3.fromRGB(172, 47, 47), Color3.fromRGB(135, 37, 37)),
        stroke = ColorSequence.new(Color3.fromRGB(255, 75, 75), Color3.fromRGB(244, 67, 67)),
        glow = Color3.fromRGB(154, 42, 42),
    },
    neutral = {
        fill = ColorSequence.new(Color3.fromRGB(39, 109, 172), Color3.fromRGB(31, 86, 135)),
        stroke = ColorSequence.new(Color3.fromRGB(63, 175, 255), Color3.fromRGB(56, 155, 244)),
        glow = Color3.fromRGB(35, 98, 154),
    },
}

local function formatPct(pct)
    if pct > 0 then
        return string.format("+%.1f%%", pct)
    elseif pct < 0 then
        return string.format("%.1f%%", pct)
    else
        return "0%"
    end
end

local function formatValue(value)
    if typeof(value) ~= "number" then
        return tostring(value)
    end
    local s = tostring(math.abs(math.floor(value)))
    local result = s:reverse():gsub("%d%d%d", "%0,"):reverse()
    if result:sub(1, 1) == "," then result = result:sub(2) end
    return if value < 0 then "-" .. result else result
end

local function formatChange(delta)
    if delta > 0 then
        return "+" .. formatValue(math.round(delta))
    elseif delta < 0 then
        return formatValue(math.round(delta))
    else
        return "0"
    end
end

function Statistic.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or "Statistic",
        icon = properties.icon or properties.Icon,
        description = properties.description or properties.Description,

        callback = properties.callback or properties.Callback or function() end,

        value = if (properties.value or properties.Value) ~= nil then (properties.value or properties.Value) else 0,

        numberEasing = if (properties.numberEasing ~= nil) then properties.numberEasing
        elseif (properties.NumberEasing ~= nil) then properties.NumberEasing
        else true,

        changeMode = properties.changeMode or properties.ChangeMode or "percentage", -- "percentage" | "absolute"
        changeBaseline = properties.changeBaseline or properties.ChangeBaseline or "previous",

        prefix = properties.prefix or properties.Prefix or "",
        suffix = properties.suffix or properties.Suffix or "",

        _initialValue = nil,
        _displayedValue = nil,
        _valueAnimTask = nil,
        _displayedPct = nil,
        _pctAnimTask = nil,
    }, Statistic)

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 90),
        BorderSizePixel = 0,
        Name = self.name,
        ZIndex = 5,

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
        Rotation = 2,
        Offset = Vector2.new(0, 0.5),
        Color = accents.neutral.stroke,
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
        ZIndex = 5,

        Parent = self.main,
    })

    self.gradientContainer = self.window:Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0),
        BorderSizePixel = 0,
        BackgroundTransparency = 1, -- In 0
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        ZIndex = 5,

        Parent = self.main,
    })

    -- Accent glow behind the stat (UIShadow, no image)
    self.statGlow = self.window:Create("UIShadow", {
        Color = accents.neutral.glow,
        Transparency = 1, -- In = 0.4
        ZIndex = -1,

        Parent = self.gradientContainer,
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
        ZIndex = 10,

        -- Animation
        TextTransparency = 1, -- In = 0

        Parent = self.titleContainer
    }, {TextColor3 = 'ContentColor', FontFace = 'TitleFont'})

    self.mainGradient = self.window:Create("UIGradient", {
        Rotation = 2,
        Offset = Vector2.new(0, 0.5),
        Color = accents.neutral.fill,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.85),
            NumberSequenceKeypoint.new(1, 0),
          }),


        Parent = self.gradientContainer
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
            ZIndex = 10,

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

    self.valueLabel = self.window:Create("TextLabel", {
        -- Configurables
        Text = self.prefix .. formatValue(self.value) .. self.suffix,

        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 20, 1, -15),
        Size = UDim2.fromOffset(200, 20),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 1,
        ZIndex = 10,

        -- Animation
        TextTransparency = 1, -- In = 0

        Parent = self.main
    }, {TextColor3 = 'ContentColor', FontFace = 'Font'})

    self.changeLabel = self.window:Create("TextLabel", {
        -- Configurables
        Text = '0%',

        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -20, 1, -15),
        Size = UDim2.fromOffset(200, 15),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextWrapped = true,
        RichText = true,
        LayoutOrder = 1,
        ZIndex = 10,

        -- Animation
        TextTransparency = 1, -- In = 0

        Parent = self.main
    }, {TextColor3 = 'ContentColor', FontFace = 'Font'})

    -- Function

    self.window:Connect(self.window.signal, function(command)
        if command == 'hide' then

        elseif command == 'show' then
            task.wait(0.7)
            variables.tweenService:Create(self.stroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeTransparency}):Play()
            variables.tweenService:Create(self.title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
            variables.tweenService:Create(self.gradientContainer, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
            variables.tweenService:Create(self.statGlow, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = 0.4}):Play()
            variables.tweenService:Create(self.main, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
            variables.tweenService:Create(self.valueLabel, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
            variables.tweenService:Create(self.changeLabel, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
            if self.icon then variables.tweenService:Create(self.iconLabel, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = 0}):Play() end
        end
    end)

    if self.description then
        self.descriptor = require(script.Parent.descriptor).new(self.tab, { description = self.description })
    end

    return self
end


function Statistic:_setAccent(key, direction)
    local accent = accents[key]
    self.strokeGradient.Color = accent.stroke
    self.mainGradient.Color = accent.fill
    variables.tweenService:Create(self.statGlow, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), { Color = accent.glow }):Play()

    -- Subtle rotation + offset shift to give the gradient a bit of life
    local rotation = if direction == 1 then 14 elseif direction == -1 then -10 else 2
    local offset = if direction == 1 then Vector2.new(0.04, 0.5) elseif direction == -1 then Vector2.new(-0.04, 0.5) else Vector2.new(0, 0.5)
    local gradientTweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Exponential)
    for _, gradient in { self.strokeGradient, self.mainGradient } do
        variables.tweenService:Create(gradient, gradientTweenInfo, { Rotation = rotation, Offset = offset }):Play()
    end
end

function Statistic:_formatValue(value)
    return self.prefix .. formatValue(value) .. self.suffix
end

function Statistic:_formatChange(delta)
    if self.changeMode == "absolute" then
        return formatChange(delta)
    else
        return formatPct(delta)
    end
end

function Statistic:Set(value)
    assert(typeof(value) == "number", "Statistic:Set() - value must be a number, got " .. typeof(value))

    local previousValue = self.value
    local hasNoHistory = (previousValue == false or previousValue == nil)
    self.value = value

    if hasNoHistory then
        self._initialValue = value
    end

    local refValue = if self.changeBaseline == "initial" then self._initialValue else previousValue
    local noChange = hasNoHistory or refValue == value

    -- Determine target change, accent, and direction
    local targetChange, infinityText, accentKey, direction
    if noChange then
        targetChange = 0
        accentKey = 'neutral'
        direction = 0
    elseif refValue == 0 then
        local sign = if value > 0 then "+" else "-"
        local suffix = if self.changeMode == "percentage" then "∞%" else "∞"
        infinityText = sign .. suffix
        accentKey = if value > 0 then 'positive' else 'negative'
        direction = if value > 0 then 1 else -1
    elseif self.changeMode == "percentage" then
        targetChange = ((value - refValue) / math.abs(refValue)) * 100
        direction = if targetChange > 0 then 1 elseif targetChange < 0 then -1 else 0
        accentKey = if direction == 1 then 'positive' elseif direction == -1 then 'negative' else 'neutral'
    else
        targetChange = value - refValue
        direction = if targetChange > 0 then 1 elseif targetChange < 0 then -1 else 0
        accentKey = if direction == 1 then 'positive' elseif direction == -1 then 'negative' else 'neutral'
    end

    self:_setAccent(accentKey, direction)

    -- Cancel any in-progress animations
    if self._valueAnimTask then
        task.cancel(self._valueAnimTask)
        self._valueAnimTask = nil
    end
    if self._pctAnimTask then
        task.cancel(self._pctAnimTask)
        self._pctAnimTask = nil
    end

    -- Animate value label
    if self.numberEasing and not hasNoHistory then
        local startVal = if self._displayedValue ~= nil then self._displayedValue else previousValue
        local startTime = tick()

        self._valueAnimTask = task.spawn(function()
            repeat
                local alpha = math.min((tick() - startTime) / 0.5, 1)
                local current = startVal + (value - startVal) * (1 - (1 - alpha) ^ 3)
                self._displayedValue = current
                self.valueLabel.Text = self:_formatValue(math.round(current))
                task.wait()
            until alpha >= 1
            self._displayedValue = value
            self.valueLabel.Text = self:_formatValue(value)
        end)
    else
        self._displayedValue = value
        self.valueLabel.Text = self:_formatValue(value)
    end

    -- Animate change label
    if infinityText then
        self.changeLabel.Text = infinityText
        self._displayedPct = nil
    elseif self.numberEasing and not noChange then
        local startChange = if self._displayedPct ~= nil then self._displayedPct else 0
        local startTime = tick()

        self._pctAnimTask = task.spawn(function()
            repeat
                local alpha = math.min((tick() - startTime) / 0.5, 1)
                local current = startChange + (targetChange - startChange) * (1 - (1 - alpha) ^ 3)
                self._displayedPct = current
                self.changeLabel.Text = self:_formatChange(current)
                task.wait()
            until alpha >= 1
            self._displayedPct = targetChange
            self.changeLabel.Text = self:_formatChange(targetChange)
        end)
    else
        self._displayedPct = targetChange
        self.changeLabel.Text = self:_formatChange(targetChange or 0)
    end
end

function Statistic:ResetBaseline(newBaseline)
    local baseline = if typeof(newBaseline) == "number" then newBaseline else self.value
    self._initialValue = baseline
    self.value = baseline
    self._displayedPct = 0
    self.changeLabel.Text = self:_formatChange(0)
    self:_setAccent('neutral', 0)
end


function Statistic:MoveTo(index)
    self.tab:_moveElement(self, index)
end

function Statistic:MoveToTop()
    self.tab:_moveElement(self, 1)
end

function Statistic:MoveToBottom()
    self.tab:_moveElement(self, #self.tab.elements)
end

function Statistic:MoveUp()
    local idx = table.find(self.tab.elements, self)
    if idx then self.tab:_moveElement(self, idx - 1) end
end

function Statistic:MoveDown()
    local idx = table.find(self.tab.elements, self)
    if idx then self.tab:_moveElement(self, idx + 1) end
end


return Statistic
