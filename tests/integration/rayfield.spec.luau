local helpers = (_G :: any).__RAYFIELD_TEST_HELPERS

return function()
    local Rayfield = helpers.requireRayfield()
    local image = helpers.requireUtility("image")
    local variables = helpers.requireUtility("variables")

    describe("Rayfield init and themes", function()
        local originalSecureMode
        local originalPreload
        local originalLoadFont
        local window

        beforeEach(function()
            originalSecureMode = variables.secureMode
            originalPreload = image.preload
            originalLoadFont = variables.fontManager.loadFont
        end)

        afterEach(function()
            if window and not window.unloaded then
                window:Unload()
            end
            window = nil
            variables.secureMode = originalSecureMode
            image.preload = originalPreload
            variables.fontManager.loadFont = originalLoadFont
        end)

        it("requires every built-in theme", function()
            for _, name in { "default", "amethyst", "cobalt", "ember", "frost", "rose" } do
                local theme = helpers.requireTheme(name)
                expect(type(theme)).to.equal("table")
                expect(theme.WindowColor).to.be.ok()
                expect(theme.AccentColor).to.be.ok()
            end
        end)

        it("pings a window's heartbeat only while the window is up", function()
            local heartbeat = helpers.requireUtility("heartbeat")
            local originalStart = heartbeat.start
            local started = {}
            heartbeat.start = function(target, alive)
                table.insert(started, { target = target, alive = alive })
                return true
            end

            local ok, err = pcall(function()
                variables.secureMode = false
                window = Rayfield:CreateWindow({ name = "Plain" })
                expect(#started).to.equal(0)
                window:Unload()

                local link = "https://www.sentivel.com/api/heartbeat/" .. string.rep("a", 64)
                window = Rayfield:CreateWindow({ name = "Monitored", heartbeat = link })
                expect(#started).to.equal(1)
                expect(started[1].target).to.equal(link)
                expect(started[1].alive()).to.equal(true)
                window:Unload()
                expect(started[1].alive()).to.equal(false)

                -- a gui torn down from outside, as a re-executed script does to the old copy
                window = Rayfield:CreateWindow({ name = "Monitored", heartbeat = link })
                expect(started[2].alive()).to.equal(true)
                window.screenGui.Parent = nil
                expect(started[2].alive()).to.equal(false)
                window:Unload()

                -- every window prop takes either casing
                window = Rayfield:CreateWindow({ Name = "Monitored", Heartbeat = link } :: any)
                expect(#started).to.equal(3)
                expect(started[3].target).to.equal(link)
            end)
            heartbeat.start = originalStart
            assert(ok, err)
        end)

        it("still flags a bad heartbeat link in Studio, and survives props that aren't a table", function()
            local log = helpers.requireUtility("log")
            local originalWarn = log.warn
            local warnings = {}
            log.warn = function(message)
                table.insert(warnings, message)
            end

            local ok, err = pcall(function()
                variables.secureMode = false
                window = Rayfield:CreateWindow({ name = "Heartbeat", heartbeat = string.rep("a", 64) })
                expect(#warnings).to.equal(0)
                window:Unload()

                window = Rayfield:CreateWindow({ name = "Heartbeat", heartbeat = "https://example.com/ping" })
                expect(#warnings).to.equal(1)
                expect(string.find(warnings[1], "only pings Sentivel", 1, true)).to.be.ok()
                window:Unload()

                window = Rayfield:CreateWindow(true :: any)
                expect(window).to.be.ok()
            end)
            log.warn = originalWarn
            assert(ok, err)
        end)

        it("creates a window through the public init module", function()
            variables.secureMode = false

            window = Rayfield:CreateWindow({
                name = "Init Window",
                subtitle = "Normal",
                configuration = {
                    autoSave = false,
                    autoLoad = false,
                },
            })

            expect(window.name).to.equal("Init Window")
            expect(window.hidden).to.equal(false)
            expect(window.hasShownOnce).to.equal(true)
        end)

        it("runs the secure-mode preload and font-swap branches deterministically", function()
            local preloadCalled = false
            local loadedWeights = {}

            variables.secureMode = true
            image.preload = function(onSettled)
                preloadCalled = true
                if onSettled then
                    onSettled(0)
                end
            end
            variables.fontManager.loadFont = function(_, _asset, weight)
                table.insert(loadedWeights, weight)
                return Font.new("font://secure", weight, Enum.FontStyle.Normal)
            end

            window = Rayfield:CreateWindow({
                name = "Secure Window",
                fallbackFont = Enum.Font.SourceSans,
                configuration = {
                    autoSave = false,
                    autoLoad = false,
                },
            })

            expect(preloadCalled).to.equal(true)
            expect(#loadedWeights).to.equal(2)
            expect(window.name).to.equal("Secure Window")
            expect(window.hidden).to.equal(false)
        end)
    end)
end
