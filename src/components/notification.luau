local Notification = {}
Notification.__index = Notification
Notification.__type = "Notification"

local TextService = game:GetService("TextService")

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)

-- Grow-in slide + swipe-out-left on exit, Quint easing per project rule
local growInfo = TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local fadeInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
-- swipe + fade both fast-start over the same window so the card is visible while it moves
local swipeInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local exitFadeInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local collapseInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- Auto duration from content length, clamped to a sensible window
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
    -- animated (grow in / collapse the gap on exit). The UIListLayout owns its
    -- Position, which is why the visible card is a separate inner frame we can swipe.
    self.main = self.window:Create("Frame", {
        Name = "Notification",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 2,

        Parent = self.window.notifications,
    })

    -- Inner body: the visible card; this is what swipes out to the left on dismiss.
    self.body = self.window:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Size = UDim2.new(1, 0, 1, 0),
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
    }, {Color = {'WindowColor', function(color)
        if typeof(color) == 'ColorSequence' then return color else return ColorSequence.new(color) end
    end}})

    self.window:Create("UICorner", {
        Parent = self.body,
    }, {CornerRadius = 'CornerRoundness'})

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
        }, {ImageColor3 = 'ContentColor'})
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
    }, {TextColor3 = 'ContentColor', FontFace = 'TitleFont'})

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
        }, {TextColor3 = 'ContentColor', FontFace = 'Font'})
    end

    -- Newest sits at the bottom of the (bottom-anchored) stack
    self.window._notificationCount = (self.window._notificationCount or 0) + 1
    self.main.LayoutOrder = self.window._notificationCount

    self.window:Connect(self.body.MouseEnter, function() self._hovered = true end)
    self.window:Connect(self.body.MouseLeave, function() self._hovered = false end)
    self.window:Connect(self.body.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self:_dismiss()
        end
    end)

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
        return ok and bounds.Y or size
    end

    local contentH = textHeight(self.title, self.window.theme.TitleFont, 16)
    if self.descriptionLabel then
        contentH = contentH + 4 + textHeight(self.content, self.window.theme.Font, 15)
    end

    return math.max(contentH, self.iconLabel and 24 or 0) + 28
end

function Notification:_show()
    -- All sizing done before anything is visible: outer is height 0 and the body
    -- is fully transparent until the grow tween starts, so there's no flicker.
    local target = self:_measure()
    if not self.main.Parent then return end

    -- Grow in (slide up out of the stack)
    variables.tweenService:Create(self.main, growInfo, {Size = UDim2.new(1, 0, 0, target)}):Play()

    task.wait(0.12)
    variables.tweenService:Create(self.body, fadeInfo, {BackgroundTransparency = 0}):Play()
    variables.tweenService:Create(self.stroke, fadeInfo, {Transparency = 0.95}):Play()
    variables.tweenService:Create(self.shadow, fadeInfo, {Transparency = 0.6}):Play()
    variables.tweenService:Create(self.titleLabel, fadeInfo, {TextTransparency = 0}):Play()

    task.wait(0.05)
    if self.iconLabel then variables.tweenService:Create(self.iconLabel, fadeInfo, {ImageTransparency = 0}):Play() end

    task.wait(0.05)
    if self.descriptionLabel then variables.tweenService:Create(self.descriptionLabel, fadeInfo, {TextTransparency = 0.35}):Play() end

    -- Dwell, pausing while hovered
    local elapsed = 0
    while elapsed < self.duration and not self._dismissed and self.main.Parent do
        local dt = task.wait()
        if not self._hovered then elapsed += dt end
    end

    self:_dismiss()
end

function Notification:_dismiss()
    if self._dismissed then return end
    self._dismissed = true

    if not self.main.Parent then return end

    -- Swipe the card out to the right (off the nearest edge) while it fades
    variables.tweenService:Create(self.body, swipeInfo, {Position = UDim2.new(0, 340, 0, 0)}):Play()
    variables.tweenService:Create(self.body, exitFadeInfo, {BackgroundTransparency = 1}):Play()
    variables.tweenService:Create(self.stroke, exitFadeInfo, {Transparency = 1}):Play()
    variables.tweenService:Create(self.shadow, exitFadeInfo, {Transparency = 1}):Play()
    variables.tweenService:Create(self.titleLabel, exitFadeInfo, {TextTransparency = 1}):Play()
    if self.descriptionLabel then variables.tweenService:Create(self.descriptionLabel, exitFadeInfo, {TextTransparency = 1}):Play() end
    if self.iconLabel then variables.tweenService:Create(self.iconLabel, exitFadeInfo, {ImageTransparency = 1}):Play() end

    task.wait(0.28)

    -- Collapse the outer frame so the stack closes the gap, then remove
    if not self.main.Parent then return end
    local collapse = variables.tweenService:Create(self.main, collapseInfo, {Size = UDim2.new(1, 0, 0, 0)})
    collapse:Play()
    collapse.Completed:Wait()

    self.main:Destroy()
end

return Notification
