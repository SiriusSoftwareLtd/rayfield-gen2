local Notification = {}
Notification.__index = Notification
Notification.__type = "Notification"

local TextService = game:GetService("TextService")

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local functions = require(utility.functions)

-- Timings/easings copied from Rayfield Gen1 (all Exponential, Out).
local growInfo = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local fadeLong = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out) -- bg + stroke
local fadeShort = TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out) -- title/icon/desc/shadow
-- entry: card slides in from the right as the slot opens
local swipeInInfo = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
-- exit "scale": shrink width + collapse height while it fades
local shrinkInfo = TweenInfo.new(0.9, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

local OFFSCREEN_RIGHT = UDim2.new(0.5, 360, 0.5, 0)
local CENTRED = UDim2.new(0.5, 0, 0.5, 0)

-- Gap between stacked notifications. Applied INSIDE each notification (as top
-- padding on the outer frame) rather than on the container's UIListLayout, so
-- removing one collapses its gap with it instead of dropping an external gap
-- and making the notifications above jump up.
local STACK_PADDING = 8

-- Auto duration from content length, clamped to a sensible window (Gen1-style)
local function autoDuration(content)
    return math.clamp(#content * 0.06 + 3, 3, 9)
end

function Notification.new(window, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        title = properties.title or properties.Title or "Notification",
        content = properties.content or properties.Content or "",
        icon = properties.icon or properties.Icon,
        _hovered = false,
        _dismissed = false,
    }, Notification)

    self.duration = properties.duration or properties.Duration or autoDuration(self.content)

    local hasIcon = self.icon ~= nil and self.icon ~= 0 and self.icon ~= ""

    -- Outer frame: the stack layout item. Invisible itself; only its height is
    -- animated (grow in / collapse the gap on exit).
    self.main = self.window:Create("Frame", {
        Name = "Notification",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 2,

        Parent = self.window.notifications,
    })

    -- Inter-notification gap lives here (not on the stack layout) so it collapses
    -- with the card and its neighbours don't jump when it's removed.
    self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, STACK_PADDING),

        Parent = self.main,
    })

    -- Inner body: the visible card. Centred so the exit width-shrink pulls in
    -- symmetrically from both sides.
    self.body = self.window:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Size = UDim2.new(1, 0, 1, 0),
        Position = OFFSCREEN_RIGHT, -- starts off to the right; _show slides it in
        AnchorPoint = Vector2.new(0.5, 0.5),
        Active = true, -- receives input for click-to-dismiss
        BorderSizePixel = 0,
        ZIndex = 2,

        -- Animation
        BackgroundTransparency = 1, -- In = 0

        Parent = self.main,
    })

    self.window:Create("UIGradient", {
        Rotation = 270,
        Offset = Vector2.new(0, -0.1),

        Parent = self.body,
    }, { Color = { "WindowColor", functions.toColorSequence } })

    self.window:Create("UICorner", {
        Parent = self.body,
    }, { CornerRadius = "CornerRoundness" })

    self.stroke = self.window:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 1, -- In = 0.95

        Parent = self.body,
    })

    self.shadow = self.window:CreateGlow(self.body, Color3.fromRGB(0, 0, 0), 20, 1) -- In = 0.6

    -- Horizontal insets; vertical padding comes from centering the row in the grown height
    self.window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 20),
        PaddingRight = UDim.new(0, 20),

        Parent = self.body,
    })

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 14),

        Parent = self.body,
    })

    if hasIcon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(24, 24),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 1,
            ZIndex = 2,

            -- Animation
            ImageTransparency = 1, -- In = 0

            Parent = self.body,
        }, { ImageColor3 = "ContentColor" })
    end

    -- Text column fills the row minus icon + padding (container is 300 wide)
    self.container = self.window:Create("Frame", {
        Size = UDim2.fromOffset(hasIcon and 222 or 260, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        ZIndex = 2,

        Parent = self.body,
    })

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),

        Parent = self.container,
    })

    self.titleLabel = self.window:Create("TextLabel", {
        Text = self.title,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        ZIndex = 2,

        -- Animation
        TextTransparency = 1, -- In = 0

        Parent = self.container,
    }, { TextColor3 = "ContentColor", FontFace = "TitleFont" })

    if self.content ~= "" then
        self.descriptionLabel = self.window:Create("TextLabel", {
            Text = self.content,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            TextSize = 15,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            LayoutOrder = 2,
            ZIndex = 2,

            -- Animation
            TextTransparency = 1, -- In = 0.35

            Parent = self.container,
        }, { TextColor3 = "ContentColor", FontFace = "Font" })
    end

    -- Newest sits at the bottom of the (bottom-anchored) stack
    self.window._notificationCount = (self.window._notificationCount or 0) + 1
    self.main.LayoutOrder = self.window._notificationCount

    -- tracked so _dismiss can drop them; notifications come and go so we cant let their
    -- connections/instances sit in the window lists until Unload
    self._connections = {
        self.window:Connect(self.body.MouseEnter, function()
            self._hovered = true
        end),
        self.window:Connect(self.body.MouseLeave, function()
            self._hovered = false
        end),
        self.window:Connect(self.body.InputBegan, function(input)
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                self:_dismiss()
            end
        end),
    }

    task.spawn(function()
        self:_show()
    end)

    return self
end

-- Height the card needs, measured without rendering (so nothing flickers into
-- the stack before it's ready to animate).
function Notification:_measure()
    local colWidth = self.iconLabel and 222 or 260
    local function textHeight(text, font, size)
        local params = Instance.new("GetTextBoundsParams")
        params.Text = text
        params.Font = font
        params.Size = size
        params.Width = colWidth
        local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
        params:Destroy()
        return ok and bounds.Y or size
    end

    local contentH = textHeight(self.title, self.window.theme.TitleFont, 16)
    if self.descriptionLabel then
        contentH = contentH + 4 + textHeight(self.content, self.window.theme.Font, 15)
    end

    return math.max(contentH, self.iconLabel and 24 or 0) + 28
end

-- Enter: grow the height, then stagger the fades (Gen1 timing).
function Notification:_show()
    -- All sizing done before anything is visible: outer is height 0 and the body
    -- is fully transparent until the grow tween starts, so there's no flicker.
    -- +STACK_PADDING because the outer's top padding holds the inter-card gap.
    local target = self:_measure() + STACK_PADDING
    if not self.main.Parent then
        return
    end

    -- Open the slot and slide the card in from the right (body starts off-right), fading as it comes
    variables.tweenService:Create(self.main, growInfo, { Size = UDim2.new(1, 0, 0, target) }):Play()
    variables.tweenService:Create(self.body, swipeInInfo, { Position = CENTRED }):Play()
    variables.tweenService:Create(self.body, fadeLong, { BackgroundTransparency = 0 }):Play()
    variables.tweenService:Create(self.titleLabel, fadeShort, { TextTransparency = 0 }):Play()
    variables.tweenService:Create(self.stroke, fadeLong, { Transparency = 0.95 }):Play()
    variables.tweenService:Create(self.shadow, fadeShort, { Transparency = 0.6 }):Play()

    task.wait(0.05)
    if self.iconLabel then
        variables.tweenService:Create(self.iconLabel, fadeShort, { ImageTransparency = 0 }):Play()
    end

    task.wait(0.05)
    if self.descriptionLabel then
        variables.tweenService:Create(self.descriptionLabel, fadeShort, { TextTransparency = 0.35 }):Play()
    end

    -- Dwell, pausing while hovered
    local elapsed = 0
    while elapsed < self.duration and not self._dismissed and self.main.Parent do
        local dt = task.wait()
        if not self._hovered then
            elapsed += dt
        end
    end

    self:_dismiss()
end

-- Exit: fade out while the card shrinks (width + height) - Gen1's exit.
function Notification:_dismiss()
    if self._dismissed then
        return
    end
    self._dismissed = true

    if not self.main.Parent then
        return
    end

    -- Fade everything out (runs during the shrink -> "goes transparent as it scales")
    variables.tweenService:Create(self.body, fadeLong, { BackgroundTransparency = 1 }):Play()
    variables.tweenService:Create(self.stroke, fadeLong, { Transparency = 1 }):Play()
    variables.tweenService:Create(self.shadow, fadeShort, { Transparency = 1 }):Play()
    variables.tweenService:Create(self.titleLabel, fadeShort, { TextTransparency = 1 }):Play()
    if self.descriptionLabel then
        variables.tweenService:Create(self.descriptionLabel, fadeShort, { TextTransparency = 1 }):Play()
    end
    if self.iconLabel then
        variables.tweenService:Create(self.iconLabel, fadeShort, { ImageTransparency = 1 }):Play()
    end

    -- Shrink: narrow the card (width -90) and collapse the slot (height 0) together
    variables.tweenService:Create(self.body, shrinkInfo, { Size = UDim2.new(1, -90, 1, 0) }):Play()
    local collapse = variables.tweenService:Create(self.main, shrinkInfo, { Size = UDim2.new(1, 0, 0, 0) })
    collapse:Play()
    collapse.Completed:Wait()

    if not self.main.Parent then
        return
    end

    for _, connection in self._connections do
        self.window:Disconnect(connection)
    end
    self.window:DestroySubtree(self.main)
end

return Notification
