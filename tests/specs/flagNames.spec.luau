local function requireUtility(name)
    local loader = _G.__RAYFIELD_TEST_REQUIRE_UTILITY
    if loader then
        return loader(name)
    end

    return require(game:GetService("ReplicatedStorage").Rayfield.utility[name])
end

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
