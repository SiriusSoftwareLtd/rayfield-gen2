local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local reflow = requireUtility("reflow")

    local function frame(anchor: Vector2, position: UDim2, size: Vector2)
        local instance = Instance.new("Frame")
        instance.AnchorPoint = anchor
        instance.Position = position
        instance.AbsoluteSize = size
        return instance
    end

    describe("utility.reflow", function()
        it("lands a layout at once when it is not animated", function()
            local instance = frame(Vector2.new(0, 0), UDim2.fromOffset(0, 0), Vector2.new(100, 20))

            reflow.morph(instance, {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -15, 0.5, 0),
                Size = UDim2.fromOffset(222, 14),
            }, false)

            expect(instance.AnchorPoint).to.equal(Vector2.new(1, 0.5))
            expect(instance.Position).to.equal(UDim2.new(1, -15, 0.5, 0))
            expect(instance.Size).to.equal(UDim2.fromOffset(222, 14))
        end)

        it("rewrites the position an anchor change would otherwise move", function()
            -- the anchor is what the position is measured from, so taking a new one without
            -- rewriting the position teleports the element before the tween has even started
            local instance = frame(Vector2.new(0, 0), UDim2.fromOffset(20, 10), Vector2.new(100, 20))

            reflow.morph(instance, { AnchorPoint = Vector2.new(1, 0.5) }, true)

            expect(instance.AnchorPoint).to.equal(Vector2.new(1, 0.5))
            -- moved by exactly the anchor's share of the element's own size, so it has not moved
            expect(instance.Position).to.equal(UDim2.fromOffset(120, 20))
        end)

        it("leaves the position alone when the anchor is already the one asked for", function()
            local instance = frame(Vector2.new(0.5, 0.5), UDim2.fromOffset(40, 40), Vector2.new(100, 20))

            reflow.morph(instance, { AnchorPoint = Vector2.new(0.5, 0.5) }, true)

            expect(instance.Position).to.equal(UDim2.fromOffset(40, 40))
        end)

        it("does nothing when there is nothing to move", function()
            local instance = frame(Vector2.new(0, 0), UDim2.fromOffset(5, 5), Vector2.new(100, 20))

            reflow.morph(instance, {}, true)

            expect(instance.Position).to.equal(UDim2.fromOffset(5, 5))
        end)
    end)
end
