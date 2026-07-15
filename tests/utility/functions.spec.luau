--!strict

local helpers = ((_G :: any).__RAYFIELD_TEST_HELPERS or require(script.Parent.Parent.TestHelpers)) :: any
local requireUtility = helpers.requireUtility

return function()
    local functions = requireUtility("functions")
    local colors = requireUtility("colors")
    local flagNames = requireUtility("flagNames")
    local textMetrics = requireUtility("textMetrics")

    describe("utility.functions", function()
        it("exports the shared utility functions", function()
            expect(functions.textWidth).to.equal(textMetrics.textWidth)
            expect(functions.textHeight).to.equal(textMetrics.textHeight)
            expect(functions.deriveFlagFromName).to.equal(flagNames.deriveFlagFromName)
            expect(functions.contrastColor).to.equal(colors.contrastColor)
            expect(functions.toColorSequence).to.equal(colors.toColorSequence)
            expect(functions.contrastText).to.equal(colors.contrastText)
        end)
    end)
end
