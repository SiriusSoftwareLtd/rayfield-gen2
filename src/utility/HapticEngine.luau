--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Haptic feedback. A thin wrapper over HapticEffect that buzzes the player's device
-- (phone, gamepad, VR controller) on two interactions: a press and a notification. We map
-- them to the presets that feel best in practice - the softer UIHover tick for a press, the
-- crisper UIClick for a notification. No-ops on devices without haptics, off from settings.

local variables = require(script.Parent.variables)

local hapticEngine = {}

hapticEngine.enabled = false -- off by default; the settings toggle flips it (see setEnabled)

-- Resolve the presets once. HapticEffect (and its enum) only exist on newer clients, so
-- everything below is gated on this: on an old client `types` stays empty and every call
-- is a no-op. pcall guards the enum lookup too, since indexing a missing value would throw.
type HapticTypes = {
    click: Enum.HapticEffectType?,
    notify: Enum.HapticEffectType?,
}

local types: HapticTypes = {}
local supported, resolvedTypes = pcall(function()
    Instance.new("HapticEffect"):Destroy() -- probe: errors on clients without the class
    return {
        click = Enum.HapticEffectType.UIHover, -- presses use the softer hover tick
        notify = Enum.HapticEffectType.UIClick, -- notifications use the crisper click
    }
end)
if supported then
    types = resolvedTypes
end

-- One reusable effect per preset, made on first use and kept parented for the session.
--
-- These live with the interface, not in the Workspace the docs examples use. Workspace is
-- readable by the game's own scripts, so a pooled effect sitting there is the one piece of
-- Rayfield a game could find by walking the tree - everything else hides behind gethui with
-- a random name. An effect only needs *a* parent to play, not a world one.
local effects: { [Enum.HapticEffectType]: Instance } = {}
local container: Instance? = nil

-- Where new effects get parented. The window hands us its ScreenGui; until then (or after it
-- goes away) fall back to the container every Rayfield gui lives in.
function hapticEngine.setContainer(target: Instance?)
    container = target
end

-- Let go of a gui thats being torn down, without stamping on a container another window may
-- have set since. Passing nil clears whatever is held.
function hapticEngine.releaseContainer(target: Instance?)
    if target == nil or container == target then
        container = nil
    end
end

local function containerFor(): Instance
    if container and container.Parent then
        return container
    end
    return variables.guiContainer
end

local function effectFor(hapticType: Enum.HapticEffectType): Instance?
    local effect = effects[hapticType]
    -- recreate if it was never made, or got destroyed out from under us (Parent goes nil)
    if effect and effect.Parent then
        return effect
    end
    local ok, made = pcall(Instance.new, "HapticEffect")
    if not ok then
        return nil
    end
    local hapticEffect = made :: any
    hapticEffect.Type = hapticType
    local parented = pcall(function()
        made.Parent = containerFor()
    end)
    if not parented then
        made:Destroy()
        return nil
    end
    effects[hapticType] = made
    return made
end

local function play(hapticType: Enum.HapticEffectType?)
    if not hapticType or not hapticEngine.enabled then
        return
    end
    local effect = effectFor(hapticType)
    if effect then
        local hapticEffect = effect :: any
        pcall(hapticEffect.Play, effect)
    end
end

-- tap for a button, switch, tab or any discrete press
function hapticEngine.click()
    play(types.click)
end

-- attention buzz for a notification, toast or popup
function hapticEngine.notify()
    play(types.notify)
end

-- Global on/off for the settings toggle. Turning it off tears the pooled effects down so
-- nothing lingers behind; they're remade lazily if it's turned back on.
function hapticEngine.setEnabled(state: boolean?)
    hapticEngine.enabled = state and true or false
    if not hapticEngine.enabled then
        hapticEngine.teardown()
    end
end

-- Drop the pool without touching the enabled flag, so a window can clean up after itself
-- without deciding haptics for anyone else.
function hapticEngine.teardown()
    for hapticType, effect in effects do
        pcall(effect.Destroy, effect)
        effects[hapticType] = nil
    end
end

return hapticEngine
