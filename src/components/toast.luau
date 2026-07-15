--!nonstrict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local Toast = {}
Toast.__index = Toast
Toast.__type = "Toast"

-- Utility
local utility = script.Parent.Parent.utility
local variables = require(utility.variables)
local functions = require(utility.functions)
local constants = require(utility.constants)
local image = require(utility.image)
local hapticEngine = require(utility.HapticEngine)

-- Timings (Exponential Out, matching the notification feel).
local slideInfo = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out) -- entry travel
local growInfo = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out) -- slot open/close
local fadeLong = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out) -- fill + stroke
local fadeShort = TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out) -- content + shadow
local shrinkInfo = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out) -- exit scale

-- title weight is fixed (semibold) rather than themed, and the measure below uses the same
-- font so the hug-width always matches what actually renders
local titleFont = variables.brandFont(Enum.FontWeight.SemiBold)

local iconSize = 24 -- a glyph icon
local avatarSize = 32 -- a user headshot (matches the old "signed in as" card)
local leftPadding = 18 -- inside the pill, before the icon/text
local rightPadding = 18 -- trailing room after the text
-- the avatar (profile-chip) variant sits its headshot closer to the edge like the old card
-- and gives the text extra trailing room
local avatarLeftPadding = 10
local avatarRightPadding = 28
local iconGap = 12 -- icon to text
local stackPadding = 8 -- gap between stacked toasts (lives inside each, so it collapses on exit)
local MIN_WIDTH, MAX_WIDTH = 140, 320

-- how far above its slot the pill starts, so it flies in from off the top of the screen
local offscreenAbove = UDim2.new(0.5, 0, 0.5, -180)
local centred = UDim2.new(0.5, 0, 0.5, 0)

-- Auto duration from the text length, clamped to a sensible window (matches notifications).
local function autoDuration(text)
    return math.clamp(#text * 0.05 + 3, 3, 8)
end

-- Accept a bare asset id (number) or any ready image string (rbxassetid/rbxthumb/http).
local function resolveImage(icon)
    if type(icon) == "number" then
        return "rbxassetid://" .. tostring(icon)
    end
    return icon
end

function Toast.new(window, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        title = properties.title or properties.Title or "",
        subtitle = properties.subtitle or properties.Subtitle,
        icon = properties.icon or properties.Icon,
        -- a user id: shows that user's headshot as a larger, edge-hugging avatar (the profile
        -- chip look). takes precedence over icon.
        avatar = properties.avatar or properties.Avatar,
        -- floor the pill width (content is left-aligned, so the slack becomes right-hand room);
        -- the welcome toast uses this to match the old license card, others just hug
        minWidth = properties.minWidth or properties.MinWidth,
        -- put the subtitle line above the title (for label-over-value toasts like "Signed in
        -- as" / name); default is the usual title-on-top
        subtitleAbove = properties.subtitleAbove or properties.SubtitleAbove or false,
        _hovered = false,
        _dismissed = false,
    }, Toast)

    self.duration = properties.duration or properties.Duration or autoDuration(self.title .. (self.subtitle or ""))

    -- an avatar is a bigger, edge-hugging headshot with roomier trailing padding; a plain icon
    -- is the compact glyph. these drive both the build below and _measure.
    local hasAvatar = self.avatar ~= nil and self.avatar ~= 0
    local hasIcon = hasAvatar or (self.icon ~= nil and self.icon ~= 0 and self.icon ~= "")
    -- headshots resolve to a local getcustomasset file in secure mode, fetched async - so it may
    -- land after the toast builds, hence the onReady that fills the icon in once it's ready
    self._iconImage = if hasAvatar
        then image.avatar(self.avatar, function(uri)
            if self.iconLabel then
                image.assign(self.iconLabel, "Image", uri)
            end
        end)
        elseif hasIcon then resolveImage(self.icon)
        else nil
    self._iconSize = if hasAvatar then avatarSize else iconSize
    self._leftPad = if hasAvatar then avatarLeftPadding else leftPadding
    self._rightPad = if hasAvatar then avatarRightPadding else rightPadding
    self._minWidth = math.max(self.minWidth or 0, MIN_WIDTH)
    local hasSubtitle = self.subtitle ~= nil and self.subtitle ~= ""

    -- Outer frame: the stack item. Invisible; only its height animates (open the slot on
    -- entry, collapse it on exit so neighbours slide up into the gap).
    self.main = self.window:Create("Frame", {
        Name = "Toast",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = constants.zIndex.toast,

        Parent = self.window.toasts,
    })

    -- inter-toast gap lives here (not on the stack layout) so it collapses with the card
    self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, stackPadding),

        Parent = self.main,
    })

    -- Inner body: the visible pill. Centred so the exit width-shrink pulls in symmetrically.
    self.body = self.window:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Size = UDim2.new(1, 0, 1, 0),
        Position = offscreenAbove,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Active = true, -- takes clicks for click-to-dismiss
        BorderSizePixel = 0,
        ZIndex = constants.zIndex.toast,

        BackgroundTransparency = 1, -- In = 0

        Parent = self.main,
    })

    self.window:Create("UIGradient", {
        Rotation = 270,
        Offset = Vector2.new(0, -0.1),

        Parent = self.body,
    }, { Color = { "WindowColor", functions.toColorSequence } })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),

        Parent = self.body,
    })

    self.stroke = self.window:Create("UIStroke", {
        Transparency = 1, -- In = 0.9

        Parent = self.body,
    }, { Color = "SurfaceStroke" })

    self.shadow = self.window:CreateGlow(self.body, "ShadowColor", 20, 1) -- In = 0.6

    self.window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, self._leftPad),
        PaddingRight = UDim.new(0, self._rightPad),

        Parent = self.body,
    })

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, iconGap),

        Parent = self.body,
    })

    if hasIcon then
        -- glyph icons follow the theme's content colour; an avatar headshot stays untinted so the
        -- photo isn't recoloured. circular to suit both
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = self._iconImage,
            Size = UDim2.fromOffset(self._iconSize, self._iconSize),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel = 0,
            LayoutOrder = 1,
            ZIndex = constants.zIndex.toastContent,

            BackgroundTransparency = 1, -- In = 0.95 (a faint plate behind avatars)
            ImageTransparency = 1, -- In = 0

            Parent = self.body,
        }, if hasAvatar then nil else { ImageColor3 = "ContentColor" })

        self.window:Create("UICorner", {
            CornerRadius = UDim.new(1, 0),

            Parent = self.iconLabel,
        })
    end

    -- text column hugs its content; the body's AutomaticSize is off (we tween its width) so
    -- this fixed height keeps the row centred
    self.container = self.window:Create("Frame", {
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, hasSubtitle and 32 or 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        ZIndex = constants.zIndex.toastContent,

        Parent = self.body,
    })

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 1),

        Parent = self.container,
    })

    self.titleLabel = self.window:Create("TextLabel", {
        Text = self.title,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 16),
        BackgroundTransparency = 1,
        FontFace = titleFont,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = if self.subtitleAbove then 2 else 1,
        ZIndex = constants.zIndex.toastContent,

        TextTransparency = 1, -- In = 0

        Parent = self.container,
    }, { TextColor3 = "ContentColor" })

    if hasSubtitle then
        self.subtitleLabel = self.window:Create("TextLabel", {
            Text = self.subtitle,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 14),
            BackgroundTransparency = 1,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = if self.subtitleAbove then 1 else 2,
            ZIndex = constants.zIndex.toastContent,

            TextTransparency = 1, -- In = 0.5

            Parent = self.container,
        }, { TextColor3 = "ContentColor", FontFace = "Font" })
    end

    -- Newest on top: the container is top-anchored, so a smaller LayoutOrder sorts higher.
    self.window._toastCount = (self.window._toastCount or 0) + 1
    self.main.LayoutOrder = -self.window._toastCount

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

-- Width the pill needs to hug its content, measured without rendering so it grows into place
-- rather than snapping wide first. Height is fixed by line count (icon dictates the minimum).
function Toast:_measure()
    local titleWidth = functions.textWidth(titleFont, 16, self.title)
    local subtitleWidth = if self.subtitleLabel
        then functions.textWidth(self.window.theme.Font, 14, self.subtitle)
        else 0
    local textWidth = math.max(titleWidth, subtitleWidth)

    local left = if self.iconLabel then self._leftPad + self._iconSize + iconGap else self._leftPad
    local width = math.clamp(left + textWidth + self._rightPad, self._minWidth, MAX_WIDTH)

    local textHeight = if self.subtitleLabel then 16 + 1 + 14 else 16
    local height = math.max(textHeight, if self.iconLabel then self._iconSize else 0) + 18

    return width, height
end

-- Enter: open the slot to full height while the pill drops in from above and fades, staggering
-- the content the way a notification does.
function Toast:_show()
    if not self.main.Parent then
        return
    end

    hapticEngine.notify()

    local width, height = self:_measure()
    self.main.Size = UDim2.new(0, width, 0, 0)

    -- +stackPadding because the outer's top padding holds the inter-toast gap
    variables.tweenService:Create(self.main, growInfo, { Size = UDim2.new(0, width, 0, height + stackPadding) }):Play()
    variables.tweenService:Create(self.body, slideInfo, { Position = centred }):Play()
    variables.tweenService:Create(self.body, fadeLong, { BackgroundTransparency = 0 }):Play()
    variables.tweenService:Create(self.stroke, fadeLong, { Transparency = 0.9 }):Play()
    variables.tweenService:Create(self.shadow, fadeShort, { Transparency = 0.6 }):Play()
    variables.tweenService:Create(self.titleLabel, fadeShort, { TextTransparency = 0 }):Play()

    task.wait(0.05)
    if self._dismissed or not self.main.Parent then
        return -- dismissed mid-stagger; dont fight the exit fade
    end
    if self.iconLabel then
        variables.tweenService:Create(self.iconLabel, fadeShort, { BackgroundTransparency = 0.95 }):Play()
        variables.tweenService:Create(self.iconLabel, fadeShort, { ImageTransparency = 0 }):Play()
    end

    task.wait(0.05)
    if self._dismissed or not self.main.Parent then
        return
    end
    if self.subtitleLabel then
        variables.tweenService:Create(self.subtitleLabel, fadeShort, { TextTransparency = 0.5 }):Play()
    end

    -- Dwell, pausing while hovered.
    local elapsed = 0
    while elapsed < self.duration and not self._dismissed and self.main.Parent do
        local dt = task.wait()
        if not self._hovered then
            elapsed += dt
        end
    end

    self:_dismiss()
end

-- Exit: fade out while the pill shrinks (width + height collapse) - the notification exit.
function Toast:_dismiss()
    if self._dismissed then
        return
    end
    self._dismissed = true

    if not self.main.Parent then
        return
    end

    variables.tweenService:Create(self.body, fadeLong, { BackgroundTransparency = 1 }):Play()
    variables.tweenService:Create(self.stroke, fadeLong, { Transparency = 1 }):Play()
    variables.tweenService:Create(self.shadow, fadeShort, { Transparency = 1 }):Play()
    variables.tweenService:Create(self.titleLabel, fadeShort, { TextTransparency = 1 }):Play()
    if self.subtitleLabel then
        variables.tweenService:Create(self.subtitleLabel, fadeShort, { TextTransparency = 1 }):Play()
    end
    if self.iconLabel then
        variables.tweenService
            :Create(self.iconLabel, fadeShort, { ImageTransparency = 1, BackgroundTransparency = 1 })
            :Play()
    end

    variables.tweenService:Create(self.body, shrinkInfo, { Size = UDim2.new(1, -60, 1, 0) }):Play()
    local collapse =
        variables.tweenService:Create(self.main, shrinkInfo, { Size = UDim2.new(0, self.main.Size.X.Offset, 0, 0) })
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

return Toast
