--!strict

local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local variables = requireUtility("variables")
    local constants = requireUtility("constants")

    describe("utility.variables", function()
        local originalSecureMode

        beforeEach(function()
            originalSecureMode = variables.secureMode
        end)

        afterEach(function()
            variables.secureMode = originalSecureMode
        end)

        it("returns the configured brand font outside secure mode", function()
            variables.secureMode = false

            local font = variables.brandFont(Enum.FontWeight.Bold)

            expect(font.Family).to.equal(constants.fontAsset)
            expect(font.Weight).to.equal(Enum.FontWeight.Bold)
        end)

        it("returns the fallback family while secure mode is active", function()
            variables.secureMode = true

            local font = variables.brandFont(Enum.FontWeight.Light)

            expect(font.Family).to.equal(variables.fallbackFont.Family)
            expect(font.Weight).to.equal(Enum.FontWeight.Light)
        end)
    end)
end
