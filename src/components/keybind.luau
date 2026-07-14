-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local Keybind = {}
Keybind.__index = Keybind
Keybind.__type = "Keybind"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local functions = require(utility.functions)
local moveable = require(utility.moveable)
local locale = require(utility.locale)
local constants = require(utility.constants)
local hapticEngine = require(utility.HapticEngine)

local resizeInfo = constants.pillResizeInfo
local recordInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- shorter labels for the mouse buttons (KeyCodes already read fine)
local mouseNames = {
    [Enum.UserInputType.MouseButton1] = "MB1",
    [Enum.UserInputType.MouseButton2] = "MB2",
    [Enum.UserInputType.MouseButton3] = "MB3",
}

local function keyName(value)
    if typeof(value) ~= "EnumItem" or value == Enum.KeyCode.Unknown then
        return "None"
    end
    return mouseNames[value] or value.Name
end

-- accept an EnumItem or a KeyCode name string, fall back to unbound
local function coerceKey(value)
    if typeof(value) == "EnumItem" then
        return value
    end
    if type(value) == "string" then
        local ok, key = pcall(function()
            return Enum.KeyCode[value]
        end)
        if ok and key then
            return key
        end
    end
    return Enum.KeyCode.Unknown
end

local function enumItemFromValue(enumType, value)
    local ok, item = pcall(function()
        return enumType:FromValue(value)
    end)
    if ok and item then
        return item
    end

    local itemsOk, items = pcall(function()
        return enumType:GetEnumItems()
    end)
    if not itemsOk then
        return nil
    end

    for _, enumItem in items do
        if enumItem.Value == value then
            return enumItem
        end
    end

    return nil
end

function Keybind.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or "Keybind",
        icon = properties.icon or properties.Icon,
        description = properties.description or properties.Description,
        forgetState = properties.forgetState or properties.ForgetState or tab.forgetState,

        -- the settings' menu-toggle keybind. it drives settings.toggleKeybind, so its clash
        -- check runs the other way: reject keys an element keybind already owns.
        isMenuToggle = properties.isMenuToggle or properties.IsMenuToggle or false,

        -- fires when the bound key is pressed (or, in hold mode, with true/false)
        callback = properties.callback or properties.Callback or function() end,
        -- fires when the binding changes (rebind or :Set), gets the new key
        onChanged = properties.onChanged or properties.OnChanged or function() end,

        -- hold mode: callback(true) once the key survives holdThreshold, callback(false) on release.
        -- the threshold means a quick accidental tap fires nothing.
        hold = properties.hold or properties.Hold or false,
        holdThreshold = properties.holdThreshold or properties.HoldThreshold or 0.2,

        recording = false,
    }, Keybind)

    self.value = coerceKey(properties.value or properties.Value or properties.default or properties.Default)

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

    -- Right: the key box. A faint white pill pinned right that hugs the key name.
    self.box = self.window:Create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -7, 0, 20),
        Size = UDim2.fromOffset(40, 30),
        AutoButtonColor = false,
        Text = "",
        BorderSizePixel = 0,

        BackgroundTransparency = 1, -- In = FieldTransparency

        Parent = self.main,
    }, { BackgroundColor3 = "FieldBackground" })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = self.box,
    })

    self.boxStroke = self.window:Create("UIStroke", {
        Transparency = 1, -- In = 0.85

        Parent = self.box,
    }, { Color = "SurfaceStroke" })

    -- soft white glow behind the box: 0.9 idle, 0.7 while recording
    self.glow = self.window:CreateGlow(self.box, "FieldGlow", 20, 1)
    self._glowIdle = 0.9 -- glow Transparency at rest (used by the set-result flash)

    self.keyLabel = self.window:Create("TextLabel", {
        Text = keyName(self.value),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 2,

        TextTransparency = 1, -- In = 0.6

        Parent = self.box,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self.window:ConnectFor(self, self.box.MouseButton1Click, function()
        hapticEngine.click()
        if self.recording then
            self:_stopRecording()
        else
            self:_startRecording()
        end
    end)

    -- one persistent listener: captures the next key while recording, otherwise fires the
    -- callback when the bound key is pressed. `processed` is Roblox's gameProcessedEvent, true
    -- when the input was already consumed (typing in a box, core UI), so we skip it either way
    -- and keybinds never go off mid-type.
    self.window:ConnectFor(self, variables.userInputService.InputBegan, function(input, processed)
        if processed then
            return
        end
        if self.recording then
            self:_capture(input)
            return
        end
        -- another keybind is mid-rebind: the key being pressed is meant for it, dont let it
        -- also trigger us
        if self.window._recordingKeybind then
            return
        end
        if self:_matches(input) then
            if self.hold then
                self:_beginHold(input)
            else
                self.window:_runGuarded(self, self.callback, self.value)
            end
        end
    end)

    self.window:_wireElementHover(self)

    if self.description then
        self.descriptor = require(script.Parent.descriptor).new(self.tab, { description = self.description })
    end

    self:_sizeBox(false) -- initial hug, no animation

    return self
end

-- width the box needs to hug the current label, floored so a single key still reads as a pill
function Keybind:_sizeBox(animate)
    local width = math.clamp(functions.textWidth(self.window.theme.Font, 15, self.keyLabel.Text) + 28, 40, 200)
    if animate then
        variables.tweenService:Create(self.box, resizeInfo, { Size = UDim2.fromOffset(width, 30) }):Play()
    else
        self.box.Size = UDim2.fromOffset(width, 30)
    end
end

-- deepen the glow, light the label fully and prompt for a key
function Keybind:_startRecording()
    -- only one keybind records at a time; cancel whoever was listening before us
    local current = self.window._recordingKeybind
    if current and current ~= self then
        current:_stopRecording()
    end
    self.recording = true
    self.window._recordingKeybind = self -- window skips its toggle key while we listen
    self.keyLabel.Text = locale.resolve("Recording")
    self:_sizeBox(true)
    variables.tweenService:Create(self.glow, recordInfo, { Transparency = 0.7 }):Play()
    variables.tweenService:Create(self.keyLabel, recordInfo, { TextTransparency = 0 }):Play()
end

-- revert the glow + label and relabel to whatever value we ended up with
function Keybind:_stopRecording()
    self.recording = false
    -- clear next frame, not now: the key that stops us (a toggle-key clash) is still being
    -- dispatched, and the window's toggle listener may run after us. keep the flag up so it
    -- still bails instead of hiding the window on the same press.
    if self.window._recordingKeybind == self then
        local window = self.window
        task.defer(function()
            if window._recordingKeybind == self then
                window._recordingKeybind = nil
            end
        end)
    end
    self.keyLabel.Text = keyName(self.value)
    self:_sizeBox(true)
    variables.tweenService:Create(self.glow, recordInfo, { Transparency = 0.9 }):Play()
    variables.tweenService:Create(self.keyLabel, recordInfo, { TextTransparency = 0.6 }):Play()
end

-- capture the next input while recording. Esc cancels, Backspace clears, MB1 is the click
-- that opened us so it's ignored
function Keybind:_capture(input)
    local key
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.Escape then
            self:_stopRecording()
            return
        end
        if input.KeyCode == Enum.KeyCode.Backspace then
            self:_bind(Enum.KeyCode.Unknown)
            return
        end
        key = input.KeyCode
    elseif
        input.UserInputType == Enum.UserInputType.MouseButton2
        or input.UserInputType == Enum.UserInputType.MouseButton3
    then
        key = input.UserInputType
    end
    if not key then
        return
    end

    if self.isMenuToggle then
        -- the menu toggle cant land on a key an element keybind already owns, else that press
        -- would both fire the element and open/close the window. bail and keep the old binding.
        local clash = self.window:_keybindUsing(key, self)
        if clash then
            self.window:Notify({
                title = locale.resolve("Keybind unavailable"),
                content = string.format(
                    locale.resolve("%s is bound to %s. Kept %s."),
                    keyName(key),
                    clash.name,
                    keyName(self.value)
                ),
            })
            self:_stopRecording()
            self.window:_flashResult(self, false) -- red: rejected
            return
        end
    elseif key == self.window.settings.toggleKeybind then
        -- an element keybind cant clash with the menu toggle key, same double-fire problem the
        -- other way round. bail, tell them, and keep the old binding.
        self.window:Notify({
            title = locale.resolve("Keybind unavailable"),
            content = string.format(
                locale.resolve("%s is the menu toggle key. Kept %s."),
                keyName(key),
                keyName(self.value)
            ),
        })
        self:_stopRecording()
        self.window:_flashResult(self, false) -- red: rejected
        return
    end

    self:_bind(key)
end

-- commit a new binding from the user: store, relabel, notify + autosave
function Keybind:_bind(key)
    self.value = key
    self:_stopRecording()
    self.window:_runGuarded(self, self.onChanged, key)
    self.window:_persist(self)

    self.window:_flashResult(self, true) -- green: bound
end

-- does this input match the bound key (either a KeyCode or a mouse button)
function Keybind:_matches(input)
    local v = self.value
    if typeof(v) ~= "EnumItem" or v == Enum.KeyCode.Unknown then
        return false
    end
    if v.EnumType == Enum.KeyCode then
        return input.KeyCode == v
    elseif v.EnumType == Enum.UserInputType then
        return input.UserInputType == v
    end
    return false
end

-- hold mode: arm after holdThreshold (a quick tap never counts), fire callback(true) then
-- callback(false) once, edge-triggered off this exact press ending.
function Keybind:_beginHold(input)
    if self._holding or self._holdPress then
        return -- already tracking a hold
    end
    local press = {}
    self._holdPress = press

    -- match the release against the exact key that started this hold, not self.value, so a
    -- rebind mid-hold still lets the original key release and fire callback(false).
    local heldKeyCode = input.KeyCode
    local heldInputType = input.UserInputType

    task.delay(self.holdThreshold, function()
        if self._holdPress ~= press then
            return -- released (or rebound) before it armed
        end
        self._holding = true
        self.window:_runGuarded(self, self.callback, true)
    end)

    -- release edge off the global InputEnded (robust to synthetic input, where the original
    -- InputObject's state doesnt always transition). tracked on the window so it cant outlive
    -- Unload.
    local conn
    conn = self.window:Connect(variables.userInputService.InputEnded, function(ended)
        local released = if heldKeyCode ~= Enum.KeyCode.Unknown
            then ended.KeyCode == heldKeyCode
            else ended.UserInputType == heldInputType
        if not released then
            return
        end
        self.window:Disconnect(conn)
        if self._holdPress == press then
            self._holdPress = nil
        end
        if self._holding then
            self._holding = false
            self.window:_runGuarded(self, self.callback, false)
        end
    end)
end

function Keybind:Set(value, skipChanged)
    self.value = coerceKey(value)
    if self.recording then
        self:_stopRecording() -- also relabels + resizes for us
    else
        self.keyLabel.Text = keyName(self.value)
        self:_sizeBox(true)
    end

    if not skipChanged then
        self.window:_runGuarded(self, self.onChanged, self.value)
        self.window:_persist(self)
    end
end

-- Persistence: store the enum type + value so any bound KeyCode or mouse button round-trips.
function Keybind:_serialize()
    return { tostring(self.value.EnumType), self.value.Value }
end

function Keybind:_deserialize(raw)
    -- the saved type is tostring(EnumType), e.g. "Enum.KeyCode", so strip the prefix before lookup
    local enumName = tostring(raw[1]):gsub("^Enum%.", "")
    local enumOk, enumType = pcall(function()
        return Enum[enumName]
    end)
    if not enumOk or not enumType then
        return
    end

    local item = enumItemFromValue(enumType, raw[2])
    if item then
        self:Set(item)
    end
end

function Keybind:_setShown(shown, animate)
    local w = self.window
    if shown then
        w:_revealCommon(self, animate)
        w:_reveal(self.box, { BackgroundTransparency = w.theme.FieldTransparency }, animate)
        w:_reveal(self.boxStroke, { Transparency = 0.85 }, animate)
        w:_reveal(self.keyLabel, { TextTransparency = 0.6 }, animate)
        w:_reveal(self.glow, { Transparency = 0.9 }, animate)
    else
        w:_hideCommon(self, animate)
        w:_reveal(self.box, { BackgroundTransparency = 1 }, animate)
        w:_reveal(self.boxStroke, { Transparency = 1 }, animate)
        w:_reveal(self.keyLabel, { TextTransparency = 1 }, animate)
        w:_reveal(self.glow, { Transparency = 1 }, animate)
    end
end

-- Re-apply the box's theme-driven fill transparency on a runtime ChangeTheme (its colour rides
-- a themeProperty). Called on the visible tab only, so the box is shown.
function Keybind:_refreshTheme()
    variables.tweenService
        :Create(
            self.box,
            TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { BackgroundTransparency = self.window.theme.FieldTransparency }
        )
        :Play()
end

moveable(Keybind)

return Keybind
