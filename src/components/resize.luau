--!nonstrict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local Resize = {}
Resize.__index = Resize
Resize.__type = "Resize"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local constants = require(utility.constants)

-- The hit area is deliberately much larger than the mark it draws. A corner is a small target
-- on a phone, and the padding sits over the window's own rounded corner where no element
-- reaches anyway.
local gripSize = 54
local gripInset = 8

-- The bracket at rest, and how much it grows as the cursor moves into the corner. Each arm is
-- driven by its own axis, so approaching along the edge stretches only the arm you are moving
-- toward - the mark leans at the window rather than just swelling.
local armThickness = 2
local armRest = 18
local armReach = 20
local armStretch = 30
local armPress = 30

-- Transparency rather than fixed greys: the bracket has to read the same on every theme, and
-- a light one would swallow a grey picked against the dark default.
local restTransparency = 0.6
local reachTransparency = 0.35
local pressTransparency = 0.15

-- How tightly the window follows the cursor: the fraction of the remaining gap closed per
-- second, as a rate rather than a per-frame step, so the glide is the same at 30fps and 240.
local followRate = 26

-- Two clicks inside this window snap the size back to the one the screen calls for.
local doubleClickWindow = 0.32

-- Below this the follow is close enough that another frame of it would move nothing.
local settleEpsilon = 0.45

local function tween(instance, properties, duration: number)
    variables.tweenService
        :Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), properties)
        :Play()
end

function Resize.new(window)
    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
    }, Resize)

    -- TextButton over ImageButton: nothing to load, and it takes touch the same way the drag
    -- grab does. Parented to the window itself so it rides every move, resize and reveal.
    self.grip = self.window:Create("TextButton", {
        Name = "ResizeGrip",
        BackgroundTransparency = 1,
        Text = "",
        TextTransparency = 1,
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -gripInset, 1, -gripInset),
        Size = UDim2.fromOffset(gripSize, gripSize),
        ZIndex = constants.zIndex.resizeGrip,

        Parent = self.window.main,
    })

    -- Two rounded arms meeting at the corner. Drawn rather than an image so it re-tints with
    -- the theme for free and stretches without a slice scale to keep honest.
    local function arm(horizontal: boolean)
        local bar = self.window:Create("Frame", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.fromScale(1, 1),
            Size = if horizontal
                then UDim2.fromOffset(armRest, armThickness)
                else UDim2.fromOffset(armThickness, armRest),
            BorderSizePixel = 0,
            BackgroundTransparency = restTransparency,
            ZIndex = constants.zIndex.resizeGrip,

            Parent = self.grip,
        }, { BackgroundColor3 = "TitlingColor" })

        self.window:Create("UICorner", {
            CornerRadius = UDim.new(1, 0),

            Parent = bar,
        })

        return bar
    end

    self.horizontalArm = arm(true)
    self.verticalArm = arm(false)

    local resizing = false
    local hovering = false
    local pointer: Vector2? = nil
    local lastClick = -math.huge

    -- Where the grab started, in pointer and in pixels, so the drag is measured against the
    -- size at the moment it began rather than accumulating rounding every frame.
    local startPointer = Vector2.zero
    local startSize = Vector2.zero
    local resetOnSettle = false

    -- Where the window is heading and where it currently is. Splitting the two is what makes
    -- the glide possible: the cursor moves the target, the frame loop chases it.
    local target = Vector2.zero
    local visual = Vector2.zero

    local function currentSize(): Vector2
        return Vector2.new(self.window.size.X.Offset, self.window.size.Y.Offset)
    end

    -- The cursor is reported in a space that may or may not carry the topbar inset, while
    -- AbsolutePosition never does. Rather than assume a sign for it, resolve it from the
    -- geometry: a cursor over the grip must land inside the grip's rect, so if the raw reading
    -- doesnt, whichever of y +/- inset does is the space the two agree in. Remember it, because
    -- once the cursor leaves the rect there is nothing left to resolve against.
    local insetOffset = 0

    local function resolveY(y: number, top: number, height: number): number
        if y >= top and y <= top + height then
            return y
        end

        local inset = 0
        pcall(function()
            inset = variables.guiService:GetGuiInset().Y
        end)

        for _, candidate in { y + inset, y - inset } do
            if candidate >= top and candidate <= top + height then
                insetOffset = candidate - y
                return candidate
            end
        end

        return y + insetOffset
    end

    -- How far into the grip the pointer is, per axis, 0 at the outer edge and 1 in the corner.
    local function reach(): Vector2
        local position, size = self.grip.AbsolutePosition, self.grip.AbsoluteSize
        local at = pointer or variables.userInputService:GetMouseLocation()
        local x = (at.X - position.X) / math.max(size.X, 1)
        local y = (resolveY(at.Y, position.Y, size.Y) - position.Y) / math.max(size.Y, 1)
        return Vector2.new(math.clamp(x, 0, 1), math.clamp(y, 0, 1))
    end

    local function setArms(horizontal: number, vertical: number, transparency: number, duration: number)
        tween(self.horizontalArm, {
            Size = UDim2.fromOffset(horizontal, armThickness),
            BackgroundTransparency = transparency,
        }, duration)
        tween(self.verticalArm, {
            Size = UDim2.fromOffset(armThickness, vertical),
            BackgroundTransparency = transparency,
        }, duration)
    end

    local function leanArms(duration: number)
        local into = reach()
        setArms(armReach + into.X * armStretch, armReach + into.Y * armStretch, reachTransparency, duration)
    end

    local function pressArms()
        setArms(armPress, armPress, pressTransparency, 0.12)
    end

    local function restArms()
        setArms(armRest, armRest, restTransparency, 0.18)
    end

    -- The size the screen can carry, held to whole pixels the same way the window is.
    local function apply(size: Vector2)
        self.window:_applyUserSize(size)
    end

    local function stopFollowing()
        if self.following then
            self.window:Disconnect(self.following)
            self.following = nil
        end
    end

    local function startFollowing()
        if self.following then
            return
        end

        visual = currentSize()
        self.following = self.window:Connect(variables.runService.RenderStepped, function(delta: number)
            -- a grab that goes stale under us (hidden, minimised, mid-animation) drops here
            -- rather than waking up later and yanking the window to wherever the cursor drifted
            if resizing and not self.window:_interactive() then
                resizing = false
            end

            -- exponential smoothing on a rate, so the glide is frame-rate independent
            local alpha = 1 - math.exp(-delta * followRate)
            visual += (target - visual) * alpha
            apply(visual)

            if not resizing and (target - visual).Magnitude <= settleEpsilon then
                visual = target
                apply(target)
                stopFollowing()

                -- a glide back to the fitted size ends with the override let go, so the window
                -- goes back to following the screen rather than holding the size it landed on
                if resetOnSettle then
                    resetOnSettle = false
                    self.window:_resetUserSize()
                end
            end
        end)
    end

    local function beginResize(at: Vector2)
        resizing = true
        startPointer = at
        startSize = currentSize()
        target = startSize
        pressArms()
        startFollowing()
    end

    local function endResize()
        if not resizing then
            return
        end
        resizing = false

        if hovering then
            leanArms(0.18)
        else
            restArms()
        end
    end

    -- Touch reports where it is; a mouse has to be asked.
    local function pointerOf(input): Vector2
        if input and input.UserInputType.Name == "Touch" and input.Position then
            return Vector2.new(input.Position.X, input.Position.Y)
        end
        return variables.userInputService:GetMouseLocation()
    end

    self.window:Connect(self.grip.InputBegan, function(input, processed)
        if processed then
            return
        end

        local inputType = input.UserInputType.Name
        if inputType ~= "MouseButton1" and inputType ~= "Touch" then
            return
        end

        if not self.window:_interactive() or not self.window.settings.resizable then
            return
        end

        -- two clicks in quick succession is the shortcut back to the fitted size, so it must be
        -- read before the grab arms, or the drag that the second click starts fights the snap
        local now = os.clock()
        if now - lastClick < doubleClickWindow then
            lastClick = -math.huge
            resizing = false
            resetOnSettle = true
            target = self.window:_fittedSize()
            restArms()
            startFollowing()
            return
        end
        lastClick = now

        beginResize(pointerOf(input))
    end)

    self.window:Connect(self.grip.MouseEnter, function()
        hovering = true
        if not resizing and self.window:_interactive() then
            leanArms(0.18)
        end
    end)

    self.window:Connect(self.grip.MouseLeave, function()
        hovering = false
        pointer = nil
        if not resizing then
            restArms()
        end
    end)

    -- Moving inside the grip leans the bracket further toward the corner as you approach it.
    -- InputChanged rather than MouseMoved so a finger sliding over it leans the same way.
    self.window:Connect(self.grip.InputChanged, function(input)
        if resizing then
            return
        end

        local inputType = input.UserInputType.Name
        if inputType ~= "MouseMovement" and inputType ~= "Touch" then
            return
        end

        pointer = if inputType == "Touch" and input.Position
            then Vector2.new(input.Position.X, input.Position.Y)
            else nil

        if self.window:_interactive() then
            leanArms(0.14)
        end
    end)

    self.window:Connect(variables.userInputService.InputChanged, function(input)
        if not resizing then
            return
        end

        local inputType = input.UserInputType.Name
        if inputType ~= "MouseMovement" and inputType ~= "Touch" then
            return
        end

        -- twice the distance dragged: the window is centre-anchored, so both edges move and the
        -- corner under the cursor only covers half of whatever the size gains
        local moved = (pointerOf(input) - startPointer) * 2
        target = self.window:_boundUserSize(startSize + moved)
    end)

    self.window:Connect(variables.userInputService.InputEnded, function(input)
        local inputType = input.UserInputType.Name
        if inputType == "MouseButton1" or inputType == "Touch" then
            endResize()
        end
    end)

    -- alt-tabbing with the button still down never delivers InputEnded
    self.window:Connect(variables.userInputService.WindowFocusReleased, endResize)

    -- A collapsed or hidden window has no corner to grab, and the grip would otherwise sit over
    -- the pill. The window's own size is the one signal every one of those paths goes through.
    self.window:Connect(self.window.main:GetPropertyChangedSignal("Size"), function()
        self:_refresh()
    end)

    return self
end

-- Show the grip only where there is a window corner to take hold of.
function Resize:_refresh()
    if not self.grip then
        return
    end
    local window = self.window
    self.grip.Visible = window.settings.resizable and not window.minimised and not window.hidden
end

-- Show or hide the grip. The window keeps whatever size it was dragged to when the grip goes
-- away: turning resizing off stops further changes, it does not undo the ones already made.
function Resize:SetEnabled(state: boolean)
    self.window.settings.resizable = state
    self:_refresh()
end

return Resize
