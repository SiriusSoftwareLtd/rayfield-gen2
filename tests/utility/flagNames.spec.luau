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

        it("hashes names that strip down to nothing", function()
            -- %w is ASCII only, so these used to derive an empty flag and skip persistence
            expect(flagNames.deriveFlagFromName("音量")).to.equal("Flagb441cfe3")
            expect(flagNames.deriveFlagFromName("Настройки")).to.equal("Flag6879436d")
            expect(flagNames.deriveFlagFromName("!!!")).to.equal("Flag2d53a722")
        end)

        it("keeps hashed flags stable and distinct", function()
            -- hardcoded above so a session that saved a config can always reload it
            expect(flagNames.deriveFlagFromName("音量")).to.equal(flagNames.deriveFlagFromName("音量"))
            expect(flagNames.deriveFlagFromName("音量")).never.to.equal(flagNames.deriveFlagFromName("音量 "))
            expect(flagNames.deriveFlagFromName("音量")).never.to.equal(flagNames.deriveFlagFromName("設定"))
        end)

        it("leaves an empty name alone", function()
            expect(flagNames.deriveFlagFromName("")).to.equal("")
        end)
    end)
end
