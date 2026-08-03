--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- A damped spring, for motion that has a speed rather than a duration.
--
-- A tween is told how long to take, so it covers two pixels and two hundred pixels in the same
-- time, and it starts from a standstill however fast the thing was already travelling. A spring
-- is told where to go instead: it accelerates toward the target, is slowed by its own damping,
-- and arrives carrying whatever speed it has left. Long moves take longer than short ones on
-- their own, and retargeting mid-flight bends the path instead of restarting it.
--
-- That last part is the reason this exists. Closing a window while it is still opening used to
-- snap, because the new tween began from rest. The spring keeps its velocity, so the window
-- turns around and goes back the way it came.

local spring = {}
spring.__index = spring

export type Spring = typeof(setmetatable(
    {} :: {
        position: Vector2,
        velocity: Vector2,
        target: Vector2,
        stiffness: number,
        damping: number,
    },
    spring
))

-- Integration runs at a fixed step regardless of frame rate. A spring stepped with whatever
-- delta the frame happened to take drifts on a slow machine and can leave the rails entirely
-- after a hitch, which is exactly when it is most visible.
local fixedStep = 1 / 240

-- The longest frame the spring will account for in full. Enough substeps to cover it at the
-- fixed step, so a slow frame advances the spring by as much time as actually passed rather
-- than by as much as the cap allowed. Twelve steps only covered 50ms, so at anything under 20
-- FPS the spring ran slower than the clock while the backstop that ends the move kept running
-- on wall time: it came due with the window still travelling and snapped it to the end.
--
-- Past a quarter of a second the frame is a hitch rather than a frame rate, and the missing
-- time is dropped deliberately. Catching up on half a second in one go is a teleport whichever
-- way it is integrated.
-- Capping the frame is what bounds the work: a quarter of a second is 60 steps of arithmetic on
-- two vectors, twice per window, and only while something is actually moving.
spring.maxFrame = 0.25

-- `damping` as a fraction of critical for the given stiffness: 1 arrives without overshooting,
-- below 1 overshoots and settles back, above 1 crawls in. Expressing it this way means the two
-- can be tuned independently, where raw damping has to be recomputed every time stiffness moves.
function spring.new(position: Vector2, stiffness: number, damping: number): Spring
    local self = setmetatable({
        position = position,
        velocity = Vector2.zero,
        target = position,
        stiffness = stiffness,
        damping = 0,
    }, spring)
    spring.tune(self, stiffness, damping)
    return self
end

-- Retune without disturbing where it is or how fast it is going, so a move already under way
-- can be handed different physics rather than being restarted under them.
function spring.tune(self: Spring, stiffness: number, damping: number)
    self.stiffness = stiffness
    self.damping = damping * 2 * math.sqrt(stiffness)
end

function spring.setTarget(self: Spring, target: Vector2)
    self.target = target
end

-- A shove, in pixels per second. Used for the small move against the direction of travel that
-- reads as a thing gathering itself before it goes, which no easing curve can express.
function spring.impulse(self: Spring, velocity: Vector2)
    self.velocity += velocity
end

function spring.step(self: Spring, delta: number): Vector2
    -- All of the frame, up to the hitch cap, spread over as many fixed steps as it takes. The
    -- step size stays at the fixed one rather than growing with the frame, so the integration
    -- is as stable on a slow machine as a fast one.
    local elapsed = math.clamp(delta, 0, spring.maxFrame)
    local steps = math.max(math.ceil(elapsed / fixedStep), 1)
    local step = elapsed / steps

    for _ = 1, steps do
        local acceleration = (self.target - self.position) * self.stiffness - self.velocity * self.damping
        self.velocity += acceleration * step
        self.position += self.velocity * step
    end

    return self.position
end

-- Settled means both near the target and no longer moving. Distance alone would call it done at
-- the top of an overshoot, mid-flight, with the whole return trip still to come.
function spring.settled(self: Spring, tolerance: number): boolean
    return (self.target - self.position).Magnitude <= tolerance and self.velocity.Magnitude <= tolerance * 10
end

-- Put it exactly on a value and stop it dead, for handing control back to whatever owns the
-- property normally.
function spring.snap(self: Spring, position: Vector2)
    self.position = position
    self.target = position
    self.velocity = Vector2.zero
end

return spring
