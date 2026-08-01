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

-- The corner mark: a rounded bracket, sliced so the curve holds its radius while the arms
-- stretch. Its size is driven per axis by where the pointer sits in the grip, so it leans the
-- way you are approaching from rather than just swelling.
local markImage = "rbxassetid://86527207319523"
local markSlice = Rect.new(51, 52, 51, 52)
local markSliceScale = 0.5
local markRest = 18
local markReach = 20
local markStretch = 30
local markPress = 30

local restColor = Color3.fromRGB(90, 90, 98)
local reachColor = Color3.fromRGB(125, 125, 135)
local pressColor = Color3.fromRGB(150, 150, 160)

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

    -- Parented to the window itself, so it rides every move, resize and reveal.
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

    -- 9-sliced, so the curve keeps its radius however far the arms are stretched.
    self.mark = self.window:Create("ImageLabel", {
        Name = "Mark",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.fromScale(1, 1),
        Size = UDim2.fromOffset(markRest, markRest),
        Image = markImage,
        ImageColor3 = restColor,
        -- Animation
        ImageTransparency = 1, -- In = 0, once the window has finished coming in
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = markSlice,
        SliceScale = markSliceScale,
        ZIndex = constants.zIndex.resizeGrip + 1,

        Parent = self.grip,
    })

    local resizing = false
    local hovering = false
    local pointer: Vector2? = nil
    local lastClick = -math.huge

    -- The touch that started the resize. Another finger landing on the screen sends its own
    -- InputChanged and InputEnded, and without holding on to this one they would move and end a
    -- resize they had nothing to do with.
    local held: InputObject? = nil

    -- Whether this grab came from a finger at all. A mouse resize leaves `held` empty, so
    -- without it a touch on a device carrying both could still move and end the resize.
    local touching = false

    -- How far the pointer may travel and still count as a press rather than a drag. A resize
    -- that only moved a pixel or two was never meant to be one, and a resize that moved further
    -- must not arm the double click, or the next grab resets the window instead of resizing it.
    local stillDistance = 6

    -- Where the grab started, in pointer and in pixels, so the drag is measured against the
    -- size at the moment it began rather than accumulating rounding every frame.
    local startPointer = Vector2.zero
    local pressedAt: Vector2? = nil
    local startSize = Vector2.zero
    local resetOnSettle = false

    -- Whether this grab has earned the right to pin a size. A press that never travelled is a
    -- click, and pinning on a click leaves the window holding a size the user never chose,
    -- which then survives the next viewport change instead of refitting.
    local committed = false

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

    -- How far the pointer sits from the corner, per axis, 0 in the corner itself and 1 at the
    -- grip's far edge.
    local function reach(): Vector2
        local position, size = self.grip.AbsolutePosition, self.grip.AbsoluteSize
        local at = pointer or variables.userInputService:GetMouseLocation()
        -- measured out from the corner, so the mark is at its smallest where the corner itself
        -- is and reaches furthest as the pointer comes in from the window
        local x = (at.X - position.X) / math.max(size.X, 1)
        local y = (resolveY(at.Y, position.Y, size.Y) - position.Y) / math.max(size.Y, 1)
        return Vector2.new(1 - math.clamp(x, 0, 1), 1 - math.clamp(y, 0, 1))
    end

    -- The mark leans toward the pointer by default. Held still it keeps its resting size and
    -- only takes the colour, so the grip still answers to being hovered and pressed without the
    -- corner of the window moving while you are trying to aim at it.
    local function setMark(horizontal: number, vertical: number, color: Color3, duration: number)
        local still = self.window.settings and self.window.settings.gripAnimation == false
        tween(self.mark, {
            Size = if still then UDim2.fromOffset(markRest, markRest) else UDim2.fromOffset(horizontal, vertical),
            ImageColor3 = color,
        }, duration)
    end

    local function leanMark(duration: number)
        local into = reach()
        setMark(markReach + into.X * markStretch, markReach + into.Y * markStretch, reachColor, duration)
    end

    local function pressMark()
        setMark(markPress, markPress, pressColor, 0.12)
    end

    local function restMark()
        setMark(markRest, markRest, restColor, 0.18)
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
            if committed then
                apply(visual)
            end

            if not resizing and (target - visual).Magnitude <= settleEpsilon then
                visual = target
                if committed then
                    apply(target)
                end
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
        -- a press that lands during the glide back to the fitted size takes the window over, so
        -- the reset it interrupted must not still be waiting to fire when this one settles
        resetOnSettle = false
        -- nothing is pinned until the pointer has travelled far enough to be a drag rather than
        -- a click, or a click on the grip would leave the window holding its own size for good
        committed = false
        pressedAt = at
        startPointer = at
        startSize = currentSize()
        target = startSize
        pressMark()
        startFollowing()
    end

    local function endResize(at: Vector2?)
        if not resizing then
            return
        end
        resizing = false
        held = nil
        touching = false

        -- read, not cleared: the glide carries on after the button is up and still has to
        -- write. beginResize is what clears it, for the next grab.
        local wasCommitted = committed

        -- a press that stayed put is a click, and two of those in quick succession are the
        -- reset. One that travelled was a resize, and must not arm it, including one that
        -- wandered out and came back: the distance at the end says nothing about where it went.
        local travelled = if at and pressedAt then (at - pressedAt).Magnitude else math.huge
        lastClick = if not wasCommitted and travelled <= stillDistance then os.clock() else -math.huge

        if hovering then
            leanMark(0.18)
        else
            restMark()
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
        if lastClick > -math.huge and now - lastClick < doubleClickWindow then
            lastClick = -math.huge
            resizing = false
            resetOnSettle = true
            committed = true
            target = self.window:_fittedSize()
            restMark()
            startFollowing()
            return
        end
        -- armed on release instead, and only if the pointer stayed put. Arming here counted
        -- every press as the first half of a double click, including presses that became drags.
        lastClick = -math.huge
        touching = inputType == "Touch"
        held = if touching then input else nil

        beginResize(pointerOf(input))
    end)

    self.window:Connect(self.grip.MouseEnter, function()
        hovering = true
        if not resizing and self.window:_interactive() then
            leanMark(0.18)
        end
    end)

    self.window:Connect(self.grip.MouseLeave, function()
        hovering = false
        pointer = nil
        if not resizing then
            restMark()
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
            leanMark(0.14)
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

        -- a second finger on the screen sends its own events, and so does a finger during a
        -- mouse resize on a device carrying both. Only what started this resize gets to move it.
        if touching then
            if input ~= held then
                return
            end
        elseif inputType ~= "MouseMovement" then
            return
        end

        local at = pointerOf(input)
        if not committed then
            if (at - startPointer).Magnitude <= stillDistance then
                return
            end
            committed = true
        end

        -- twice the distance dragged: the window is centre-anchored, so both edges move and the
        -- corner under the cursor only covers half of whatever the size gains
        local moved = (at - startPointer) * 2
        target = self.window:_boundUserSize(startSize + moved)
    end)

    self.window:Connect(variables.userInputService.InputEnded, function(input)
        local inputType = input.UserInputType.Name
        if inputType ~= "MouseButton1" and inputType ~= "Touch" then
            return
        end

        -- and only what started it gets to end it
        if touching then
            if input ~= held then
                return
            end
        elseif inputType ~= "MouseButton1" then
            return
        end

        endResize(pointerOf(input))
    end)

    -- alt-tabbing with the button still down never delivers InputEnded
    self.window:Connect(variables.userInputService.WindowFocusReleased, function()
        endResize()
    end)

    -- A collapsed or hidden window has no corner to grab, and the grip would otherwise sit over
    -- the pill. The window's own size is the one signal every one of those paths goes through.
    self.window:Connect(self.window.main:GetPropertyChangedSignal("Size"), function()
        self:_refresh()
    end)

    return self
end

-- Put the mark back to its resting size, for a change of mind about it leaning: without this it
-- keeps whatever size the last lean left it at until the pointer next touches the grip.
function Resize:_settleMark()
    if self.mark then
        tween(self.mark, { Size = UDim2.fromOffset(markRest, markRest), ImageColor3 = restColor }, 0.18)
    end
end

-- Show the grip only where there is a window corner to take hold of.
function Resize:_refresh()
    if not self.grip then
        return
    end
    local window = self.window
    self.grip.Visible = window.settings.resizable and not window.minimised and not window.hidden
end

-- Fade the mark with the window it belongs to. The window comes in a piece at a time and the
-- grip is the last thing on it, so it arrives after the elements have finished rather than
-- sitting in the corner of a frame that is still assembling itself.
function Resize:_setShown(shown: boolean, animate: boolean?)
    if not self.mark then
        return
    end

    local transparency = if shown then 0 else 1
    if animate == false then
        self.mark.ImageTransparency = transparency
        return
    end

    tween(self.mark, { ImageTransparency = transparency, Size = UDim2.fromOffset(markRest, markRest) }, 0.35)
end

-- Show or hide the grip. The window keeps whatever size it was dragged to when the grip goes
-- away: turning resizing off stops further changes, it does not undo the ones already made.
function Resize:SetEnabled(state: boolean)
    self.window.settings.resizable = state
    self:_refresh()
end

return Resize
