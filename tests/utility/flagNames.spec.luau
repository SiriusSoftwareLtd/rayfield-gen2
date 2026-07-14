local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local flagNames = requireUtility("flagNames")

    describe("utility.flagNames", function()
        it("derives a compact flag from spaced words", function()
            expect(flagNames.deriveFlagFromName("My Toggle")).to.equal("MyToggle")
        end)

        it("capitalizes each word", function()
            expect(flagNames.deriveFlagFromName("hello world")).to.equal("HelloWorld")
        end)

        it("drops non-alphanumeric separators", function()
            expect(flagNames.deriveFlagFromName("Auto-Farm!")).to.equal("AutoFarm")
        end)
    end)
end
