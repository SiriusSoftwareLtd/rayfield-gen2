local function requireUtility(name)
    local loader = _G.__RAYFIELD_TEST_REQUIRE_UTILITY
    if loader then
        return loader(name)
    end

    return require(game:GetService("ReplicatedStorage").Rayfield.utility[name])
end

return function()
    local colors = requireUtility("colors")

    describe("utility.colors", function()
        it("chooses black text for light backgrounds", function()
            expect(colors.contrastColor(Color3.new(1, 1, 1))).to.equal(Color3.fromRGB(0, 0, 0))
            expect(colors.contrastText(Color3.new(1, 1, 1))).to.equal(Color3.fromRGB(20, 20, 20))
        end)

        it("chooses white text for dark backgrounds", function()
            expect(colors.contrastColor(Color3.new(0, 0, 0))).to.equal(Color3.fromRGB(255, 255, 255))
            expect(colors.contrastText(Color3.new(0, 0, 0))).to.equal(Color3.fromRGB(255, 255, 255))
        end)

        it("wraps Color3 values as ColorSequence values", function()
            expect(typeof(colors.toColorSequence(Color3.new(1, 0, 0)))).to.equal("ColorSequence")
        end)

        it("passes ColorSequence values through", function()
            local sequence = ColorSequence.new(Color3.new(1, 0, 0))

            expect(colors.toColorSequence(sequence)).to.equal(sequence)
        end)
    end)
end
