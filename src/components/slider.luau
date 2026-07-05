local Slider = {}
Slider.__index = Slider
Slider.__type = "Slider"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local functions = require(utility.functions)

local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local heldInfo = TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local followInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

function Slider.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or "Slider",
        icon = properties.icon or properties.Icon,
        description = properties.description or properties.Description,
        forgetState = properties.forgetState or properties.ForgetState,

        range = properties.range or properties.Range or {0, 100},
        increment = properties.increment or properties.Increment or 1,
        suffix = properties.suffix or properties.Suffix or "",

        callback = properties.callback or properties.Callback or function() end,

        dragging = false,
    }, Slider)

    self.value = if (properties.value or properties.Value) ~= nil then (properties.value or properties.Value)
        elseif (properties.currentValue or properties.CurrentValue) ~= nil then (properties.currentValue or properties.CurrentValue)
        else self.range[1]

    self.flag = properties.flag or properties.Flag or (not self.forgetState and functions.deriveFlagFromName(self.name) or nil)
    if self.flag and self.flag ~= "" and not self.forgetState then
        self.window.controls[self.flag] = self
    end

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 65),
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

        Parent = self.main,
    }, {Color = 'ElementStroke', Transparency = 'ElementStrokeTransparency'})

    -- Left: title (+ icon) stacked over the value
    self.container = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 20, 0.5, 0),
        Size = UDim2.fromOffset(170, 33),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,

        Parent = self.main,
    })

    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 2),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.container,
    })

    self.titleContainer = self.window:Create("Frame", {
        Size = UDim2.fromOffset(170, 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,

        Parent = self.container,
    })

    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.titleContainer,
    })

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = 'rbxassetid://'..tostring(self.icon),
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ZIndex = 5,

            -- Animation
            ImageTransparency = 1, -- In = 0

            Parent = self.titleContainer,
        }, {ImageColor3 = 'ContentColor'})
    end

    self.title = self.window:Create("TextLabel", {
        Text = self.name,
        Size = UDim2.fromOffset(150, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        RichText = true,
        LayoutOrder = 1,
        ZIndex = 5,

        -- Animation
        TextTransparency = 1, -- In = 0

        Parent = self.titleContainer,
    }, {TextColor3 = 'ContentColor', FontFace = 'Font'})

    self.valueLabel = self.window:Create("TextLabel", {
        Text = self:_format(self.value),
        Size = UDim2.fromOffset(145, 15),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        ZIndex = 6,

        -- Animation
        TextTransparency = 1, -- In = 0.3

        Parent = self.container,
    }, {TextColor3 = 'ContentColor', FontFace = 'Font'})

    -- Right: the track
    self.track = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -15, 0.5, 0),
        Size = UDim2.fromOffset(222, 14),
        BorderSizePixel = 0,
        BackgroundTransparency = 1, -- In = 0

        Parent = self.main,
    }, {BackgroundColor3 = 'SliderBackground'})

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(0, 13),

        Parent = self.track,
    })

    self.progress = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 2,
        BackgroundTransparency = 1, -- In = 0

        Parent = self.track,
    })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(0, 13),

        Parent = self.progress,
    })

    self.window:Create("UIGradient", {
        Offset = Vector2.new(0, 0.5),
        Rotation = 2,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.85),
            NumberSequenceKeypoint.new(1, 0),
        }),

        Parent = self.progress,
    }, {Color = {'SliderProgress', function(color)
        if typeof(color) == 'ColorSequence' then
            return color
        else
            return ColorSequence.new(color)
        end
    end}})

    -- Green glow behind the filled progress
    self.window:Create("UIShadow", {
        Color = Color3.fromRGB(23, 153, 110),
        Transparency = 0.4,
        ZIndex = -1,

        Parent = self.progress,
    })

    -- Handle blob: solid white at rest, ghosts + grows a stroke while held
    self.handle = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 20, 0.5, 0),
        Size = UDim2.fromOffset(35, 20),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 50,
        BackgroundTransparency = 1, -- In = 0

        Parent = self.progress,
    })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),

        Parent = self.handle,
    })

    -- White glow behind the drag handle
    self.window:Create("UIShadow", {
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 0.7,
        ZIndex = -1,

        Parent = self.handle,
    })

    self.handleStroke = self.window:Create("UIStroke", {
        Transparency = 1, -- 0.6 while held

        Parent = self.handle,
    }, {Color = 'SliderStroke'})

    self.interact = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        TextTransparency = 1,
        ZIndex = 10,

        Parent = self.track,
    })

    self.window:Connect(self.main.MouseEnter, function()
        variables.tweenService:Create(self.main, tweenInfo, {BackgroundColor3 = self.window.theme.ElementHoverColor, BackgroundTransparency = self.window.theme.ElementHoverTransparency}):Play()
    end)

    self.window:Connect(self.main.MouseLeave, function()
        variables.tweenService:Create(self.main, tweenInfo, {BackgroundColor3 = self.window.theme.ElementColor, BackgroundTransparency = self.window.theme.ElementTransparency}):Play()
    end)

    self.window:Connect(self.interact.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self.dragging = true
            self:_setHeld(true)
            self:_updateFromMouse()

            -- Only run the per-frame follow while actually dragging. Self-terminates if the
            -- window unloads mid-drag, since InputEnded won't fire to clean us up then.
            self._dragConnection = variables.runService.RenderStepped:Connect(function()
                if self.window.unloaded or not self.dragging then
                    if self._dragConnection then
                        self._dragConnection:Disconnect()
                        self._dragConnection = nil
                    end
                    return
                end
                self:_updateFromMouse()
            end)
        end
    end)

    self.window:Connect(variables.userInputService.InputEnded, function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and self.dragging then
            self.dragging = false
            self:_setHeld(false)

            if self._dragConnection then
                self._dragConnection:Disconnect()
                self._dragConnection = nil
            end

            if self.flag and not self.forgetState and self.window.configuration.autoSave then
                task.spawn(self.window.Save, self.window)
            end
        end
    end)

    if self.description then
        self.descriptor = require(script.Parent.descriptor).new(self.tab, { description = self.description })
    end

    self:_renderProgress()

    return self
end

function Slider:_format(value)
    if self.suffix ~= "" then
        return tostring(value) .. " " .. self.suffix
    end
    return tostring(value)
end

function Slider:_renderProgress(info)
    local span = self.range[2] - self.range[1]
    local ratio = if span ~= 0 then math.clamp((self.value - self.range[1]) / span, 0, 1) else 0
    local size = UDim2.fromScale(ratio, 1)
    if info then
        variables.tweenService:Create(self.progress, info, {Size = size}):Play()
    else
        self.progress.Size = size
    end
end

function Slider:_updateFromMouse()
    local width = self.track.AbsoluteSize.X
    if width <= 0 then return end

    local ratio = math.clamp((variables.userInputService:GetMouseLocation().X - self.track.AbsolutePosition.X) / width, 0, 1)
    local value = math.clamp(math.round((self.range[1] + ratio * (self.range[2] - self.range[1])) / self.increment) * self.increment, self.range[1], self.range[2])

    if value ~= self.value then
        self.value = value
        self.valueLabel.Text = self:_format(value)
        self:_renderProgress(followInfo)
        task.spawn(self.callback, value)
    end
end

function Slider:_setHeld(held)
    if held then
        variables.tweenService:Create(self.handle, heldInfo, {Size = UDim2.fromOffset(41, 22), BackgroundTransparency = 0.7}):Play()
        variables.tweenService:Create(self.handleStroke, heldInfo, {Transparency = 0.6}):Play()
    else
        variables.tweenService:Create(self.handle, heldInfo, {Size = UDim2.fromOffset(35, 20), BackgroundTransparency = 0}):Play()
        variables.tweenService:Create(self.handleStroke, heldInfo, {Transparency = 1}):Play()
    end
end

function Slider:Set(value, skipCallback)
    value = math.clamp(math.round(value / self.increment) * self.increment, self.range[1], self.range[2])
    self.value = value
    self.valueLabel.Text = self:_format(value)
    self:_renderProgress(tweenInfo)

    if not skipCallback then
        task.spawn(self.callback, value)
    end
end

function Slider:MoveTo(index)
    self.tab:_moveElement(self, index)
end

function Slider:MoveToTop()
    self.tab:_moveElement(self, 1)
end

function Slider:MoveToBottom()
    self.tab:_moveElement(self, #self.tab.elements)
end

function Slider:MoveUp()
    local idx = table.find(self.tab.elements, self)
    if idx then self.tab:_moveElement(self, idx - 1) end
end

function Slider:MoveDown()
    local idx = table.find(self.tab.elements, self)
    if idx then self.tab:_moveElement(self, idx + 1) end
end

return Slider
