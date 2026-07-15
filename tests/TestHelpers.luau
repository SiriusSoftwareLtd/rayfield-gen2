--!strict

local existingHelpers = (_G :: any).__RAYFIELD_TEST_HELPERS

if existingHelpers then
    return existingHelpers
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rayfield = ReplicatedStorage:WaitForChild("Rayfield")
local utility = Rayfield:WaitForChild("utility")
local components = Rayfield:WaitForChild("components")
local themes = Rayfield:WaitForChild("themes")

local function requireChild(parent: Instance, name: string): any
    return require(parent:WaitForChild(name) :: any)
end

local helpers = {
    requireUtility = function(name: string): any
        return requireChild(utility, name)
    end,
    requireComponent = function(name: string): any
        return requireChild(components, name)
    end,
    requireTheme = function(name: string): any
        return requireChild(themes, name)
    end,
    requireRayfield = function(): any
        return require(Rayfield :: any)
    end,
}

(_G :: any).__RAYFIELD_TEST_HELPERS = helpers

return helpers
