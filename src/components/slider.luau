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
local locale = require(utility.locale)

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

-- Below this element width we reflow to the stacked layout (title/value on top, full-width
-- track under it) so the slider stays usable in a narrow column or small window instead of
-- overlapping. Sits well below a full-width slider (~435) - including the slightly narrower
-- width it has before the window's intro grow finishes - and well above a grid column (~180),
-- so those two cases land cleanly on either side and open/close transients never straddle it.
local narrowWidth = 300

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
        minimal = properties.minimal or properties.Minimal or false, -- track only, no name/value
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
    self._lastValue = self.value

    -- minimal is just the track (built below); skip the whole title/value block
    if not self.minimal then
        self:_buildLabel()
    end

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
    self.window:ConnectFor(self, self.main.MouseEnter, function()
        if not self.window:_interactive() then
            return -- window still revealing/hiding: dont light up mid-animation
        end
        variables.tweenService
            :Create(self.track, tweenInfo, { BackgroundColor3 = self.window.theme.SliderBackgroundHover })
            :Play()
    end)

    self.window:ConnectFor(self, self.main.MouseLeave, function()
        variables.tweenService
            :Create(self.track, tweenInfo, { BackgroundColor3 = self.window.theme.SliderBackground })
            :Play()
    end)

    self.window:ConnectFor(self, self.interact.InputBegan, function(input)
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

    self.window:ConnectFor(self, variables.userInputService.InputEnded, function(input)
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

            self.window:_persist(self)
        end
    end)

    if self.description and not self.minimal then
        self.descriptor = require(script.Parent.descriptor).new(self.tab, { description = self.description })
    end

    -- pick wide vs stacked from the real width, and keep it in sync if that width changes
    -- (column resolves its size a frame after we build, and windows can be small)
    self.window:ConnectFor(self, self.main:GetPropertyChangedSignal("AbsoluteSize"), function()
        -- Ignore the transient widths the window sweeps through as it collapses/grows on
        -- hide/show/minimise, so the slider just keeps the mode it settled on while visible.
        -- The one time we DO want a hidden-window reflow is the initial layout pass before the
        -- first open (the element sizes to its real/column width while the window's still
        -- hidden) - so only block hidden reflows once the window has been shown at least once.
        if self.window.animating or (self.window.hidden and self.window.hasShownOnce) then
            return
        end
        self:_applyLayout()
    end)
    self:_applyLayout()

    if self.minimal then
        -- bare: no title/value, keep the compact 41px height so it lines up with
        -- buttons/toggles/stats, and let the track fill the bar
        self.main.Size = UDim2.new(1, -20, 0, 41)
        self.track.AnchorPoint = Vector2.new(0.5, 0.5)
        self.track.Position = UDim2.new(0.5, 0, 0.5, 0)
        self.track.Size = UDim2.new(1, -30, 0, 14)
    end

    self:_renderProgress()

    return self
end

-- The title + value block: the left column in the wide layout, the top row in the narrow
-- one. A minimal slider skips this entirely and shows only the track.
function Slider:_buildLabel()
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

    self.containerLayout = self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 2),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.container,
    })

    self.titleContainer = self.window:Create("Frame", {
        Size = UDim2.new(1, 0, 0, 16),
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

    -- narrow layout puts title + value on one row; this fills the title so the value
    -- gets pushed to the right. wide layout sets it back to None (title over value).
    self.titleFlex = self.window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.None,
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
        Text = locale.t(self.name),
        Size = UDim2.new(1, 0, 0, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, -- ellipsize instead of wrapping when the column's tight
        RichText = true,
        LayoutOrder = 1,
        ZIndex = 5,

        -- Animation
        TextTransparency = 1, -- In = 0

        Parent = self.titleContainer,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    -- shrink to share the title row with the icon when space is tight
    self.window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Shrink,
        Parent = self.title,
    })

    -- Odometer readout: host frame in place of the old label; the odometer lays
    -- its per-digit reels out inside it, left-aligned under the title.
    self.valueHost = self.window:Create("Frame", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 6,
        LayoutOrder = 1, -- sits under the title (wide) / right of it (narrow)

        Parent = self.container,
    })

    self.valueOdo = odometer.new(self.window, self.valueHost, {
        textSize = 15,
        alignment = Enum.HorizontalAlignment.Left,
        transparency = 1, -- revealed to 0.3 on show
        duration = 0.28, -- snappy roll on :Set; drag snaps instead (stays glued to the handle)
    })
    self.valueOdo:snap(self:_format(self.value))
end

-- Set the element height, keeping the width alone when a horizontal stack owns it
-- (_widthManaged): there the stack freezes us to _minWidth and wraps, so we must not
-- stomp the X it set. Standalone we take the usual full width.
function Slider:_setMainHeight(height)
    if self._widthManaged then
        self.main.Size = UDim2.new(self.main.Size.X.Scale, self.main.Size.X.Offset, 0, height)
    else
        self.main.Size = UDim2.new(1, -20, 0, height)
    end
end

-- wide: title over value on the left, fixed track on the right.
-- narrow: title + value share the top row (value pushed right), full-width track below.
-- Chosen from the slider's real width, so a slider in a narrow column (a grid) stacks while a
-- full-width one stays wide. The AbsoluteSize handler that calls this ignores the transient
-- widths the window sweeps through as it opens/closes, so this only ever runs on a settled
-- width (see the guard where it's connected).
function Slider:_applyLayout()
    if self.minimal then
        return -- bare mode has a fixed slim layout, nothing to reflow
    end
    local width = self.main.AbsoluteSize.X
    local mode = if width > 0 and width < narrowWidth then "narrow" else "wide"
    if self._layoutMode == mode then
        return
    end
    self._layoutMode = mode

    if mode == "narrow" then
        self:_setMainHeight(70)

        self.container.AnchorPoint = Vector2.new(0, 0)
        self.container.Position = UDim2.new(0, 20, 0, 14)
        self.container.Size = UDim2.new(1, -40, 0, 16)
        self.containerLayout.FillDirection = Enum.FillDirection.Horizontal
        self.titleFlex.FlexMode = Enum.UIFlexMode.Fill -- title grows, value hugs the right
        self.valueHost.AutomaticSize = Enum.AutomaticSize.X
        self.valueHost.Size = UDim2.new(0, 0, 0, 16)

        self.track.AnchorPoint = Vector2.new(0.5, 1)
        self.track.Position = UDim2.new(0.5, 0, 1, -14)
        self.track.Size = UDim2.new(1, -30, 0, 14)
    else
        self:_setMainHeight(65)

        self.container.AnchorPoint = Vector2.new(0, 0.5)
        self.container.Position = UDim2.new(0, 20, 0.5, 0)
        self.container.Size = UDim2.new(0, 170, 0, 33)
        self.containerLayout.FillDirection = Enum.FillDirection.Vertical
        self.titleFlex.FlexMode = Enum.UIFlexMode.None
        self.valueHost.AutomaticSize = Enum.AutomaticSize.None
        self.valueHost.Size = UDim2.new(1, 0, 0, 16)

        self.track.AnchorPoint = Vector2.new(1, 0.5)
        self.track.Position = UDim2.new(1, -15, 0.5, 0)
        self.track.Size = UDim2.new(0, 222, 0, 14)
    end
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
        if self.valueOdo then
            self.valueOdo:snap(self:_format(value)) -- glued to the handle: no roll mid-drag
        end
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
    if self.valueOdo then
        self.valueOdo:to(self:_format(value), value >= (self._lastValue or value))
    end
    self._lastValue = value
    self:_renderProgress(tweenInfo)

    if not skipCallback then
        self:_fireCallback(value)
        self.window:_persist(self)
    end
end

-- glows delayed so they don't float in before the bar during the window-open fade
local sliderGlowReveal = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0, false, 0.35)

function Slider:_setShown(shown, animate)
    local w = self.window
    if shown then
        w:_revealCommon(self, animate)
        w:_reveal(self.track, { BackgroundTransparency = 0 }, animate)
        w:_reveal(self.progress, { BackgroundTransparency = 0 }, animate)
        w:_reveal(self.handle, { BackgroundTransparency = 0 }, animate)
        if self.valueOdo then
            self.valueOdo:reveal(0.3, animate)
        end
        w:_reveal(self.progressGlow, { Transparency = 0.55 }, animate, sliderGlowReveal)
        w:_reveal(self.handleGlow, { Transparency = 0.8 }, animate, sliderGlowReveal)
    else
        w:_hideCommon(self, animate)
        w:_reveal(self.track, { BackgroundTransparency = 1 }, animate)
        w:_reveal(self.progress, { BackgroundTransparency = 1 }, animate)
        w:_reveal(self.handle, { BackgroundTransparency = 1 }, animate)
        if self.valueOdo then
            self.valueOdo:reveal(1, animate)
        end
        w:_reveal(self.progressGlow, { Transparency = 1 }, animate, sliderGlowReveal)
        w:_reveal(self.handleGlow, { Transparency = 1 }, animate, sliderGlowReveal)
    end
end

-- Room the slider needs in a row: its narrow layout puts title + value on the top row,
-- so that has to fit, and we floor it so the track underneath stays draggable.
function Slider:_minWidth()
    if self.minimal then
        return 100 -- a slim bar: side padding + a usable minimum track
    end
    local w = 40 -- container inset, 20 each side
    if self.icon then
        w += 22 -- 16 icon + 6 gap
    end
    w += functions.textWidth(self.window.theme.Font, 16, self.name)
    w += 12 -- gap before the value
    w += functions.textWidth(self.window.theme.Font, 15, self:_format(self.value))
    return math.max(w, 160)
end

moveable(Slider)

return Slider
