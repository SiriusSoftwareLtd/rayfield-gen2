--!strict

return function()
    local globals = _G :: any

    describe("runner lifecycle consumer", function()
        it("runs previous top-level afterAll without leaking beforeEach", function()
            expect(globals.__RAYFIELD_RUNNER_AFTER_ALL).to.equal("done")
            expect(globals.__RAYFIELD_RUNNER_LEAK_COUNT).to.equal(1)

            globals.__RAYFIELD_RUNNER_AFTER_ALL = nil
            globals.__RAYFIELD_RUNNER_LEAK_COUNT = nil
        end)
    end)
end
