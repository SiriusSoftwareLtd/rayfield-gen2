--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Rayfield's own console output. Silenced under secure mode so the library never announces
-- itself through warn/print, both of which anti-cheats hook. The game's and the dev's own
-- output are left alone; this only gags Rayfield.

local runtime = require(script.Parent.runtime)

local log = {}

type SuppressPredicate = () -> boolean

local function defaultSecureModeSource(): boolean
    return runtime.secureMode
end

local secureModeSource: SuppressPredicate = defaultSecureModeSource
local suppressPredicate: SuppressPredicate? = nil

-- variables.luau points this at its mutable secureMode once it loads; until then the
-- runtime snapshot answers. nil restores the default.
function log.setSecureModeSource(source: SuppressPredicate?)
    secureModeSource = if type(source) == "function" then source else defaultSecureModeSource
end

-- extra gag for embedders (the test runner uses this), layered over secure mode so
-- loading variables never clobbers it. nil clears it.
function log.setSuppressPredicate(predicate: SuppressPredicate?)
    suppressPredicate = if type(predicate) == "function" then predicate else nil
end

local function shouldSuppress(): boolean
    if suppressPredicate and suppressPredicate() then
        return true
    end
    return secureModeSource()
end

function log.warn(...)
    if shouldSuppress() then
        return
    end
    warn(...)
end

function log.print(...)
    if shouldSuppress() then
        return
    end
    print(...)
end

return log
