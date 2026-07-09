local Input = {}
Input.__index = Input
Input.__type = "Input"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local functions = require(utility.functions)
local moveable = require(utility.moveable)
local locale = require(utility.locale)
local constants = require(utility.constants)

local resizeInfo = constants.pillResizeInfo
-- text is muted at rest, opaque while typing
local focusInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

function Input.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or "Input",
        icon = properties.icon or properties.Icon,
        description = properties.description or properties.Description,
        forgetState = properties.forgetState or properties.ForgetState,
        placeholder = properties.placeholder or properties.Placeholder or "",
        numeric = properties.numeric or properties.Numeric or false, -- strip anything not a number
        clearOnFocus = properties.clearOnFocus or properties.ClearOnFocus or false,

        callback = properties.callback or properties.Callback or function() end,
    }, Input)

    self.value =
        tostring(properties.value or properties.Value or properties.currentValue or properties.CurrentValue or "")

    self.flag = properties.flag
        or properties.Flag
        or (not self.forgetState and functions.deriveFlagFromName(self.name) or nil)
    self.window:_registerControl(self)

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 41),
        BorderSizePixel = 0,
        Name = self.name,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),

        BackgroundTransparency = 1, -- In = ElementTransparency

        Parent = self.tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    self.stroke = self.window:StyleElementBody(self.main)
    self.hoverOverlay = self.window:CreateHoverOverlay(self.main)

    -- Left: title (+ icon)
    self.container = self.window:Create("Frame", {
        Size = UDim2.new(0, 170, 0, 16),
        Position = UDim2.new(0, 20, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,

        Parent = self.main,
    })

    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,

        Parent = self.container,
    })

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = "rbxassetid://" .. tostring(self.icon),
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ZIndex = 5,

            ImageTransparency = 1, -- In = 0

            Parent = self.container,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = self.window:Create("TextLabel", {
        Text = locale.t(self.name),
        Size = UDim2.fromOffset(150, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        ZIndex = 5,

        TextTransparency = 1, -- In = 0

        Parent = self.container,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    -- Right: the field. A faint white pill pinned to the right that hugs its text.
    self.box = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -7, 0, 20),
        Size = UDim2.fromOffset(85, 30),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,

        BackgroundTransparency = 1, -- In = 0.9

        Parent = self.main,
    })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = self.box,
    })

    self.boxStroke = self.window:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),

        Transparency = 1, -- In = 0.85

        Parent = self.box,
    })

    -- glow behind the box, invisible until a set flashes it green/red
    self.glow = self.window:CreateGlow(self.box, Color3.fromRGB(255, 255, 255), 20, 1)
    self._glowIdle = 1 -- glow hidden at rest (used by the set-result flash)

    self.input = self.window:Create("TextBox", {
        Text = self.value,
        PlaceholderText = locale.t(self.placeholder),
        PlaceholderColor3 = Color3.fromRGB(178, 178, 178),
        Size = UDim2.new(1, -15, 0, 15),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClearTextOnFocus = self.clearOnFocus,

        TextTransparency = 1, -- In = 0.6

        Parent = self.box,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    -- resize to hug the text; numeric mode also strips non-number chars as they're typed
    self.window:ConnectFor(self, self.input:GetPropertyChangedSignal("Text"), function()
        if self.numeric then
            local cleaned = (self.input.Text:gsub("[^%d%.%-]", ""))
            if cleaned ~= self.input.Text then
                self.input.Text = cleaned
                return -- the reassignment re-fires this, we size on that pass
            end
        end
        self:_sizeBox(true)
    end)

    -- opaque while the field is focused, back to muted when you click away
    self.window:ConnectFor(self, self.input.Focused, function()
        variables.tweenService:Create(self.input, focusInfo, { TextTransparency = 0 }):Play()
    end)

    -- commit on focus loss (enter or click away)
    self.window:ConnectFor(self, self.input.FocusLost, function()
        variables.tweenService:Create(self.input, focusInfo, { TextTransparency = 0.6 }):Play()
        self:_commit(self.input.Text)
    end)

    self.window:_wireElementHover(self)

    if self.description then
        self.descriptor = require(script.Parent.descriptor).new(self.tab, { description = self.description })
    end

    self:_sizeBox(false) -- initial hug, no animation

    return self
end

-- width the pill needs to hug its text (placeholder when empty), floored so it stays a
-- readable pill and capped so a long value can't run over the title
function Input:_sizeBox(animate)
    local shown = self.input.Text ~= "" and self.input.Text or self.placeholder
    local width = math.clamp(functions.textWidth(self.window.theme.Font, 15, shown) + 30, 70, 220)
    if animate then
        variables.tweenService:Create(self.box, resizeInfo, { Size = UDim2.fromOffset(width, 30) }):Play()
    else
        self.box.Size = UDim2.fromOffset(width, 30)
    end
end

-- store + fire the callback + autosave, shared by typing and :Set. silent skips the
-- callback/persist/flash so config loads restore quietly.
function Input:_commit(text, silent)
    text = tostring(text)
    if self.numeric then
        -- a numeric field commits an actual number; malformed input (1.2.3, --5) clears
        local n = tonumber(text)
        text = if n then tostring(n) else ""
    end

    local changed = text ~= self.value
    self.value = text
    if self.input.Text ~= text then
        self.input.Text = text
    end

    if not silent then
        self.window:_runGuarded(self, self.callback, text)
        self.window:_persist(self)
        -- green flash to confirm the value landed (only when it actually changed)
        if changed then
            self.window:_flashResult(self, true)
        end
    end
end

function Input:Set(value, skipCallback)
    self:_commit(value, skipCallback)
end

function Input:_setShown(shown, animate)
    local w = self.window
    if shown then
        w:_revealCommon(self, animate)
        w:_reveal(self.box, { BackgroundTransparency = 0.9 }, animate)
        w:_reveal(self.boxStroke, { Transparency = 0.85 }, animate)
        w:_reveal(self.input, { TextTransparency = 0.6 }, animate)
    else
        w:_hideCommon(self, animate)
        w:_reveal(self.box, { BackgroundTransparency = 1 }, animate)
        w:_reveal(self.boxStroke, { Transparency = 1 }, animate)
        w:_reveal(self.input, { TextTransparency = 1 }, animate)
    end
end

moveable(Input)

return Input
