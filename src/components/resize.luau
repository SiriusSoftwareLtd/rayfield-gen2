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

-- Grip geometry. The hit area is deliberately larger than the lines it draws: a corner is a
-- small target on a phone, and the padding costs nothing since it sits over the window's own
-- rounded corner where no element can reach anyway.
local gripSize = 26
local gripInset = 4
local lineThickness = 2

-- The two diagonals, longest first. Lengths in pixels, offset is how far the line's centre sits
-- from the grip's, along the corner's diagonal.
local lines = {
    { length = 15, offset = 0 },
    { length = 8, offset = 4 },
}

local restTransparency = 0.55
local hoverTransparency = 0.15

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

    self.lines = {}

    for _, line in lines do
        -- rotated bars rather than an icon: an asset would have to be uploaded, moderated and
        -- then re-tinted per theme, and this is two rectangles
        local bar = self.window:Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, line.offset, 0.5, line.offset),
            Size = UDim2.fromOffset(line.length, lineThickness),
            Rotation = -45,
            BorderSizePixel = 0,
            BackgroundTransparency = restTransparency,
            ZIndex = constants.zIndex.resizeGrip,

            Parent = self.grip,
        }, { BackgroundColor3 = "TitlingColor" })

        self.window:Create("UICorner", {
            CornerRadius = UDim.new(1, 0),

            Parent = bar,
        })

        table.insert(self.lines, bar)
    end

    local function fade(transparency: number)
        for _, bar in self.lines do
            variables.tweenService
                :Create(bar, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundTransparency = transparency,
                })
                :Play()
        end
    end

    local resizing = false
    local startSize = Vector2.zero
    local startMouse = Vector2.zero
    local startPosition = UDim2.new()

    -- Letting go, however it happens: the button coming up, focus lost, or the window going
    -- away under the grab. Mirrors the drag grab, for the same reason - a grab left armed
    -- resumes against a cursor that has since moved somewhere else entirely.
    local function releaseResize()
        if not resizing then
            return
        end
        resizing = false
        fade(restTransparency)
    end

    self.window:Connect(self.grip.InputBegan, function(input, processed)
        if processed then
            return
        end

        local inputType = input.UserInputType.Name
        if inputType ~= "MouseButton1" and inputType ~= "Touch" then
            return
        end

        -- a grab started mid-reveal would fight the tween thats still sizing the window
        if not self.window:_interactive() or not self.window.settings.resizable then
            return
        end

        resizing = true
        startSize = self.window.main.AbsoluteSize
        startMouse = variables.userInputService:GetMouseLocation()
        startPosition = self.window.main.Position
        fade(hoverTransparency)
    end)

    self.window:Connect(self.grip.MouseEnter, function()
        if not resizing and self.window:_interactive() then
            fade(hoverTransparency)
        end
    end)

    self.window:Connect(self.grip.MouseLeave, function()
        if not resizing then
            fade(restTransparency)
        end
    end)

    self.window:Connect(variables.userInputService.InputEnded, function(input)
        local inputType = input.UserInputType.Name
        if inputType == "MouseButton1" or inputType == "Touch" then
            releaseResize()
        end
    end)

    -- alt-tabbing with the button still down never delivers InputEnded
    self.window:Connect(variables.userInputService.WindowFocusReleased, releaseResize)

    self.window:Connect(variables.runService.RenderStepped, function()
        if not resizing then
            return
        end

        if not self.window:_interactive() then
            releaseResize()
            return
        end

        local delta = variables.userInputService:GetMouseLocation() - startMouse
        local applied = self.window:_applyUserSize(startSize + delta)

        -- the window is centre-anchored, so growing it alone would walk both edges outward and
        -- the grip would drift away from the cursor at half speed. move the centre by half of
        -- what the size gained and the opposite corner stays put, which is the corner the user
        -- is measuring against while they drag this one.
        local shift = (applied - startSize) / 2
        self.window.main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + shift.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + shift.Y
        )
        self.window:_clampToScreen()
        self.window:_syncDragBar()
    end)

    return self
end

-- Show or hide the grip. The window keeps whatever size it was dragged to when the grip goes
-- away: turning resizing off is about stopping further changes, not undoing the ones made.
function Resize:SetEnabled(state: boolean)
    if self.grip then
        self.grip.Visible = state
    end
end

return Resize
