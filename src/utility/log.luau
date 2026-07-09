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
