local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local root = process.cwd:gsub("\\", "/"):gsub("/$", "")
local testsRoot = root .. "/tests/specs"
local utilityRoot = root .. "/src/utility"

Color3 = roblox.Color3
ColorSequence = roblox.ColorSequence
ColorSequenceKeypoint = roblox.ColorSequenceKeypoint
Enum = roblox.Enum
Instance = roblox.Instance

Font = {
    fromEnum = function(font)
        return {
            Family = tostring(font),
            Weight = Enum.FontWeight.Regular,
            Style = Enum.FontStyle.Normal,
        }
    end,
    new = function(family, weight, style)
        return {
            Family = family,
            Weight = weight,
            Style = style,
        }
    end,
}

TweenInfo = {
    new = function(...)
        return { ... }
    end,
}

task = task
    or {
        wait = function() end,
        spawn = function(callback)
            local thread = coroutine.create(callback)
            local ok, err = coroutine.resume(thread)
            if not ok then
                error(err, 0)
            end
            return thread
        end,
    }

local function makeFolder(name)
    local folder = Instance.new("Folder")
    folder.Name = name
    return folder
end

local services = {
    CoreGui = makeFolder("CoreGui"),
    Workspace = makeFolder("Workspace"),
    UserInputService = {},
    GuiService = {},
    TweenService = {},
    TextService = {},
    LocalizationService = {},
    ReplicatedStorage = makeFolder("ReplicatedStorage"),
    RunService = {
        IsStudio = function()
            return true
        end,
    },
    Players = {
        LocalPlayer = {
            PlayerGui = makeFolder("PlayerGui"),
        },
    },
    HttpService = {
        JSONDecode = function()
            error("HttpService:JSONDecode is not available in the unit test shim")
        end,
        JSONEncode = function()
            error("HttpService:JSONEncode is not available in the unit test shim")
        end,
    },
}

game = {
    GetService = function(_, name)
        if not services[name] then
            services[name] = makeFolder(name)
        end
        return services[name]
    end,
}
workspace = services.Workspace

local utilityModules = {}
for _, entry in fs.readDir(utilityRoot) do
    local name = entry:match("^(.-)%.luau$")
    if name then
        utilityModules[name] = utilityRoot .. "/" .. name
    end
end

_G.__RAYFIELD_TEST_REQUIRE_UTILITY = function(name)
    local modulePath = utilityModules[name]
    assert(modulePath, string.format("Unknown utility module: %s", tostring(name)))

    local previousScript = script
    script = {
        Parent = utilityModules,
    }

    local ok, result = pcall(require, modulePath)
    script = previousScript

    if not ok then
        error(result, 2)
    end

    return result
end

local results = {
    testsRan = 0,
    successCount = 0,
    failureCount = 0,
    errors = {},
}

local suiteNames = {}
local contexts = {
    {
        beforeEach = {},
        afterEach = {},
        afterAll = {},
    },
}

local function fullName(testName)
    local parts = table.clone(suiteNames)
    table.insert(parts, testName)
    return table.concat(parts, " > ")
end

local function recordFailure(testName, message)
    results.failureCount += 1
    table.insert(results.errors, {
        test = testName,
        message = tostring(message),
    })
end

local function runBeforeEach()
    for _, context in contexts do
        for _, hook in context.beforeEach do
            hook()
        end
    end
end

local function runAfterEach()
    for i = #contexts, 1, -1 do
        local hooks = contexts[i].afterEach
        for j = #hooks, 1, -1 do
            hooks[j]()
        end
    end
end

local function fail(message, level)
    error(message, (level or 1) + 1)
end

local function assertCondition(pass, message, negate)
    if negate then
        pass = not pass
    end

    if not pass then
        fail(message, 3)
    end
end

local function makeTo(actual, negate)
    return {
        equal = function(expected)
            assertCondition(
                actual == expected,
                string.format("expected %s to equal %s", tostring(actual), tostring(expected)),
                negate
            )
        end,
        be = {
            ok = function()
                assertCondition(actual ~= nil, string.format("expected %s to be ok", tostring(actual)), negate)
            end,
            a = function(expectedType)
                local actualType = typeof(actual)
                assertCondition(
                    actualType == expectedType or type(actual) == expectedType,
                    string.format("expected %s to be a %s, got %s", tostring(actual), expectedType, actualType),
                    negate
                )
            end,
        },
    }
end

function expect(actual)
    return {
        to = makeTo(actual, false),
        never = {
            to = makeTo(actual, true),
        },
    }
end

function beforeEach(callback)
    table.insert(contexts[#contexts].beforeEach, callback)
end

function afterEach(callback)
    table.insert(contexts[#contexts].afterEach, callback)
end

function beforeAll(callback)
    callback()
end

function afterAll(callback)
    table.insert(contexts[#contexts].afterAll, callback)
end

function describe(name, callback)
    table.insert(suiteNames, name)
    table.insert(contexts, {
        beforeEach = {},
        afterEach = {},
        afterAll = {},
    })

    local ok, err = xpcall(callback, debug.traceback)
    local context = table.remove(contexts)

    for _, hook in context.afterAll do
        local hookOk, hookErr = xpcall(hook, debug.traceback)
        if not hookOk then
            ok = false
            err = hookErr
        end
    end

    if not ok then
        recordFailure(table.concat(suiteNames, " > "), err)
    end

    table.remove(suiteNames)
end

function it(name, callback)
    local nameWithSuites = fullName(name)
    results.testsRan += 1

    local ok, err = xpcall(function()
        runBeforeEach()
        callback()
    end, debug.traceback)

    local afterOk, afterErr = xpcall(runAfterEach, debug.traceback)
    if not afterOk then
        ok = false
        err = afterErr
    end

    if ok then
        results.successCount += 1
        print("[PASS] " .. nameWithSuites)
    else
        recordFailure(nameWithSuites, err)
        warn("[FAIL] " .. nameWithSuites)
        warn(err)
    end
end

local function collectSpecs(directory, specs)
    for _, entry in fs.readDir(directory) do
        local path = directory .. "/" .. entry
        if fs.isDir(path) then
            collectSpecs(path, specs)
        elseif entry:match("%.spec%.lua$") or entry:match("%.spec%.luau$") then
            table.insert(specs, path)
        end
    end
end

local specs = {}
collectSpecs(testsRoot, specs)
table.sort(specs)

if #specs == 0 then
    warn("No TestEZ spec files found in " .. testsRoot)
    process.exit(1)
end

for _, specPath in specs do
    local spec = require(specPath)
    assert(type(spec) == "function", specPath .. " must return a function")
    spec()
end

print(string.format("%d/%d tests passed", results.successCount, results.testsRan))

if results.failureCount > 0 then
    for _, failure in results.errors do
        warn(string.format("%s\n%s", failure.test, failure.message))
    end
    process.exit(1)
end

process.exit(0)
