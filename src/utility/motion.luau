--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- How fast the interface animates, in one place.
--
-- Every animation in the library is either a tween or a spring. Tweens are told a duration, so
-- speeding them up means dividing it. Springs are told a stiffness and arrive when they arrive,
-- and their settle time goes with the square root of that, so the same change of pace means
-- multiplying stiffness by the square of the speed. Both live here so the two cannot drift
-- apart, which is what would happen if each were tuned by hand.
--
-- This is deliberately library wide rather than per window. It is a preference about motion,
-- closer to a system setting than to a property of one menu, and a script with two windows
-- open should not animate at two different speeds.

local motion = {}

-- 1 is the pace everything was designed at. Higher is quicker.
local speed = 1

-- Below a quarter the interface feels broken rather than slow, and above three the animations
-- are too short to read as motion at all.
local minimum, maximum = 0.25, 3

-- Tweens are rebuilt rather than mutated: TweenInfo is immutable, and the fields have to be
-- carried across by hand because there is no constructor that takes one.
local function rescale(info: TweenInfo): TweenInfo
    if speed == 1 then
        return info
    end

    return TweenInfo.new(
        info.Time / speed,
        info.EasingStyle,
        info.EasingDirection,
        info.RepeatCount,
        info.Reverses,
        info.DelayTime / speed
    )
end

-- Anything displaying the speed, keyed by whoever registered it so it can drop itself when it
-- goes away. The speed is one library wide number, so a second window's slider would otherwise
-- sit showing the pace the library stopped animating at.
local listeners: { [any]: (number) -> () } = {}

function motion.subscribe(key: any, callback: (speed: number) -> ())
    listeners[key] = callback
end

function motion.unsubscribe(key: any)
    listeners[key] = nil
end

function motion.setSpeed(value: number)
    if type(value) ~= "number" or value ~= value then
        return -- nan included: it would poison every duration downstream
    end

    local clamped = math.clamp(value, minimum, maximum)
    if clamped == speed then
        return
    end
    speed = clamped

    for _, callback in listeners do
        task.spawn(callback, speed) -- spawned so one bad listener cannot stop the others
    end
end

function motion.getSpeed(): number
    return speed
end

function motion.range(): (number, number)
    return minimum, maximum
end

-- A duration scaled to the current speed.
function motion.info(info: TweenInfo): TweenInfo
    return rescale(info)
end

-- The same scaling for a plain number of seconds, for the waits that exist to run one animation
-- after another. A tween's duration is scaled by the handle every animation is created through,
-- but a task.delay sitting beside it is not, so off 1x the delay and the tween it is waiting for
-- disagree: the popup would be destroyed a second before its fade finished, and the chrome would
-- fade back in over a window still on its way open.
--
-- This is for sequencing only. A wait that holds something on screen long enough to read, or
-- that retries a download, is not animation and does not belong here.
function motion.duration(seconds: number): number
    return seconds / speed
end

-- A spring stiffness scaled to the current speed. Squared because a spring's settle time goes
-- with the square root of its stiffness, so this is what makes a spring and a tween of the same
-- nominal length still agree once the speed moves.
function motion.stiffness(base: number): number
    return base * speed * speed
end

return motion
