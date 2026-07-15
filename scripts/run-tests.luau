local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local root = process.cwd:gsub("\\", "/"):gsub("/$", "")
local testsRoot = root .. "/tests"
local sourceRoot = root .. "/src"
local utilityRoot = root .. "/src/utility"
local defaultCoverageDirectory = "src"
local coverageRoot = root .. "/coverage"
local instrumentedRoot = root .. "/build/coverage/instrumented"
local coverageBaselinePath = root .. "/coverage-baseline.json"
local coverageEpsilon = 0.005

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

local function parseFlagArg(name)
    local longName = "--" .. name
    for _, arg in process.args do
        if arg == longName then
            return true
        end
    end

    return false
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

local function readJsonStringField(contents, name)
    return contents:match('"' .. name .. '"%s*:%s*"(.-)"')
end

local function readJsonNumberField(contents, name)
    local value = contents:match('"' .. name .. '"%s*:%s*([%-%d%.]+)')
    return if value then tonumber(value) else nil
end

local function readCoverageBaseline()
    if not fs.isFile(coverageBaselinePath) then
        warn("Coverage baseline is missing: coverage-baseline.json")
        process.exit(1)
    end

    local contents = fs.readFile(coverageBaselinePath)
    local baselineScope = readJsonStringField(contents, "scope")
    local lineCoverage = readJsonNumberField(contents, "lineCoverage")

    if not baselineScope or not lineCoverage then
        warn("Coverage baseline is missing required fields: scope and lineCoverage")
        process.exit(1)
    end

    return {
        scope = baselineScope,
        lineCoverage = lineCoverage,
    }
end

local coverageThreshold = parseNumberArg("coverage-threshold", tonumber(process.env.RAYFIELD_COVERAGE_THRESHOLD) or 70)
local updateCoverageBaseline = parseFlagArg("update-coverage-baseline")
local verboseTestLogsEnv = string.lower(process.env.RAYFIELD_TEST_VERBOSE_LOGS or "")
local verboseTestLogs = parseFlagArg("verbose-logs") or verboseTestLogsEnv == "true" or verboseTestLogsEnv == "1"
local coverageDirectory, coverageScope = resolveCoverageDirectory(parseDirectoryArg(defaultCoverageDirectory))
local coverageBaseline = nil

if not updateCoverageBaseline then
    coverageBaseline = readCoverageBaseline()

    if coverageBaseline.scope ~= coverageScope then
        warn(
            string.format(
                "Coverage baseline scope mismatch: baseline is %q, current scope is %q. Run `make coverage-baseline` after intentionally changing the coverage scope.",
                coverageBaseline.scope,
                coverageScope
            )
        )
        process.exit(1)
    end
end

local effectiveCoverageThreshold = coverageThreshold
if coverageBaseline and coverageBaseline.lineCoverage > effectiveCoverageThreshold then
    effectiveCoverageThreshold = coverageBaseline.lineCoverage
end

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

local function readLongBracketStart(line, index)
    if line:sub(index, index) ~= "[" then
        return nil
    end

    local cursor = index + 1
    local equals = 0
    while line:sub(cursor, cursor) == "=" do
        equals += 1
        cursor += 1
    end

    if line:sub(cursor, cursor) == "[" then
        return equals, cursor + 1
    end

    return nil
end

local function readLongBracketEnd(line, index, equals)
    if line:sub(index, index) ~= "]" then
        return nil
    end

    local cursor = index + 1
    for _ = 1, equals do
        if line:sub(cursor, cursor) ~= "=" then
            return nil
        end
        cursor += 1
    end

    if line:sub(cursor, cursor) == "]" then
        return cursor + 1
    end

    return nil
end

local function delimiterDeltaFromCode(code)
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

local function delimiterDelta(line, lexerState)
    local code = {}
    local index = 1
    local quote = nil

    while index <= #line do
        local char = line:sub(index, index)
        local nextChar = line:sub(index + 1, index + 1)

        if lexerState.longBracket then
            local afterEnd = readLongBracketEnd(line, index, lexerState.longBracket.equals)
            if afterEnd then
                lexerState.longBracket = nil
                index = afterEnd
            else
                index += 1
            end
        elseif quote then
            if char == "\\" then
                index += 2
            elseif char == quote then
                quote = nil
                index += 1
            else
                index += 1
            end
        elseif char == "-" and nextChar == "-" then
            local equals, afterStart = readLongBracketStart(line, index + 2)
            if equals ~= nil then
                lexerState.longBracket = {
                    kind = "comment",
                    equals = equals,
                }
                index = afterStart
            else
                break
            end
        elseif char == '"' or char == "'" or char == "`" then
            quote = char
            index += 1
        elseif char == "[" then
            local equals, afterStart = readLongBracketStart(line, index)
            if equals ~= nil then
                lexerState.longBracket = {
                    kind = "string",
                    equals = equals,
                }
                index = afterStart
            else
                table.insert(code, char)
                index += 1
            end
        else
            table.insert(code, char)
            index += 1
        end
    end

    return delimiterDeltaFromCode(table.concat(code))
end

local function startsContinuation(text)
    return text:match("^or%s") or text:match("^and%s") or text:match("^%.%.") or text:match("^[,:%+%*/%%]")
end

local function endsContinuation(text)
    return text:match("=%s*$")
        or text:match("%.%.%s*$")
        or text:match("[,%+%-%*/%%]%s*$")
        or text:match("[<>=~]=%s*$")
        or text:match("^return%s*$")
        or text == "elseif"
        or text:match("=%s*if%s")
end

local function isContinuationOnly(text)
    return text == "and"
        or text == "or"
        or text == ".."
        or text == "."
        or text == ","
        or text == ":"
        or text == "+"
        or text == "-"
        or text == "*"
        or text == "/"
        or text == "%"
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
    if isContinuationOnly(text) or startsContinuation(text) then
        return false
    end
    if
        text == "then"
        or text:match("^then%s")
        or text:match("^else")
        or text:match("^elseif")
        or text:match("^until")
    then
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
        or path:match("%.lune%.lua$") ~= nil
        or path:match("%.lune%.luau$") ~= nil
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
    local lexerState = {}
    local previousContinuation = false
    local output = { "local script = _G.__RAYFIELD_CURRENT_SCRIPT" }

    for lineNumber, line in splitLines(source) do
        local startsInLongBracket = lexerState.longBracket ~= nil
        local text = line:match("^%s*(.-)%s*$")
        local coverable = isCoverableLine(line, depth, startsInLongBracket, previousContinuation)

        if coverable then
            fileCoverage.coverable[lineNumber] = true
            table.insert(output, string.format("_G.__RAYFIELD_COVERAGE.hit(%q, %d)", relativePath, lineNumber))
        end

        table.insert(output, line)

        depth += delimiterDelta(line, lexerState)
        if depth < 0 then
            depth = 0
        end

        previousContinuation = not lexerState.longBracket and depth == 0 and endsContinuation(text)
    end

    if lexerState.longBracket then
        error(
            string.format(
                "Coverage instrumentation failed for %s: unsupported unterminated long %s with %d equal sign(s)",
                relativePath,
                lexerState.longBracket.kind,
                lexerState.longBracket.equals
            ),
            0
        )
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

local sourceModulePaths = {}
for _, moduleInfo in sourceModules do
    local source = fs.readFile(moduleInfo.path)
    local instrumented = instrumentSource(moduleInfo.relativePath, source)
    local outputPath = instrumentedRoot .. "/" .. moduleInfo.relativePath
    fs.writeDir(parentDir(outputPath))
    fs.writeFile(outputPath, instrumented)
    sourceModulePaths[moduleInfo.relativePath] = outputPath
end

local function makeSourceNode(name, parent, path)
    local node = {
        Name = name,
        Parent = parent,
        __path = path,
        __children = {},
    }

    function node:FindFirstChild(childName)
        return self[childName]
    end

    function node:WaitForChild(childName)
        return self[childName]
    end

    function node:GetChildren()
        return table.clone(self.__children)
    end

    function node:IsA(className)
        return (self.__path and className == "ModuleScript") or (not self.__path and className == "Folder")
    end

    return node
end

local sourceRootNode = makeSourceNode("Rayfield", nil, sourceModulePaths["src/init.luau"])
local sourceNodesByPath = {}
sourceNodesByPath[sourceRootNode.__path] = sourceRootNode

local function splitPathParts(path)
    local parts = {}
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    return parts
end

local function addChild(parent, child)
    parent[child.Name] = child
    table.insert(parent.__children, child)
end

local function ensureSourceFolder(parent, name)
    local child = parent[name]
    if child then
        return child
    end

    child = makeSourceNode(name, parent, nil)
    addChild(parent, child)
    return child
end

for _, moduleInfo in sourceModules do
    if moduleInfo.relativePath ~= "src/init.luau" then
        local withoutRoot = moduleInfo.relativePath:gsub("^src/", ""):gsub("%.luau$", "")
        local parts = splitPathParts(withoutRoot)
        local parent = sourceRootNode

        for index = 1, #parts - 1 do
            parent = ensureSourceFolder(parent, parts[index])
        end

        local node = makeSourceNode(parts[#parts], parent, sourceModulePaths[moduleInfo.relativePath])
        addChild(parent, node)
        sourceNodesByPath[node.__path] = node
    end
end

local nativeRequire = require
local sourceRequireCache = {}

function require(module)
    local path = nil
    local moduleScript = nil

    if type(module) == "table" and module.__path then
        path = module.__path
        moduleScript = module
    elseif type(module) == "string" then
        path = module
        moduleScript = sourceNodesByPath[path]
    end

    if not moduleScript then
        return nativeRequire(module)
    end

    if sourceRequireCache[path] ~= nil then
        return sourceRequireCache[path]
    end

    local previousScript = script
    local previousCurrentScript = _G.__RAYFIELD_CURRENT_SCRIPT
    script = moduleScript
    _G.__RAYFIELD_CURRENT_SCRIPT = moduleScript
    local ok, result = xpcall(function()
        return nativeRequire(path)
    end, function(err)
        return tostring(err) .. "\n" .. debug.traceback(nil, 2)
    end)
    script = previousScript
    _G.__RAYFIELD_CURRENT_SCRIPT = previousCurrentScript

    if not ok then
        error(result, 2)
    end

    sourceRequireCache[path] = result
    return result
end

Color3 = roblox.Color3
ColorSequence = roblox.ColorSequence
ColorSequenceKeypoint = roblox.ColorSequenceKeypoint
Enum = roblox.Enum
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
NumberSequence = roblox.NumberSequence
NumberSequenceKeypoint = roblox.NumberSequenceKeypoint
UDim = roblox.UDim
UDim2 = roblox.UDim2
Vector2 = roblox.Vector2
Vector3 = roblox.Vector3

TweenInfo = {
    new = function(...)
        return { ... }
    end,
}

local function makeSignal()
    local signal = {
        _connections = {},
        _lastArgs = nil,
    }

    function signal:Connect(callback)
        local connection = {
            Connected = true,
            _callback = callback,
        }

        function connection:Disconnect()
            self.Connected = false
        end

        table.insert(self._connections, connection)
        return connection
    end

    function signal:Fire(...)
        self._lastArgs = table.pack(...)
        local connections = table.clone(self._connections)
        for _, connection in connections do
            if connection.Connected then
                connection._callback(...)
            end
        end
    end

    function signal:Wait()
        if self._lastArgs then
            return table.unpack(self._lastArgs, 1, self._lastArgs.n)
        end
        return nil
    end

    return signal
end

task = {
    wait = function()
        return 1
    end,
    delay = function(_, callback, ...)
        local args = table.pack(...)
        local thread = coroutine.create(function()
            callback(table.unpack(args, 1, args.n))
        end)
        local ok, err = coroutine.resume(thread)
        if not ok then
            error(err, 0)
        end
        return thread
    end,
    spawn = function(callback, ...)
        local args = table.pack(...)
        local thread = coroutine.create(function()
            callback(table.unpack(args, 1, args.n))
        end)
        local ok, err = coroutine.resume(thread)
        if not ok then
            error(err, 0)
        end
        return thread
    end,
}
task.defer = task.spawn

local instanceMethods = {}
local removeFromParent

function instanceMethods:GetChildren()
    return table.clone(self._children)
end

function instanceMethods:GetDescendants()
    local descendants = {}

    local function visit(parent)
        for _, child in parent._children do
            table.insert(descendants, child)
            visit(child)
        end
    end

    visit(self)
    return descendants
end

function instanceMethods:FindFirstChild(name)
    for _, child in self._children do
        if child.Name == name then
            return child
        end
    end
    return nil
end

function instanceMethods:WaitForChild(name)
    return self:FindFirstChild(name)
end

function instanceMethods:IsA(className)
    return self.ClassName == className
end

function instanceMethods:GetPropertyChangedSignal(property)
    local signal = self._propertySignals[property]
    if not signal then
        signal = makeSignal()
        self._propertySignals[property] = signal
    end
    return signal
end

function instanceMethods:Destroy()
    local children = table.clone(self._children)
    for _, child in children do
        child:Destroy()
    end
    self.Destroying:Fire()
    removeFromParent(self, self.Parent)
    rawset(self, "Parent", nil)
    self._destroyed = true
end

function instanceMethods:CaptureFocus()
    self._focused = true
    self.Focused:Fire()
end

function instanceMethods:ReleaseFocus()
    local wasFocused = self._focused
    self._focused = false
    if wasFocused then
        self.FocusLost:Fire(false)
    end
end

function instanceMethods:IsFocused()
    return self._focused == true
end

function instanceMethods:JumpTo(page)
    self.CurrentPage = page
end

local signalProperties = {
    Changed = true,
    Destroying = true,
    Focused = true,
    FocusLost = true,
    InputBegan = true,
    InputChanged = true,
    InputEnded = true,
    MouseButton1Click = true,
    MouseButton2Click = true,
    MouseEnter = true,
    MouseLeave = true,
}

local instanceMetatable = {}

function instanceMetatable.__index(self, key)
    local method = instanceMethods[key]
    if method then
        return method
    end

    for _, child in rawget(self, "_children") do
        if child.Name == key then
            return child
        end
    end

    if signalProperties[key] then
        local signal = makeSignal()
        rawset(self, key, signal)
        return signal
    end

    return nil
end

function removeFromParent(instance, parent)
    if not parent or not parent._children then
        return
    end

    local index = table.find(parent._children, instance)
    if index then
        table.remove(parent._children, index)
    end
end

function instanceMetatable.__newindex(self, key, value)
    if key == "Parent" then
        local oldParent = rawget(self, "Parent")
        if oldParent == value then
            rawset(self, key, value)
            return
        end

        removeFromParent(self, oldParent)
        rawset(self, key, value)

        if value and value._children and not table.find(value._children, self) then
            table.insert(value._children, self)
        end
    else
        rawset(self, key, value)
    end

    local propertySignals = rawget(self, "_propertySignals")
    local signal = propertySignals and propertySignals[key]
    if signal then
        signal:Fire()
    end

    local changed = rawget(self, "Changed")
    if changed then
        changed:Fire(key)
    end
end

local function makeInstance(className)
    if className == "GetTextBoundsParams" then
        return {}
    end

    local instance = {
        ClassName = className,
        Name = className,
        Parent = nil,
        _children = {},
        _propertySignals = {},
        _focused = false,
        AbsolutePosition = Vector2.new(0, 0),
        AbsoluteSize = Vector2.new(420, 120),
        AbsoluteWindowSize = Vector2.new(420, 120),
        AnchorPoint = Vector2.new(0, 0),
        Position = UDim2.new(),
        Size = UDim2.new(),
        Visible = true,
        ZIndex = 1,
        Destroying = makeSignal(),
    }

    if className == "ScreenGui" then
        instance.AbsoluteSize = Vector2.new(1024, 768)
    elseif className == "TextBox" or className == "TextButton" or className == "ImageButton" then
        instance.Active = true
    elseif className == "HapticEffect" then
        instance.Played = false

        function instance:Play()
            self.Played = true
        end
    end

    return setmetatable(instance, instanceMetatable)
end

Instance = {
    new = makeInstance,
}

local function makeTween(instance, targetProperties)
    local tween = {
        Completed = makeSignal(),
        _instance = instance,
        _targetProperties = targetProperties,
        _cancelled = false,
    }

    function tween:Play()
        for property, value in self._targetProperties do
            self._instance[property] = value
        end
        self.Completed:Fire(Enum.PlaybackState.Completed)
    end

    function tween:Cancel()
        self._cancelled = true
        self.Completed:Fire(Enum.PlaybackState.Cancelled)
    end

    return tween
end

local function makeFolder(name)
    local folder = Instance.new("Folder")
    folder.Name = name
    return folder
end

local function propertySignalForService(service, property)
    service._propertySignals = service._propertySignals or {}
    local signal = service._propertySignals[property]
    if not signal then
        signal = makeSignal()
        service._propertySignals[property] = signal
    end
    return signal
end

local services = {
    CoreGui = makeFolder("CoreGui"),
    Workspace = makeFolder("Workspace"),
    UserInputService = {
        InputBegan = makeSignal(),
        InputEnded = makeSignal(),
        InputChanged = makeSignal(),
        MouseBehavior = Enum.MouseBehavior.Default,
        MouseIconEnabled = true,
        GetMouseLocation = function()
            return Vector2.new(120, 80)
        end,
        IsMouseButtonPressed = function()
            return false
        end,
        GetPropertyChangedSignal = propertySignalForService,
    },
    GuiService = {
        GetGuiInset = function()
            return Vector2.new(0, 0)
        end,
    },
    TweenService = {
        Create = function(_, instance, _info, targetProperties)
            return makeTween(instance, targetProperties)
        end,
    },
    TextService = {
        GetTextBoundsAsync = function(_, params)
            local size = params.Size or 16
            return Vector2.new(math.ceil(#tostring(params.Text or "") * size * 0.6), size)
        end,
    },
    LocalizationService = {},
    ReplicatedStorage = makeFolder("ReplicatedStorage"),
    RunService = {
        RenderStepped = makeSignal(),
        Heartbeat = makeSignal(),
        IsStudio = function()
            return true
        end,
    },
    Players = {
        LocalPlayer = {
            DisplayName = "Spec User",
            Name = "SpecUser",
            UserId = 12345,
            PlayerGui = makeFolder("PlayerGui"),
        },
    },
    HttpService = {
        GenerateGUID = function()
            return "00000000-0000-4000-8000-000000000000"
        end,
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
    local moduleScript = sourceRootNode.utility[name]
    assert(moduleScript, string.format("Unknown utility module: %s", tostring(name)))
    return require(moduleScript)
end

local function requireComponent(name)
    local moduleScript = sourceRootNode.components[name]
    assert(moduleScript, string.format("Unknown component module: %s", tostring(name)))
    return require(moduleScript)
end

local function requireTheme(name)
    local moduleScript = sourceRootNode.themes[name]
    assert(moduleScript, string.format("Unknown theme module: %s", tostring(name)))
    return require(moduleScript)
end

local function requireRayfield()
    return require(sourceRootNode)
end

local function instrumentSourceForTest(relativePath, source)
    local previousCoverage = coverage.files[relativePath]
    local ok, instrumented = xpcall(function()
        return instrumentSource(relativePath, source)
    end, debug.traceback)
    local fileCoverage = coverage.files[relativePath]
    coverage.files[relativePath] = previousCoverage

    if not ok then
        error(instrumented, 2)
    end

    return instrumented, fileCoverage
end

_G.__RAYFIELD_TEST_HELPERS = {
    requireUtility = _G.__RAYFIELD_TEST_REQUIRE_UTILITY,
    requireComponent = requireComponent,
    requireTheme = requireTheme,
    requireRayfield = requireRayfield,
    services = services,
    makeSignal = makeSignal,
    instrumentSource = instrumentSourceForTest,
}
_G.__RAYFIELD_TEST_VERBOSE_LOGS = verboseTestLogs

-- gag Rayfield's console output during test runs unless --verbose-logs is set. this is the
-- runner's job, not the library's: src must not know about test environments.
local logModule = _G.__RAYFIELD_TEST_REQUIRE_UTILITY("log")
logModule.setSuppressPredicate(function()
    return _G.__RAYFIELD_TEST_VERBOSE_LOGS ~= true
end)

local results = {
    testsRan = 0,
    successCount = 0,
    failureCount = 0,
    errors = {},
}

local function recordFailure(testName, message)
    results.failureCount += 1
    table.insert(results.errors, {
        test = testName,
        message = tostring(message),
    })
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

local currentSuite = nil

local function createSuite(name, parent)
    return {
        name = name,
        parent = parent,
        beforeEach = {},
        afterEach = {},
        beforeAll = {},
        afterAll = {},
        tests = {},
        children = {},
        registrationErrors = {},
    }
end

local function getCurrentSuite(apiName)
    if not currentSuite then
        error(apiName .. " can only be called while registering a spec", 3)
    end

    return currentSuite
end

local function suitePath(suite)
    local parts = {}
    local cursor = suite

    while cursor do
        if cursor.name then
            table.insert(parts, 1, cursor.name)
        end
        cursor = cursor.parent
    end

    return table.concat(parts, " > ")
end

local function hookName(suite, hook)
    local path = suitePath(suite)
    return if path == "" then hook else path .. " > " .. hook
end

local function testName(suite, name)
    local path = suitePath(suite)
    return if path == "" then name else path .. " > " .. name
end

local function suiteAncestry(suite)
    local ancestry = {}
    local cursor = suite

    while cursor do
        table.insert(ancestry, 1, cursor)
        cursor = cursor.parent
    end

    return ancestry
end

function beforeEach(callback)
    table.insert(getCurrentSuite("beforeEach").beforeEach, callback)
end

function afterEach(callback)
    table.insert(getCurrentSuite("afterEach").afterEach, callback)
end

function beforeAll(callback)
    table.insert(getCurrentSuite("beforeAll").beforeAll, callback)
end

function afterAll(callback)
    table.insert(getCurrentSuite("afterAll").afterAll, callback)
end

function describe(name, callback)
    local parent = getCurrentSuite("describe")
    local suite = createSuite(name, parent)
    table.insert(parent.children, suite)

    local previousSuite = currentSuite
    currentSuite = suite
    local ok, err = xpcall(callback, debug.traceback)
    currentSuite = previousSuite

    if not ok then
        table.insert(suite.registrationErrors, err)
    end
end

function it(name, callback)
    table.insert(getCurrentSuite("it").tests, {
        name = name,
        callback = callback,
    })
end

local function runBeforeEach(suite)
    for _, context in suiteAncestry(suite) do
        for _, hook in context.beforeEach do
            hook()
        end
    end
end

local function runAfterEach(suite)
    local ancestry = suiteAncestry(suite)
    for i = #ancestry, 1, -1 do
        local hooks = ancestry[i].afterEach
        for j = #hooks, 1, -1 do
            hooks[j]()
        end
    end
end

local function runHookList(suite, hooks, label)
    local ok = true

    for _, hook in hooks do
        local hookOk, hookErr = xpcall(hook, debug.traceback)
        if not hookOk then
            local name = hookName(suite, label)
            ok = false
            recordFailure(name, hookErr)
            warn("[FAIL] " .. name)
            warn(hookErr)
        end
    end

    return ok
end

local function recordRegistrationErrors(suite)
    for _, err in suite.registrationErrors do
        local name = hookName(suite, "registration")
        recordFailure(name, err)
        warn("[FAIL] " .. name)
        warn(err)
    end
end

local function runTest(suite, test)
    local nameWithSuites = testName(suite, test.name)
    results.testsRan += 1

    local ok, err = xpcall(function()
        runBeforeEach(suite)
        test.callback()
    end, debug.traceback)

    local afterOk, afterErr = xpcall(function()
        runAfterEach(suite)
    end, debug.traceback)
    if not afterOk then
        -- keep the tests own failure in front; the afterEach error alone usually hides the cause
        err = if ok then afterErr else tostring(err) .. "\n\nafterEach also failed:\n" .. tostring(afterErr)
        ok = false
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

local function runSuite(suite)
    recordRegistrationErrors(suite)

    local beforeAllOk = runHookList(suite, suite.beforeAll, "beforeAll")
    if beforeAllOk then
        for _, test in suite.tests do
            runTest(suite, test)
        end

        for _, child in suite.children do
            runSuite(child)
        end
    end

    runHookList(suite, suite.afterAll, "afterAll")
end

local function collectSpecs(directory, specs)
    for _, entry in fs.readDir(directory) do
        local path = directory .. "/" .. entry
        if fs.isDir(path) then
            collectSpecs(path, specs)
        elseif
            entry:match("%.spec%.lua$")
            or entry:match("%.spec%.luau$")
            or entry:match("%.lune%.lua$")
            or entry:match("%.lune%.luau$")
        then
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

    local rootSuite = createSuite(nil, nil)
    currentSuite = rootSuite
    local ok, err = xpcall(spec, debug.traceback)
    currentSuite = nil

    if not ok then
        table.insert(rootSuite.registrationErrors, err)
    end

    runSuite(rootSuite)
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

    local baselineText = if coverageBaseline then string.format("%.2f%%", coverageBaseline.lineCoverage) else "n/a"
    local updateModeText = if updateCoverageBaseline then " (baseline update mode)" else ""
    local textLines = {
        string.format(
            "Line coverage: %.2f%% (%d/%d), threshold %.2f%%, baseline %s, required %.2f%%%s",
            totalPercent,
            totalCovered,
            totalCoverable,
            coverageThreshold,
            baselineText,
            effectiveCoverageThreshold,
            updateModeText
        ),
        "Scope: " .. coverageScope,
        "",
        "Files:",
    }

    local jsonLines = {
        "{",
        string.format('  "scope": "%s",', jsonEscape(coverageScope)),
        string.format('  "threshold": %.2f,', coverageThreshold),
    }

    if coverageBaseline then
        table.insert(jsonLines, string.format('  "baselineLineCoverage": %.2f,', coverageBaseline.lineCoverage))
    end

    table.insert(jsonLines, string.format('  "effectiveThreshold": %.2f,', effectiveCoverageThreshold))
    table.insert(jsonLines, string.format('  "lineCoverage": %.2f,', totalPercent))
    table.insert(jsonLines, string.format('  "coveredLines": %d,', totalCovered))
    table.insert(jsonLines, string.format('  "coverableLines": %d,', totalCoverable))
    table.insert(jsonLines, '  "files": [')

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
            "coverage: %.2f%% lines (%d/%d), required %.2f%%%s",
            totalPercent,
            totalCovered,
            totalCoverable,
            effectiveCoverageThreshold,
            updateModeText
        )
    )
    print("coverage reports: coverage/coverage.txt, coverage/coverage-summary.json")

    return {
        rows = rows,
        lineCoverage = totalPercent,
        coveredLines = totalCovered,
        coverableLines = totalCoverable,
    }
end

local function appendJsonStringArray(lines, name, values, trailingComma)
    table.insert(lines, string.format('  "%s": [', name))
    for index, value in values do
        table.insert(lines, string.format('    "%s"%s', jsonEscape(value), if index == #values then "" else ","))
    end
    table.insert(lines, "  ]" .. if trailingComma then "," else "")
end

local function writeCoverageBaseline(summary)
    local baselineNotes = {
        "Generated reports are written to coverage/coverage.txt and coverage/coverage-summary.json.",
        "The enforced Lune coverage scope is discovered dynamically from src by default.",
        "Coverage line discovery is heuristic; multi-line table literal continuation lines can still be over-counted.",
        "Run `make coverage-baseline` after intentional coverage changes to refresh this file.",
    }

    local baselineAuditGaps = {
        "Deterministic Lune component coverage exercises construction and public APIs, but real Roblox rendering/input timing still requires Studio or manual validation when UI behavior changes.",
        "src/init.luau: executor-specific compatibility and asset/font download behavior are stubbed in deterministic specs and still require integration validation when touched.",
        "src/utility/odometer.luau: tween completion is simulated by the test shim; visual animation smoothness still requires Roblox runtime validation.",
        "executor-specific globals and public UI APIs still require manual compatibility validation when touched.",
    }

    local function renderBaseline(measuredDate)
        local jsonLines = {
            "{",
            string.format('  "scope": "%s",', jsonEscape(coverageScope)),
            string.format('  "measuredDate": "%s",', measuredDate),
            '  "command": "make coverage-baseline",',
            string.format('  "threshold": %.2f,', coverageThreshold),
            string.format('  "lineCoverage": %.2f,', summary.lineCoverage),
            string.format('  "coveredLines": %d,', summary.coveredLines),
            string.format('  "coverableLines": %d,', summary.coverableLines),
        }

        appendJsonStringArray(jsonLines, "notes", baselineNotes, true)
        table.insert(jsonLines, '  "files": [')

        for index, row in summary.rows do
            table.insert(jsonLines, "    {")
            table.insert(jsonLines, string.format('      "path": "%s",', jsonEscape(row.path)))
            table.insert(jsonLines, string.format('      "lineCoverage": %.2f,', row.lineCoverage))
            table.insert(jsonLines, string.format('      "coveredLines": %d,', row.coveredLines))
            table.insert(jsonLines, string.format('      "coverableLines": %d', row.coverableLines))
            table.insert(jsonLines, "    }" .. if index == #summary.rows then "" else ",")
        end

        table.insert(jsonLines, "  ],")
        appendJsonStringArray(jsonLines, "auditGaps", baselineAuditGaps, false)
        table.insert(jsonLines, "}")

        return table.concat(jsonLines, "\n") .. "\n"
    end

    -- keep the existing date when the numbers didnt move, so regenerating the baseline
    -- daily (the pre-commit hook does) never churns the file
    local baselinePath = root .. "/coverage-baseline.json"
    local existing = if fs.isFile(baselinePath) then fs.readFile(baselinePath) else nil
    local existingDate = if existing then string.match(existing, '"measuredDate":%s*"([^"]+)"') else nil
    local content = renderBaseline(existingDate or os.date("!%Y-%m-%d"))
    if content ~= existing then
        content = renderBaseline(os.date("!%Y-%m-%d") :: string)
    end

    fs.writeFile(baselinePath, content)
    print("coverage baseline updated: coverage-baseline.json")
end

print(string.format("%d/%d tests passed", results.successCount, results.testsRan))

if results.testsRan == 0 then
    warn("Spec files were found but registered zero tests; refusing to pass an empty run.")
    process.exit(1)
end

local coverageSummary = writeCoverageReports()

if results.failureCount > 0 then
    for _, failure in results.errors do
        warn(string.format("%s\n%s", failure.test, failure.message))
    end
    process.exit(1)
end

if updateCoverageBaseline then
    writeCoverageBaseline(coverageSummary)
    process.exit(0)
end

if coverageSummary.lineCoverage + coverageEpsilon < effectiveCoverageThreshold then
    local baselineText = if coverageBaseline
        then string.format(", baseline %.2f%%", coverageBaseline.lineCoverage)
        else ""
    warn(
        string.format(
            "Coverage %.2f%% is below the required %.2f%% threshold (configured %.2f%%%s).",
            coverageSummary.lineCoverage,
            effectiveCoverageThreshold,
            coverageThreshold,
            baselineText
        )
    )
    process.exit(1)
end

process.exit(0)
