--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Picks the window size for a given screen. Anything roomy keeps the default untouched; a
-- short screen trades height for a slice of width so the content area doesnt shrink with it.

local windowSizing = {}

-- Default window size, and the smallest we'll shrink it to on a tiny screen. The minimum is a
-- floor, not a guarantee: a screen too small to hold it gets a window that fits instead.
local defaultSize = Vector2.new(475, 500)
local minSize = Vector2.new(300, 285)

-- Most of the screen we'll ever take, per axis, plus a pixel floor so a huge display still
-- gets a margin. Fractions rather than a flat inset: a fixed margin only ever bites on the
-- small screens least able to afford it, which is how a phone ended up filled top to bottom
-- while half its width sat unused. The vertical cap is deliberately the tighter of the two -
-- an open window should always read as sitting on the screen rather than filling it, and it
-- also clears the Roblox topbar for free, since a centred window leaves 15% above it.
-- plain numbers, not a Vector2: its components are 32 bit, so 0.70 would come back as
-- 0.69999998 and the cap would sit a pixel under what it says on some screens
local maxOccupancyX, maxOccupancyY = 0.86, 0.70
local marginFloorX, marginFloorY = 24, 28

-- When a short screen forces the height down, the window earns a little width back, capped
-- by the viewport and by how wide we'll ever let it read. Scales with the height actually
-- lost, so a screen tall enough for the full height keeps the default width exactly.
local widthCompensation = 80
local maxAspectRatio = 1.95

-- Below this, either axis is a viewport we dont believe - a camera mid-init or a stray 1x1
-- report. Sizing off one would pin the window at its floor for the session, so take the
-- default and let the caller's reconcile correct it once the screen reports properly.
local minPlausibleViewport = 200

-- What a hand-dragged window leaves around itself. Enough to keep the corners and the shadow
-- clear of the screen edge without arguing with a size the user chose deliberately.
local manualMargin = 40

-- The floor for a hand-dragged window, above the one the automatic fit will drop to on a small
-- screen. There the whole screen is small and a cramped window is still the best on offer; here
-- there is room, so the floor is the width the top bar and the widest element layout need to
-- draw properly rather than the least the library can survive.
local manualMinSize = Vector2.new(380, 320)

windowSizing.defaultSize = defaultSize
windowSizing.minSize = minSize
windowSizing.manualMinSize = manualMinSize

-- How much height we had to give up, 0 on a screen tall enough and 1 once pinned to the floor.
local function heightDeficit(height: number): number
    return math.clamp((defaultSize.Y - height) / (defaultSize.Y - minSize.Y), 0, 1)
end

-- Hold a size the user dragged out to what the screen can carry. Separate from `fit` because the
-- two answer different questions: `fit` picks a size for a screen, this one keeps a size the user
-- already picked. Running a manual size back through `fit` would just undo it.
function windowSizing.clampUserSize(size: Vector2, viewport: Vector2?): Vector2
    -- the floor first and always: a window under it breaks its own top bar, whatever the screen says
    local width = math.max(math.floor(size.X), manualMinSize.X)
    local height = math.max(math.floor(size.Y), manualMinSize.Y)

    -- a viewport we dont believe cant be clamped against - a camera mid-init reports one, and
    -- sizing off it would pull a window the user just dragged out back to the floor and leave
    -- it there. hand the size back and let the caller's reconcile clamp it once the screen reports.
    if not viewport or viewport.X < minPlausibleViewport or viewport.Y < minPlausibleViewport then
        return Vector2.new(width, height)
    end

    -- the screen less a margin, rather than the occupancy caps `fit` works to. those caps say a
    -- window we size ourselves should read as sitting on the screen instead of filling it, which
    -- is a judgement about a size the user did not ask for - having dragged the corner out, they
    -- are entitled to the screen. same reason theres no aspect ceiling here: holding a dragged
    -- size to one would stop the grip dead halfway through a drag that was meant.
    local availableX = viewport.X - manualMargin
    local availableY = viewport.Y - manualMargin

    -- the screen beats the floor, the same way `fit` gives the floor up rather than overflow a
    -- screen too small to hold it
    return Vector2.new(math.floor(math.min(width, availableX)), math.floor(math.min(height, availableY)))
end

function windowSizing.fit(viewport: Vector2?): UDim2
    if not viewport or viewport.X < minPlausibleViewport or viewport.Y < minPlausibleViewport then
        return UDim2.fromOffset(defaultSize.X, defaultSize.Y)
    end

    local availableX = math.min(viewport.X * maxOccupancyX, viewport.X - marginFloorX)
    local availableY = math.min(viewport.Y * maxOccupancyY, viewport.Y - marginFloorY)

    -- the floor gives way to the screen: a viewport too small to hold it gets a smaller window
    -- rather than one hanging off the edge, so the occupancy caps hold at every size. settle the
    -- height to whole pixels first, so the aspect cap is measured against the height we ship
    -- rather than a fraction that rounds away underneath it.
    local height = math.floor(math.min(math.clamp(availableY, minSize.Y, defaultSize.Y), availableY))
    local deficit = heightDeficit(height)
    local width = math.max(defaultSize.X + widthCompensation * deficit, minSize.X)

    -- the screen and the aspect ceiling are the hard limits, so they are applied after the
    -- floor has lifted the width: a minimum that can push back past a cap is not a cap.
    -- floor, not round: rounding up can carry the result back past those same limits.
    return UDim2.fromOffset(math.floor(math.min(width, availableX, height * maxAspectRatio)), height)
end

return windowSizing
