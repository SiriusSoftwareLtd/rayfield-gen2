local helpers = (_G :: any).__RAYFIELD_TEST_HELPERS
local requireUtility = helpers.requireUtility

return function()
    local hapticEngine = requireUtility("HapticEngine")

    describe("utility.HapticEngine", function()
        local container

        beforeEach(function()
            container = Instance.new("Folder")
            container.Parent = helpers.services.CoreGui
            hapticEngine.setContainer(container)
        end)

        afterEach(function()
            hapticEngine.setEnabled(false) -- also tears the pooled effects down
            hapticEngine.releaseContainer(container)
            container:Destroy()
            container = nil
        end)

        it("toggles enabled state and no-ops feedback calls safely", function()
            hapticEngine.setEnabled(true)
            expect(hapticEngine.enabled).to.equal(true)

            hapticEngine.click()
            hapticEngine.notify()

            hapticEngine.setEnabled(false)
            expect(hapticEngine.enabled).to.equal(false)

            hapticEngine.click()
            hapticEngine.notify()
        end)

        it("plays the pooled effect on click and notify when enabled", function()
            hapticEngine.setEnabled(true)

            hapticEngine.click()
            local effects = container:GetChildren()
            expect(#effects).to.equal(1)
            expect(effects[1].ClassName).to.equal("HapticEffect")
            expect(effects[1].Played).to.equal(true)

            -- a second click reuses the pooled effect rather than making another
            effects[1].Played = false
            hapticEngine.click()
            expect(effects[1].Played).to.equal(true)
            expect(#container:GetChildren()).to.equal(1)

            -- notify pools its own preset and plays it too
            hapticEngine.notify()
            expect(#container:GetChildren()).to.equal(2)
            for _, effect in container:GetChildren() do
                expect(effect.Played).to.equal(true)
            end
        end)

        it("creates and plays nothing while disabled", function()
            hapticEngine.setEnabled(false)

            hapticEngine.click()
            hapticEngine.notify()
            expect(#container:GetChildren()).to.equal(0)
        end)
    end)
end
