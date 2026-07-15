--!strict

local helpers = ((_G :: any).__RAYFIELD_TEST_HELPERS or require(script.Parent.Parent.TestHelpers)) :: any
local requireUtility = helpers.requireUtility

return function()
    local persistence = requireUtility("persistence")
    local config = requireUtility("persistenceConfig")
    local settings = requireUtility("persistenceSettings")

    describe("utility.persistence", function()
        it("exposes configuration persistence functions", function()
            expect(persistence.getPath).to.equal(config.getPath)
            expect(persistence.save).to.equal(config.save)
            expect(persistence.load).to.equal(config.load)
            expect(persistence.list).to.equal(config.list)
            expect(persistence.delete).to.equal(config.delete)
        end)

        it("exposes settings persistence functions", function()
            expect(persistence.getSettingsPath).to.equal(settings.getSettingsPath)
            expect(persistence.saveSettings).to.equal(settings.saveSettings)
            expect(persistence.loadSettings).to.equal(settings.loadSettings)
        end)
    end)
end
