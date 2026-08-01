--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Moves an element from one place in its parent to another without it jumping first. Layouts
-- that switch at a width threshold cross it while a window is being resized by hand, so the
-- switch happens in front of the person doing it rather than between one open and the next.

local variables = require(script.Parent.variables)

local reflow = {}

export type Target = {
    AnchorPoint: Vector2?,
    Position: UDim2?,
    Size: UDim2?,
}

reflow.info = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- An anchor change is a change in what the position means, not a move, so tweening across one
-- swings the element through somewhere it was never meant to be. Take the new anchor at once and
-- rewrite the position to the one that leaves the element exactly where it already is; the tween
-- then has an honest place to start from.
local function adoptAnchor(instance: GuiObject, anchor: Vector2)
    local current = instance.AnchorPoint
    if current == anchor then
        return
    end

    local shift = (anchor - current) * instance.AbsoluteSize
    local position = instance.Position
    instance.AnchorPoint = anchor
    instance.Position =
        UDim2.new(position.X.Scale, position.X.Offset + shift.X, position.Y.Scale, position.Y.Offset + shift.Y)
end

-- Apply a layout. `animate` false lands it at once, which is what a build wants, or a window that
-- is not on screen: there is nothing to watch, and a tween would only be something else to fight
-- when it opens.
function reflow.morph(instance: GuiObject, target: Target, animate: boolean, info: TweenInfo?)
    if target.AnchorPoint then
        adoptAnchor(instance, target.AnchorPoint)
    end

    local moving: { [string]: any } = {}
    if target.Position then
        moving.Position = target.Position
    end
    if target.Size then
        moving.Size = target.Size
    end
    if not next(moving) then
        return
    end

    if not animate then
        local raw = instance :: any
        for property, value in moving do
            raw[property] = value
        end
        return
    end

    variables.tweenService:Create(instance, info or reflow.info, moving):Play()
end

return reflow
