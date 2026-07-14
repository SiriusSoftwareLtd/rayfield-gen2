--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Filesystem Abstraction
-- Uses native executor functions when available, simulates with instances

local services = require(script.Parent.services)
-- local variables = require(script.Parent.variables)

local filesystem = {}

local isStudio = services.getService("RunService"):IsStudio()
local hasNativeFS = not isStudio and typeof(writefile) == "function"

if hasNativeFS then
    -- Native executor environment - wrap globals directly

    function filesystem.writefile(path: string, content: string)
        writefile(path, content)
    end

    function filesystem.readfile(path: string): string
        return readfile(path)
    end

    function filesystem.appendfile(path: string, content: string)
        appendfile(path, content)
    end

    function filesystem.isfile(path: string): boolean
        return isfile(path)
    end

    function filesystem.delfile(path: string)
        delfile(path)
    end

    function filesystem.listfiles(folder: string): { string }
        return listfiles(folder)
    end

    function filesystem.makefolder(path: string)
        makefolder(path)
    end

    function filesystem.isfolder(path: string): boolean
        return isfolder(path)
    end

    function filesystem.delfolder(path: string)
        delfolder(path)
    end
elseif isStudio then
    -- Studio simulation using Instance hierarchy under ReplicatedStorage.
    -- Files are StringValues, folders are Folders. Glass is glass.

    local root = Instance.new("Folder")
    root.Name = "Filesystem"
    root.Parent = services.getService("ReplicatedStorage")

    local function splitPath(path: string): { string }
        local parts = {}
        for part in string.gmatch(path, "[^/]+") do
            table.insert(parts, part)
        end
        return parts
    end

    local function resolveParent(parts: { string }, createMissing: boolean): Instance?
        local current: Instance = root
        for i = 1, #parts - 1 do
            local child = current:FindFirstChild(parts[i])
            if not child then
                if not createMissing then
                    return nil
                end
                local folder = Instance.new("Folder")
                folder.Name = parts[i]
                folder.Parent = current
                child = folder
            end
            current = child :: Instance
        end
        return current
    end

    local function fileFromInstance(instance: Instance?): StringValue?
        if instance and instance:IsA("StringValue") then
            return instance
        end
        return nil
    end

    function filesystem.writefile(path: string, content: string)
        local parts = splitPath(path)
        assert(#parts > 0, "Invalid path")

        local parent = resolveParent(parts, true)
        assert(parent, "Invalid path")
        local fileName = parts[#parts]

        local existing = parent:FindFirstChild(fileName)
        local existingFile = fileFromInstance(existing)
        if existingFile then
            existingFile.Value = content
        else
            if existing then
                existing:Destroy()
            end
            local file = Instance.new("StringValue")
            file.Name = fileName
            file.Value = content
            file.Parent = parent
        end
    end

    function filesystem.readfile(path: string): string
        local parts = splitPath(path)
        assert(#parts > 0, "Invalid path")

        local parent = resolveParent(parts, false)
        assert(parent, "File not found: " .. path)

        local file = parent:FindFirstChild(parts[#parts])
        local stringFile = fileFromInstance(file)
        assert(stringFile, "File not found: " .. path)

        return stringFile.Value
    end

    function filesystem.appendfile(path: string, content: string)
        local parts = splitPath(path)
        assert(#parts > 0, "Invalid path")

        local parent = resolveParent(parts, false)
        assert(parent, "File not found: " .. path)

        local file = parent:FindFirstChild(parts[#parts])
        local stringFile = fileFromInstance(file)
        assert(stringFile, "File not found: " .. path)

        stringFile.Value = stringFile.Value .. content
    end

    function filesystem.isfile(path: string): boolean
        local parts = splitPath(path)
        if #parts == 0 then
            return false
        end

        local parent = resolveParent(parts, false)
        if not parent then
            return false
        end

        return fileFromInstance(parent:FindFirstChild(parts[#parts])) ~= nil
    end

    function filesystem.listfiles(folder: string): { string }
        local parts = splitPath(folder)
        local current: Instance = root

        for _, part in parts do
            local child = current:FindFirstChild(part)
            if not child or not child:IsA("Folder") then
                error("Folder not found: " .. folder)
            end
            current = child
        end

        local results: { string } = {}
        for _, child in current:GetChildren() do
            table.insert(results, folder .. "/" .. child.Name)
        end
        return results
    end

    function filesystem.delfile(path: string)
        local parts = splitPath(path)
        assert(#parts > 0, "Invalid path")

        local parent = resolveParent(parts, false)
        assert(parent, "File not found: " .. path)

        local file = parent:FindFirstChild(parts[#parts])
        local stringFile = fileFromInstance(file)
        assert(stringFile, "File not found: " .. path)

        stringFile:Destroy()
    end

    function filesystem.makefolder(path: string)
        local parts = splitPath(path)
        if #parts == 0 then
            return
        end

        local current: Instance = root
        for _, part in parts do
            local child = current:FindFirstChild(part)
            if not child then
                local folder = Instance.new("Folder")
                folder.Name = part
                folder.Parent = current
                child = folder
            end
            current = child :: Instance
        end
    end

    function filesystem.isfolder(path: string): boolean
        local parts = splitPath(path)
        if #parts == 0 then
            return false
        end

        local current: Instance = root
        for _, part in parts do
            local child = current:FindFirstChild(part)
            if not child or not child:IsA("Folder") then
                return false
            end
            current = child
        end
        return true
    end

    function filesystem.delfolder(path: string)
        local parts = splitPath(path)
        assert(#parts > 0, "Invalid path")

        local parent = resolveParent(parts, false)
        assert(parent, "Folder not found: " .. path)

        local folder = parent:FindFirstChild(parts[#parts])
        assert(folder and folder:IsA("Folder"), "Folder not found: " .. path)

        folder:Destroy()
    end
end

function filesystem.ensureFolder(path: string)
    if not filesystem.isfolder(path) then
        filesystem.makefolder(path)
    end
end

function filesystem.ensureDir(dir: string)
    local built = ""
    for part in string.gmatch(dir, "[^/]+") do
        built = if built == "" then part else built .. "/" .. part
        if not filesystem.isfolder(built) then
            filesystem.makefolder(built)
        end
    end
end

return filesystem
