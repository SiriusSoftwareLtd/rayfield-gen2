--!strict

local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local locale = requireUtility("locale")
    local variables = requireUtility("variables")

    describe("utility.locale", function()
        local originalStrings
        local originalCurrent
        local originalTranslator
        local originalRobloxLocaleId

        beforeEach(function()
            originalStrings = locale.strings
            originalCurrent = locale.current
            originalTranslator = locale.translator
            originalRobloxLocaleId = variables.localizationService.RobloxLocaleId

            locale.strings = {}
            locale.current = "en"
            locale.translator = nil
            variables.localizationService.RobloxLocaleId = nil
        end)

        afterEach(function()
            locale.strings = originalStrings
            locale.current = originalCurrent
            locale.translator = originalTranslator
            variables.localizationService.RobloxLocaleId = originalRobloxLocaleId
        end)

        it("wraps and identifies translatable tokens", function()
            local token = locale.t("Search")

            expect(locale.isToken(token)).to.equal(true)
            expect(locale.sourceOf(token)).to.equal("Search")
            expect(locale.t("")).to.equal("")
            expect(locale.t(nil)).never.to.be.ok()
            expect(locale.isToken("Search")).to.equal(false)
        end)

        it("resolves translator, exact locale, language fallback, and source text", function()
            locale.register({
                ["pt"] = {
                    Search = "Pesquisar",
                },
                ["pt-br"] = {
                    Settings = "Configuracoes",
                },
            })

            locale.setActive("PT-BR")
            expect(locale.resolve("Settings")).to.equal("Configuracoes")
            expect(locale.resolve("Search")).to.equal("Pesquisar")
            expect(locale.resolve("Missing")).to.equal("Missing")
            expect(locale.resolve(123)).to.equal(123)

            locale.translator = function(source, localeId)
                if localeId == "pt-br" and source == "Search" then
                    return "Buscar"
                end
                return ""
            end
            expect(locale.resolve("Search")).to.equal("Buscar")

            locale.translator = function()
                error("translator failed")
            end
            expect(locale.resolve("Search")).to.equal("Pesquisar")
        end)

        it("ignores invalid registration entries and normalizes active locale", function()
            locale.register(nil)
            locale.register({
                fr = {
                    Search = "Chercher",
                },
                [5] = {
                    Search = "bad",
                },
                de = "bad",
            })

            expect(locale.setActive("FR-CA")).to.equal("fr-ca")
            expect(locale.resolve("Search")).to.equal("Chercher")
            expect(locale.setActive("")).to.equal("en")
        end)

        it("detects the Roblox locale with an English fallback", function()
            variables.localizationService.RobloxLocaleId = "ES-MX"
            expect(locale.detect()).to.equal("es-mx")

            variables.localizationService.RobloxLocaleId = ""
            expect(locale.detect()).to.equal("en")
        end)
    end)
end
