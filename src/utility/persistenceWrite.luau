--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Crash-safe writes for the persistence layer.

local filesystem = require(script.Parent.filesystem)

local persistenceWrite = {}

local parkedExtension = ".saving"

-- Where a save parks its new copy while it works.
function persistenceWrite.tempPathFor(fullPath: string): string
    return fullPath .. parkedExtension
end

-- Executors give us no rename, so this is the next best thing: park a whole copy beside the
-- real file, read it back, then overwrite. Die mid-overwrite and the parked copy is still
-- intact for the next load to pick up. Throws on failure, callers pcall.
function persistenceWrite.write(dir: string, fullPath: string, contents: string)
    local tempPath = persistenceWrite.tempPathFor(fullPath)

    filesystem.ensureDir(dir)
    filesystem.writefile(tempPath, contents)

    -- a short read back means the disk is full or gone. stop here rather than shred the real file
    if filesystem.readfile(tempPath) ~= contents then
        error("parked copy did not write cleanly")
    end

    filesystem.writefile(fullPath, contents)
    pcall(filesystem.delfile, tempPath)
end

return persistenceWrite
