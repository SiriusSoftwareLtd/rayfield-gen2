--!strict

local helpers = ((_G :: any).__RAYFIELD_TEST_HELPERS or require(script.Parent.Parent.TestHelpers)) :: any
local requireUtility = helpers.requireUtility

return function()
    local hapticEngine = requireUtility("HapticEngine")

    describe("utility.HapticEngine", function()
        afterEach(function()
            hapticEngine.setEnabled(false)
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
    end)
end
