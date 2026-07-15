--!strict

local helpers = ((_G :: any).__RAYFIELD_TEST_HELPERS or require(script.Parent.Parent.TestHelpers)) :: any
local requireUtility = helpers.requireUtility

return function()
    local moveable = requireUtility("moveable")

    describe("utility.moveable", function()
        it("adds movement methods that delegate to the owning tab", function()
            local class: any = {}
            moveable(class)

            local calls = {}
            local element: any = setmetatable({}, { __index = class })
            local sibling: any = {}
            element.tab = {
                elements = { sibling, element, {} },
                _moveElement = function(_, moved, index)
                    table.insert(calls, moved == element and tostring(index) or "wrong")
                end,
            }

            element:MoveTo(3)
            element:MoveToTop()
            element:MoveToBottom()
            element:MoveUp()
            element:MoveDown()

            expect(table.concat(calls, ",")).to.equal("3,1,3,1,3")
            expect(moveable(class)).to.equal(class)
        end)

        it("does not move up or down when the element is not registered", function()
            local class: any = {}
            moveable(class)

            local calls = 0
            local element: any = setmetatable({}, { __index = class })
            element.tab = {
                elements = {},
                _moveElement = function()
                    calls += 1
                end,
            }

            element:MoveUp()
            element:MoveDown()

            expect(calls).to.equal(0)
        end)
    end)
end
