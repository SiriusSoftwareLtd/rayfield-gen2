local Slider = {}
Slider.__index = Slider
Slider.__type = "Slider"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local functions = require(utility.functions)
local odometer = require(utility.odometer)
local moveable = require(utility.moveable)
local constants = require(utility.constants)

-- Decimal places implied by an increment (0.1 -> 1, 0.25 -> 2, 1 -> 0). Used so
-- the readout formats mid-roll floats to the same precision as landed values.
local function decimalsOf(step)
    local decimals = 0
    while step % 1 ~= 0 and decimals < 6 do
        step = step * 10
        decimals += 1
    end
    return decimals
end

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

        range = properties.range or properties.Range or { 0, 100 },
        increment = properties.increment or properties.Increment or 1,
        suffix = properties.suffix or properties.Suffix or "",

        callback = properties.callback or properties.Callback or function() end,

        dragging = false,
    }, Slider)

    -- keep range ascending and increment positive so the clamp/snap math stays sane
    if self.range[1] > self.range[2] then
        self.range = { self.range[2], self.range[1] }
    end
    if self.increment <= 0 then
        self.increment = 1
    end

    self.value = if (properties.value or properties.Value) ~= nil
        then (properties.value or properties.Value)
        elseif (properties.currentValue or properties.CurrentValue) ~= nil then (
            properties.currentValue or properties.CurrentValue
        )
        else self.range[1]

    -- snap + clamp the starting value the same way Set does, so the stored value
    -- and the bar never disagree (and a bad initial value can't be saved)
    self.value = math.clamp(math.round(self.value / self.increment) * self.increment, self.range[1], self.range[2])

    self._decimals = decimalsOf(self.increment)

    self.flag = properties.flag
        or properties.Flag
        or (not self.forgetState and functions.deriveFlagFromName(self.name) or nil)
    self.window:_registerControl(self)

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 65),
        BorderSizePixel = 0,
        Name = self.name,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),

        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    self.stroke = self.window:StyleElementBody(self.main)

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
            Image = "rbxassetid://" .. tostring(self.icon),
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ZIndex = 5,

            -- Animation
            ImageTransparency = 1, -- In = 0

            Parent = self.titleContainer,
        }, { ImageColor3 = "ContentColor" })
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
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    -- Odometer readout: host frame in place of the old label; the odometer lays
    -- its per-digit reels out inside it, left-aligned under the title.
    self.valueHost = self.window:Create("Frame", {
        Size = UDim2.fromOffset(145, 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 6,

        Parent = self.container,
    })

    self.valueOdo = odometer.new(self.window, self.valueHost, {
        textSize = 15,
        alignment = Enum.HorizontalAlignment.Left,
        transparency = 1, -- revealed to 0.3 on show
        duration = 0.28, -- snappy roll on :Set; drag snaps instead (stays glued to the handle)
    })
    self.valueOdo:snap(self:_format(self.value))
    self._lastValue = self.value

    -- Right: the track
    self.track = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -15, 0.5, 0),
        Size = UDim2.fromOffset(222, 14),
        BorderSizePixel = 0,
        BackgroundTransparency = 1, -- In = 0

        Parent = self.main,
    }, { BackgroundColor3 = "SliderBackground" })

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
    }, { Color = { "SliderProgress", functions.toColorSequence } })

    -- Green glow behind the filled progress (revealed on show)
    self.progressGlow = self.window:CreateGlow(self.progress, constants.accent.on, 20, 1)

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

    -- White glow behind the drag handle (revealed on show)
    self.handleGlow = self.window:CreateGlow(self.handle, Color3.fromRGB(255, 255, 255), 10, 1)

    self.handleStroke = self.window:Create("UIStroke", {
        Transparency = 1, -- 0.6 while held

        Parent = self.handle,
    }, { Color = "SliderStroke" })

    self.interact = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        TextTransparency = 1,
        ZIndex = 10,

        Parent = self.track,
    })

    -- Subtle hover on the slider track itself, not the whole element row
    self.window:Connect(self.main.MouseEnter, function()
        variables.tweenService:Create(self.track, tweenInfo, { BackgroundColor3 = Color3.fromRGB(60, 60, 60) }):Play()
    end)

    self.window:Connect(self.main.MouseLeave, function()
        variables.tweenService
            :Create(self.track, tweenInfo, { BackgroundColor3 = self.window.theme.SliderBackground })
            :Play()
    end)

    self.window:Connect(self.interact.InputBegan, function(input)
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            self.dragging = true
            self:_setHeld(true)
            self:_updateFromMouse()

            -- drop any stale follow first, in case InputBegan fires again before InputEnded
            if self._dragConnection then
                self._dragConnection:Disconnect()
                self._dragConnection = nil
            end

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
        if
            (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
            and self.dragging
        then
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
    local text = string.format("%." .. self._decimals .. "f", value)
    if self.suffix ~= "" then
        return text .. " " .. self.suffix
    end
    return text
end

function Slider:_renderProgress(info)
    local span = self.range[2] - self.range[1]
    local ratio = if span ~= 0 then math.clamp((self.value - self.range[1]) / span, 0, 1) else 0
    local size = UDim2.fromScale(ratio, 1)
    if info then
        variables.tweenService:Create(self.progress, info, { Size = size }):Play()
    else
        self.progress.Size = size
    end
end

function Slider:_updateFromMouse()
    local width = self.track.AbsoluteSize.X
    if width <= 0 then
        return
    end

    local ratio =
        math.clamp((variables.userInputService:GetMouseLocation().X - self.track.AbsolutePosition.X) / width, 0, 1)
    local value = math.clamp(
        math.round((self.range[1] + ratio * (self.range[2] - self.range[1])) / self.increment) * self.increment,
        self.range[1],
        self.range[2]
    )

    if value ~= self.value then
        self.value = value
        self.valueOdo:snap(self:_format(value)) -- glued to the handle: no roll mid-drag
        self._lastValue = value
        self:_renderProgress(followInfo)
        self:_fireCallback(value)
    end
end

function Slider:_setHeld(held)
    if held then
        variables.tweenService
            :Create(self.handle, heldInfo, { Size = UDim2.fromOffset(41, 22), BackgroundTransparency = 0.7 })
            :Play()
        variables.tweenService:Create(self.handleStroke, heldInfo, { Transparency = 0.6 }):Play()
    else
        variables.tweenService
            :Create(self.handle, heldInfo, { Size = UDim2.fromOffset(35, 20), BackgroundTransparency = 0 })
            :Play()
        variables.tweenService:Create(self.handleStroke, heldInfo, { Transparency = 1 }):Play()
    end
end

-- pcall + debounced error-flash via Window:_runGuarded (fires every drag frame)
function Slider:_fireCallback(value)
    self.window:_runGuarded(self, self.callback, value)
end

function Slider:Set(value, skipCallback)
    value = math.clamp(math.round(value / self.increment) * self.increment, self.range[1], self.range[2])
    self.value = value
    self.valueOdo:to(self:_format(value), value >= (self._lastValue or value))
    self._lastValue = value
    self:_renderProgress(tweenInfo)

    if not skipCallback then
        self:_fireCallback(value)
    end
end

-- glows delayed so they don't float in before the bar during the window-open fade
local sliderGlowReveal = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0, false, 0.35)

function Slider:_setShown(animate)
    local w = self.window
    w:_revealCommon(self, animate)
    w:_reveal(self.track, { BackgroundTransparency = 0 }, animate)
    w:_reveal(self.progress, { BackgroundTransparency = 0 }, animate)
    w:_reveal(self.handle, { BackgroundTransparency = 0 }, animate)
    self.valueOdo:reveal(0.3, animate)
    w:_reveal(self.progressGlow, { Transparency = 0.55 }, animate, sliderGlowReveal)
    w:_reveal(self.handleGlow, { Transparency = 0.8 }, animate, sliderGlowReveal)
end

moveable(Slider)

return Slider
