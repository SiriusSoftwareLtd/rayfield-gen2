--!strict

local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local textMetrics = requireUtility("textMetrics")
    local variables = requireUtility("variables")

    describe("utility.textMetrics", function()
        local originalGetTextBoundsAsync

        beforeEach(function()
            originalGetTextBoundsAsync = variables.textService.GetTextBoundsAsync
        end)

        afterEach(function()
            variables.textService.GetTextBoundsAsync = originalGetTextBoundsAsync
        end)

        it("measures and caches text width", function()
            local calls = 0
            variables.textService.GetTextBoundsAsync = function(_, params: any)
                calls += 1
                return {
                    X = #params.Text * 7.25,
                    Y = params.Size + 3,
                }
            end

            local font = Font.new("font://spec", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

            expect(textMetrics.textWidth(font, 12, "abc")).to.equal(22)
            expect(textMetrics.textWidth(font, 12, "abc")).to.equal(22)
            expect(calls).to.equal(1)
        end)

        it("falls back when width measurement fails", function()
            variables.textService.GetTextBoundsAsync = function()
                error("measurement failed")
            end

            local font = Font.new("font://spec", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

            expect(textMetrics.textWidth(font, 10, "abcd")).to.equal(22)
        end)

        it("measures text height with fallback", function()
            local font = Font.new("font://spec", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

            variables.textService.GetTextBoundsAsync = function(_, params)
                expect(params.Width).to.equal(48)
                return {
                    X = 40,
                    Y = 19.2,
                }
            end
            expect(textMetrics.textHeight(font, 14, "wrapped", 48)).to.equal(20)

            variables.textService.GetTextBoundsAsync = function()
                error("measurement failed")
            end
            expect(textMetrics.textHeight(font, 14, "wrapped", 48)).to.equal(14)
        end)
    end)
end
