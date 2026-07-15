--!strict

local helpers = ((_G :: any).__RAYFIELD_TEST_HELPERS or require(script.Parent.Parent.TestHelpers)) :: any

return function()
    local Rayfield = helpers.requireRayfield()
    local image = helpers.requireUtility("image")
    local variables = helpers.requireUtility("variables")

    describe("Rayfield init and themes", function()
        local originalSecureMode
        local originalPreload
        local originalLoadFont
        local originalGuiContainer
        local testGuiContainer: Folder?
        local window: any

        local function isServerContext(): boolean
            local runService = game:GetService("RunService") :: any
            return type(runService.IsServer) == "function" and runService:IsServer()
        end

        local function waitForShown(targetWindow: any)
            local deadline = os.clock() + 2
            while not targetWindow.hasShownOnce and os.clock() < deadline do
                task.wait()
            end
        end

        beforeEach(function()
            originalSecureMode = variables.secureMode
            originalPreload = image.preload
            originalLoadFont = variables.fontManager.loadFont
            originalGuiContainer = variables.guiContainer
            local container = Instance.new("Folder")
            container.Name = "RayfieldTestGuiContainer"
            testGuiContainer = container
            variables.guiContainer = container
        end)

        afterEach(function()
            if window and not window.unloaded then
                window:Unload()
            end
            window = nil
            variables.secureMode = originalSecureMode
            image.preload = originalPreload
            variables.fontManager.loadFont = originalLoadFont
            variables.guiContainer = originalGuiContainer
            if testGuiContainer then
                testGuiContainer:Destroy()
            end
            testGuiContainer = nil
        end)

        it("requires every built-in theme", function()
            for _, name in { "default", "amethyst", "cobalt", "ember", "frost", "rose" } do
                local theme = helpers.requireTheme(name)
                expect(type(theme)).to.equal("table")
                expect(theme.WindowColor).to.be.ok()
                expect(theme.AccentColor).to.be.ok()
            end
        end)

        it("creates a window through the public init module", function()
            if isServerContext() then
                return
            end

            variables.secureMode = false

            window = Rayfield:CreateWindow({
                name = "Init Window",
                subtitle = "Normal",
                configuration = {
                    autoSave = false,
                    autoLoad = false,
                },
            })
            waitForShown(window)

            expect(window.name).to.equal("Init Window")
            expect(window.hidden).to.equal(false)
            expect(window.hasShownOnce).to.equal(true)
        end)

        it("runs the secure-mode preload and font-swap branches deterministically", function()
            if isServerContext() then
                return
            end

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
            waitForShown(window)

            expect(preloadCalled).to.equal(true)
            expect(#loadedWeights).to.equal(2)
            expect(window.name).to.equal("Secure Window")
            expect(window.hidden).to.equal(false)
        end)
    end)
end
