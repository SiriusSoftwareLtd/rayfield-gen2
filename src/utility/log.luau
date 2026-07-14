-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Rayfield's own console output. Silenced under secure mode so the library never announces
-- itself through warn/print, both of which anti-cheats hook. The game's and the dev's own
-- output are left alone; this only gags Rayfield.

local variables = require(script.Parent.variables)

local log = {}

function log.warn(...)
    if variables.secureMode then
        return
    end
    warn(...)
end

function log.print(...)
    if variables.secureMode then
        return
    end
    print(...)
end

return log
