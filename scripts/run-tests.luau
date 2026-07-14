local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local root = process.cwd:gsub("\\", "/"):gsub("/$", "")
local testsRoot = root .. "/tests/specs"
local utilityRoot = root .. "/src/utility"
local defaultCoverageDirectory = "src/utility"
local coverageRoot = root .. "/coverage"
local instrumentedRoot = root .. "/build/coverage/instrumented"

local function normalizePath(path)
    path = path:gsub("\\", "/"):gsub("/+", "/")

    local prefix = ""
    if path:match("^%a:/") then
        prefix = path:sub(1, 2)
        path = path:sub(3)
    elseif path:sub(1, 1) == "/" then
        prefix = "/"
        path = path:sub(2)
    end

    local parts = {}
    for part in path:gmatch("[^/]+") do
        if part == ".." then
            if #parts > 0 and parts[#parts] ~= ".." then
                table.remove(parts)
            elseif prefix == "" then
                table.insert(parts, part)
            end
        elseif part ~= "." and part ~= "" then
            table.insert(parts, part)
        end
    end

    local normalized = table.concat(parts, "/")
    if prefix == "/" then
        return "/" .. normalized
    elseif prefix ~= "" then
        return if normalized == "" then prefix .. "/" else prefix .. "/" .. normalized
    end

    return normalized
end

local function isAbsolutePath(path)
    return path:match("^%a:/") ~= nil or path:sub(1, 1) == "/"
end

local function isInsideRoot(path)
    local lowerRoot = root:lower()
    local lowerPath = path:lower()
    return lowerPath == lowerRoot or lowerPath:sub(1, #lowerRoot + 1) == lowerRoot .. "/"
end

local function parseNumberArg(name, default)
    local longName = "--" .. name
    local argPrefix = longName .. "="
    for index, arg in process.args do
        if arg == longName then
            return tonumber(process.args[index + 1]) or default
        end

        if arg:sub(1, #argPrefix) == argPrefix then
            return tonumber(arg:sub(#argPrefix + 1)) or default
        end
    end

    return default
end

local function parseDirectoryArg(default)
    local positional = nil
    local skipNext = false

    for _, arg in process.args do
        if skipNext then
            skipNext = false
        elseif arg == "--coverage-threshold" then
            skipNext = true
        elseif arg:sub(1, 2) == "--" then
            -- Other options are ignored so future flags do not become paths.
        elseif positional == nil then
            positional = arg
        else
            warn("Only one coverage directory can be provided.")
            process.exit(1)
        end
    end

    return positional or default
end

local function resolveCoverageDirectory(path)
    local normalized = normalizePath(path)
    local absolutePath = if isAbsolutePath(normalized) then normalized else normalizePath(root .. "/" .. normalized)

    if not isInsideRoot(absolutePath) then
        warn("Coverage directory must be inside the repository: " .. path)
        process.exit(1)
    end

    if not fs.isDir(absolutePath) then
        warn("Coverage directory does not exist: " .. path)
        process.exit(1)
    end

    local relativePath = if absolutePath == root then "." else absolutePath:sub(#root + 2)
    return absolutePath, relativePath
end

local coverageThreshold = parseNumberArg("coverage-threshold", tonumber(process.env.RAYFIELD_COVERAGE_THRESHOLD) or 70)
local coverageDirectory, coverageScope = resolveCoverageDirectory(parseDirectoryArg(defaultCoverageDirectory))

local coverage = {
    files = {},
}

function coverage.hit(relativePath, lineNumber)
    local file = coverage.files[relativePath]
    if file then
        file.hits[lineNumber] = true
    end
end

_G.__RAYFIELD_COVERAGE = coverage

local function splitLines(source)
    local lines = {}
    for line in (source .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

local function removeStringsAndComments(line)
    local result = {}
    local index = 1
    local quote = nil

    while index <= #line do
        local char = line:sub(index, index)
        local nextChar = line:sub(index + 1, index + 1)

        if quote then
            if char == "\\" then
                index += 2
            elseif char == quote then
                quote = nil
                index += 1
            else
                index += 1
            end
        elseif char == "-" and nextChar == "-" then
            break
        elseif char == '"' or char == "'" or char == "`" then
            quote = char
            index += 1
        else
            table.insert(result, char)
            index += 1
        end
    end

    return table.concat(result)
end

local function delimiterDelta(line)
    local code = removeStringsAndComments(line)
    local delta = 0
    for index = 1, #code do
        local char = code:sub(index, index)
        if char == "{" or char == "(" or char == "[" then
            delta += 1
        elseif char == "}" or char == ")" or char == "]" then
            delta -= 1
        end
    end
    return delta
end

local function startsContinuation(text)
    return text:match("^or%s") or text:match("^and%s") or text:match("^%.%.") or text:match("^[,:%+%*/%%]")
end

local function endsContinuation(text)
    return text:match("=%s*$") or text:match("%.%.%s*$") or text:match("[,%+%-%*/%%]%s*$") or text:match("^return%s*$")
end

local function isCoverableLine(line, depth, inBlockComment, previousContinuation)
    if depth ~= 0 or inBlockComment or previousContinuation then
        return false
    end

    local text = line:match("^%s*(.-)%s*$")
    if text == "" then
        return false
    end
    if text:sub(1, 2) == "--" or text:sub(1, 2) == "::" then
        return false
    end
    if text:match("^type%s") or text:match("^export%s+type%s") then
        return false
    end
    if text:match("^end[%s,%)%}]") or text == "end" then
        return false
    end
    if startsContinuation(text) then
        return false
    end
    if text:match("^then%s") or text:match("^else") or text:match("^elseif") or text:match("^until") then
        return false
    end
    if text:match("^[%}%]%)]") then
        return false
    end

    return true
end

local function parentDir(path)
    return path:match("^(.*)/[^/]+$") or "."
end

local function isTestFile(path)
    return path:match("%.spec%.lua$") ~= nil
        or path:match("%.spec%.luau$") ~= nil
        or path:match("%.test%.lua$") ~= nil
        or path:match("%.test%.luau$") ~= nil
end

local function instrumentSource(relativePath, source)
    local fileCoverage = {
        coverable = {},
        hits = {},
    }
    coverage.files[relativePath] = fileCoverage

    local depth = 0
    local inBlockComment = false
    local previousContinuation = false
    local output = {}

    for lineNumber, line in splitLines(source) do
        local startsBlockComment = line:find("%-%-%[%[", 1) ~= nil
        local endsBlockComment = line:find("%]%]", 1) ~= nil
        local text = line:match("^%s*(.-)%s*$")
        local coverable = isCoverableLine(line, depth, inBlockComment, previousContinuation)

        if coverable then
            fileCoverage.coverable[lineNumber] = true
            table.insert(output, string.format("_G.__RAYFIELD_COVERAGE.hit(%q, %d)", relativePath, lineNumber))
        end

        table.insert(output, line)

        if startsBlockComment and not endsBlockComment then
            inBlockComment = true
        elseif inBlockComment and endsBlockComment then
            inBlockComment = false
        end

        if not inBlockComment then
            depth += delimiterDelta(line)
            if depth < 0 then
                depth = 0
            end
        end

        previousContinuation = not inBlockComment and depth == 0 and endsContinuation(text)
    end

    return table.concat(output, "\n")
end

local function collectSourceModules(directory, modules)
    for _, entry in fs.readDir(directory) do
        local path = directory .. "/" .. entry
        if fs.isDir(path) then
            collectSourceModules(path, modules)
        elseif entry:match("%.luau$") and not isTestFile(entry) then
            local relativePath = path:sub(#root + 2)
            table.insert(modules, {
                path = path,
                relativePath = relativePath,
            })
        end
    end
end

local function addSourceModules(sourceModulesByPath, modules)
    for _, moduleInfo in modules do
        sourceModulesByPath[moduleInfo.relativePath] = moduleInfo
    end
end

pcall(fs.removeDir, instrumentedRoot)
fs.writeDir(instrumentedRoot)

local coverageModules = {}
collectSourceModules(coverageDirectory, coverageModules)
table.sort(coverageModules, function(a, b)
    return a.relativePath < b.relativePath
end)

local trackedCoverageFiles = {}
for _, moduleInfo in coverageModules do
    table.insert(trackedCoverageFiles, moduleInfo.relativePath)
end

local utilitySourceModules = {}
collectSourceModules(utilityRoot, utilitySourceModules)

local sourceModulesByPath = {}
addSourceModules(sourceModulesByPath, coverageModules)
addSourceModules(sourceModulesByPath, utilitySourceModules)

local sourceModules = {}
for _, moduleInfo in sourceModulesByPath do
    table.insert(sourceModules, moduleInfo)
end

table.sort(sourceModules, function(a, b)
    return a.relativePath < b.relativePath
end)

local utilityModules = {}
for _, moduleInfo in sourceModules do
    local source = fs.readFile(moduleInfo.path)
    local instrumented = instrumentSource(moduleInfo.relativePath, source)
    local outputPath = instrumentedRoot .. "/" .. moduleInfo.relativePath
    fs.writeDir(parentDir(outputPath))
    fs.writeFile(outputPath, instrumented)

    local name = moduleInfo.relativePath:match("^src/utility/(.-)%.luau$")
    if name then
        utilityModules[name] = outputPath
    end
end

Color3 = roblox.Color3
ColorSequence = roblox.ColorSequence
ColorSequenceKeypoint = roblox.ColorSequenceKeypoint
Enum = roblox.Enum
Instance = table.clone(roblox.Instance)

local robloxInstanceNew = roblox.Instance.new
Instance.new = function(className, ...)
    if className == "GetTextBoundsParams" then
        return {}
    end

    if className == "HapticEffect" then
        local effect = {
            ClassName = className,
            Parent = nil,
            Type = nil,
            Played = false,
        }
        function effect:Destroy()
            self.Parent = nil
        end
        function effect:Play()
            self.Played = true
        end
        function effect:IsA(name)
            return name == className
        end
        return effect
    end

    return robloxInstanceNew(className, ...)
end

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

_G.__RAYFIELD_TEST_HELPERS = {
    requireUtility = _G.__RAYFIELD_TEST_REQUIRE_UTILITY,
}

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
                assertCondition(
                    actual ~= nil and actual ~= false,
                    string.format("expected %s to be ok", tostring(actual)),
                    negate
                )
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

local function jsonEscape(value)
    return tostring(value):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
end

local function fileCoverageSummary(relativePath)
    local file = coverage.files[relativePath]
    local coverableLines = 0
    local coveredLines = 0
    local uncovered = {}

    if file then
        for lineNumber in file.coverable do
            coverableLines += 1
            if file.hits[lineNumber] then
                coveredLines += 1
            else
                table.insert(uncovered, lineNumber)
            end
        end
    end

    table.sort(uncovered)
    local percent = if coverableLines == 0 then 100 else (coveredLines / coverableLines) * 100
    return {
        path = relativePath,
        coveredLines = coveredLines,
        coverableLines = coverableLines,
        lineCoverage = percent,
        uncoveredLines = uncovered,
    }
end

local function writeCoverageReports()
    local rows = {}
    local totalCovered = 0
    local totalCoverable = 0

    for _, relativePath in trackedCoverageFiles do
        local row = fileCoverageSummary(relativePath)
        table.insert(rows, row)
        totalCovered += row.coveredLines
        totalCoverable += row.coverableLines
    end

    local totalPercent = if totalCoverable == 0 then 100 else (totalCovered / totalCoverable) * 100
    fs.writeDir(coverageRoot)

    local textLines = {
        string.format(
            "Line coverage: %.2f%% (%d/%d), threshold %.2f%%",
            totalPercent,
            totalCovered,
            totalCoverable,
            coverageThreshold
        ),
        "Scope: " .. coverageScope,
        "",
        "Files:",
    }

    local jsonLines = {
        "{",
        string.format('  "scope": "%s",', jsonEscape(coverageScope)),
        string.format('  "threshold": %.2f,', coverageThreshold),
        string.format('  "lineCoverage": %.2f,', totalPercent),
        string.format('  "coveredLines": %d,', totalCovered),
        string.format('  "coverableLines": %d,', totalCoverable),
        '  "files": [',
    }

    for index, row in rows do
        table.insert(
            textLines,
            string.format("  %s: %.2f%% (%d/%d)", row.path, row.lineCoverage, row.coveredLines, row.coverableLines)
        )
        if #row.uncoveredLines > 0 then
            table.insert(textLines, "    uncovered: " .. table.concat(row.uncoveredLines, ", "))
        end

        local uncoveredText = {}
        for _, lineNumber in row.uncoveredLines do
            table.insert(uncoveredText, tostring(lineNumber))
        end

        table.insert(jsonLines, "    {")
        table.insert(jsonLines, string.format('      "path": "%s",', jsonEscape(row.path)))
        table.insert(jsonLines, string.format('      "lineCoverage": %.2f,', row.lineCoverage))
        table.insert(jsonLines, string.format('      "coveredLines": %d,', row.coveredLines))
        table.insert(jsonLines, string.format('      "coverableLines": %d,', row.coverableLines))
        table.insert(jsonLines, string.format('      "uncoveredLines": [%s]', table.concat(uncoveredText, ", ")))
        table.insert(jsonLines, "    }" .. if index == #rows then "" else ",")
    end

    table.insert(jsonLines, "  ]")
    table.insert(jsonLines, "}")

    fs.writeFile(coverageRoot .. "/coverage.txt", table.concat(textLines, "\n") .. "\n")
    fs.writeFile(coverageRoot .. "/coverage-summary.json", table.concat(jsonLines, "\n") .. "\n")

    print(
        string.format(
            "coverage: %.2f%% lines (%d/%d), threshold %.2f%%",
            totalPercent,
            totalCovered,
            totalCoverable,
            coverageThreshold
        )
    )
    print("coverage reports: coverage/coverage.txt, coverage/coverage-summary.json")

    return totalPercent
end

print(string.format("%d/%d tests passed", results.successCount, results.testsRan))

local coveragePercent = writeCoverageReports()

if results.failureCount > 0 then
    for _, failure in results.errors do
        warn(string.format("%s\n%s", failure.test, failure.message))
    end
    process.exit(1)
end

if coveragePercent + 0.0001 < coverageThreshold then
    warn(string.format("Coverage %.2f%% is below the required %.2f%% threshold.", coveragePercent, coverageThreshold))
    process.exit(1)
end

process.exit(0)
