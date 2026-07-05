local Notification = {}
Notification.__index = Notification
Notification.__type = "Notification"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local image = require(utility.image)

local enterInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local exitInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local collapseInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

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

    self.main = self.window:Create("Frame", {
        Name = "Notification",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Active = true, -- so it can receive input for click-to-dismiss
        BorderSizePixel = 0,
        ZIndex = 2,

        -- Animation
        BackgroundTransparency = 1, -- In = 0

        Parent = self.window.notifications,
    })

    self.window:Create("UIGradient", {
        Rotation = 270,
        Offset = Vector2.new(0, -0.1),

        Parent = self.main,
    }, {Color = {'WindowColor', function(color)
        if typeof(color) == 'ColorSequence' then return color else return ColorSequence.new(color) end
    end}})

    self.window:Create("UICorner", {
        Parent = self.main,
    }, {CornerRadius = 'CornerRoundness'})

    self.stroke = self.window:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 1, -- In = 0.95

        Parent = self.main,
    })

    self.shadow = self.window:CreateGlow(self.main, Color3.fromRGB(0, 0, 0), 20, 1) -- In = 0.6

    self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, 14),
        PaddingBottom = UDim.new(0, 14),
        PaddingLeft = UDim.new(0, 20),
        PaddingRight = UDim.new(0, 20),

        Parent = self.main,
    })

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 14),

        Parent = self.main,
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

            Parent = self.main,
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

        Parent = self.main,
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

    self.window:Connect(self.main.MouseEnter, function() self._hovered = true end)
    self.window:Connect(self.main.MouseLeave, function() self._hovered = false end)
    self.window:Connect(self.main.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self:_dismiss()
        end
    end)

    task.spawn(function()
        self:_show()
    end)

    return self
end

function Notification:_show()
    local w = self.window
    variables.tweenService:Create(self.main, enterInfo, {BackgroundTransparency = 0}):Play()
    variables.tweenService:Create(self.titleLabel, enterInfo, {TextTransparency = 0}):Play()

    task.wait(0.05)
    if self.iconLabel then variables.tweenService:Create(self.iconLabel, enterInfo, {ImageTransparency = 0}):Play() end

    task.wait(0.05)
    if self.descriptionLabel then variables.tweenService:Create(self.descriptionLabel, enterInfo, {TextTransparency = 0.35}):Play() end
    variables.tweenService:Create(self.stroke, enterInfo, {Transparency = 0.95}):Play()
    variables.tweenService:Create(self.shadow, enterInfo, {Transparency = 0.6}):Play()

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

    variables.tweenService:Create(self.main, exitInfo, {BackgroundTransparency = 1}):Play()
    variables.tweenService:Create(self.stroke, exitInfo, {Transparency = 1}):Play()
    variables.tweenService:Create(self.shadow, exitInfo, {Transparency = 1}):Play()
    variables.tweenService:Create(self.titleLabel, exitInfo, {TextTransparency = 1}):Play()
    if self.descriptionLabel then variables.tweenService:Create(self.descriptionLabel, exitInfo, {TextTransparency = 1}):Play() end
    if self.iconLabel then variables.tweenService:Create(self.iconLabel, exitInfo, {ImageTransparency = 1}):Play() end

    task.wait(0.2)

    -- Collapse the row so the stack closes the gap, then remove
    if not self.main.Parent then return end
    self.main.AutomaticSize = Enum.AutomaticSize.None
    local collapse = variables.tweenService:Create(self.main, collapseInfo, {Size = UDim2.new(1, 0, 0, 0)})
    collapse:Play()
    collapse.Completed:Wait()

    self.main:Destroy()
end

return Notification
