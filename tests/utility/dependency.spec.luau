--!nolint BuiltinGlobalWrite
--!strict

local helpers = (_G :: any).__RAYFIELD_TEST_HELPERS
local requireUtility = helpers.requireUtility

return function()
    describe("utility dependency boundaries", function()
        local log
        local variables
        local runtime
        local originalHelpers
        local originalWarn: any
        local originalPrint: any
        local originalVariablesSecureMode
        local originalRuntimeSecureMode
        local originalVerboseLogs
        local warnings
        local prints

        local function captureConsole()
            warnings = {}
            prints = {}

            local env = getfenv() :: any
            env.warn = function(...)
                table.insert(warnings, { ... })
            end

            env.print = function(...)
                table.insert(prints, { ... })
            end
        end

        beforeEach(function()
            runtime = runtime or requireUtility("runtime")
            originalHelpers = (_G :: any).__RAYFIELD_TEST_HELPERS
            originalWarn = warn
            originalPrint = print
            originalVariablesSecureMode = if variables then variables.secureMode else nil
            originalRuntimeSecureMode = runtime.secureMode
            originalVerboseLogs = _G.__RAYFIELD_TEST_VERBOSE_LOGS
            warnings = {}
            prints = {}
        end)

        afterEach(function()
            if variables and originalVariablesSecureMode ~= nil then
                variables.secureMode = originalVariablesSecureMode
            end
            if runtime then
                runtime.secureMode = originalRuntimeSecureMode
            end
            if log and variables then
                log.setSuppressPredicate(function()
                    return variables.secureMode
                end)
            elseif log then
                log.setSuppressPredicate(nil :: any)
            end
            _G.__RAYFIELD_TEST_HELPERS = originalHelpers
            _G.__RAYFIELD_TEST_VERBOSE_LOGS = originalVerboseLogs
            local env = getfenv() :: any
            env.warn = originalWarn
            env.print = originalPrint
        end)

        it("loads log and fontManager before variables", function()
            log = requireUtility("log")
            local fontManager = requireUtility("fontManager")
            variables = requireUtility("variables")

            expect(type(log.warn)).to.equal("function")
            expect(type(log.print)).to.equal("function")
            expect(type(fontManager.new)).to.equal("function")
            expect(type(variables.brandFont)).to.equal("function")
        end)

        it("uses runtime secure mode by default", function()
            log = log or requireUtility("log")
            log.setSuppressPredicate(nil :: any)
            captureConsole()
            _G.__RAYFIELD_TEST_HELPERS = nil
            _G.__RAYFIELD_TEST_VERBOSE_LOGS = nil

            runtime.secureMode = false
            log.warn("visible")
            log.print("visible")

            runtime.secureMode = true
            log.warn("hidden")
            log.print("hidden")

            expect(#warnings).to.equal(1)
            expect(#prints).to.equal(1)
        end)

        it("uses mutable variables secure mode after variables configures it", function()
            log = log or requireUtility("log")
            variables = variables or requireUtility("variables")
            captureConsole()
            _G.__RAYFIELD_TEST_HELPERS = nil
            _G.__RAYFIELD_TEST_VERBOSE_LOGS = nil

            variables.secureMode = false
            log.warn("visible")
            log.print("visible")

            variables.secureMode = true
            log.warn("hidden")
            log.print("hidden")

            expect(#warnings).to.equal(1)
            expect(#prints).to.equal(1)
        end)

        it("suppresses test output unless verbose logs are enabled", function()
            log = log or requireUtility("log")
            captureConsole()
            _G.__RAYFIELD_TEST_HELPERS = originalHelpers
            _G.__RAYFIELD_TEST_VERBOSE_LOGS = false

            log.warn("hidden")
            log.print("hidden")

            expect(#warnings).to.equal(0)
            expect(#prints).to.equal(0)

            _G.__RAYFIELD_TEST_VERBOSE_LOGS = true
            log.warn("visible")
            log.print("visible")

            expect(#warnings).to.equal(1)
            expect(#prints).to.equal(1)
        end)

        it("ignores verbose test logs outside the test environment", function()
            log = log or requireUtility("log")
            log.setSuppressPredicate(nil :: any)
            captureConsole()
            _G.__RAYFIELD_TEST_HELPERS = nil

            runtime.secureMode = false
            _G.__RAYFIELD_TEST_VERBOSE_LOGS = false
            log.warn("visible")
            log.print("visible")

            runtime.secureMode = true
            _G.__RAYFIELD_TEST_VERBOSE_LOGS = true
            log.warn("hidden")
            log.print("hidden")

            expect(#warnings).to.equal(1)
            expect(#prints).to.equal(1)
        end)

        it("routes fontManager diagnostics through log suppression", function()
            log = log or requireUtility("log")
            variables = variables or requireUtility("variables")
            local fontManager = requireUtility("fontManager")
            local fallback = Font.fromEnum(Enum.Font.SourceSans)
            local manager = fontManager.new("LogSpecFonts", true, true, nil, {
                saveToDisk = true,
                skipCache = false,
                fallbackFont = fallback,
            })
            captureConsole()
            _G.__RAYFIELD_TEST_HELPERS = originalHelpers
            _G.__RAYFIELD_TEST_VERBOSE_LOGS = true

            variables.secureMode = false
            expect(manager:loadFont(nil)).to.equal(fallback)
            expect(#warnings).to.equal(1)

            variables.secureMode = true
            expect(manager:loadFont(nil)).to.equal(fallback)
            expect(#warnings).to.equal(1)
        end)
    end)
end
