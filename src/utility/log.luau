-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Rayfield's own console output. Silenced under secure mode so the library never announces
-- itself through warn/print, both of which anti-cheats hook. The game's and the dev's own
-- output are left alone; this only gags Rayfield.

local runtime = require(script.Parent.runtime)

local log = {}

local suppressPredicate = function()
    return runtime.secureMode
end

local function shouldSuppress()
    local testHelpers = _G.__RAYFIELD_TEST_HELPERS
    local isTestEnvironment = type(testHelpers) == "table" and type(testHelpers.requireUtility) == "function"
    if isTestEnvironment and _G.__RAYFIELD_TEST_VERBOSE_LOGS ~= true then
        return true
    end
    return suppressPredicate()
end

function log.setSuppressPredicate(predicate)
    suppressPredicate = if type(predicate) == "function"
        then predicate
        else function()
            return runtime.secureMode
        end
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
