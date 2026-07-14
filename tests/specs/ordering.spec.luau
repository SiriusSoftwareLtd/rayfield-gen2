local function requireUtility(name)
    local loader = _G.__RAYFIELD_TEST_REQUIRE_UTILITY
    if loader then
        return loader(name)
    end

    return require(game:GetService("ReplicatedStorage").Rayfield.utility[name])
end

return function()
    local assignOrder = requireUtility("ordering")

    describe("utility.ordering", function()
        it("assigns the requested order to the main element", function()
            local element = {
                main = {},
            }

            assignOrder(element, 30)

            expect(element.main.LayoutOrder).to.equal(30)
        end)

        it("places descriptors immediately after their element", function()
            local element = {
                main = {},
                descriptor = {
                    main = {},
                },
            }

            assignOrder(element, 40)

            expect(element.main.LayoutOrder).to.equal(40)
            expect(element.descriptor.main.LayoutOrder).to.equal(41)
        end)
    end)
end
