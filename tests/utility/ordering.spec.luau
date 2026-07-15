--!strict

local helpers = ((_G :: any).__RAYFIELD_TEST_HELPERS or require(script.Parent.Parent.TestHelpers)) :: any
local requireUtility = helpers.requireUtility

return function()
    local assignOrder = requireUtility("ordering")

    describe("utility.ordering", function()
        it("assigns the requested order to the main element", function()
            local element: any = {
                main = {},
            }

            assignOrder(element, 30)

            expect(element.main.LayoutOrder).to.equal(30)
        end)

        it("places descriptors immediately after their element", function()
            local element: any = {
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
