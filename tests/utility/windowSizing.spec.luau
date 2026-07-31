local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local windowSizing = requireUtility("windowSizing")

    local function fit(x: number, y: number)
        local size = windowSizing.fit(Vector2.new(x, y))
        return size.X.Offset, size.Y.Offset
    end

    describe("utility.windowSizing", function()
        it("leaves roomy screens on the default size", function()
            for _, viewport in { Vector2.new(1280, 720), Vector2.new(1920, 1080), Vector2.new(1080, 810) } do
                local width, height = fit(viewport.X, viewport.Y)
                expect(width).to.equal(windowSizing.defaultSize.X)
                expect(height).to.equal(windowSizing.defaultSize.Y)
            end
        end)

        it("falls back to the default when the viewport is missing or implausible", function()
            for _, viewport in { nil, Vector2.new(0, 0), Vector2.new(1, 1), Vector2.new(640, 120) } do
                local size = windowSizing.fit(viewport)
                expect(size.X.Offset).to.equal(windowSizing.defaultSize.X)
                expect(size.Y.Offset).to.equal(windowSizing.defaultSize.Y)
            end
        end)

        it("only widens once height is actually constrained", function()
            -- tall enough for the full height, so width stays exactly default
            local wideWidth = fit(2560, 1440)
            expect(wideWidth).to.equal(windowSizing.defaultSize.X)

            -- a short screen gives height up, and earns width back for it
            local phoneWidth, phoneHeight = fit(844, 390)
            expect(phoneHeight < windowSizing.defaultSize.Y).to.equal(true)
            expect(phoneWidth > windowSizing.defaultSize.X).to.equal(true)
        end)

        it("keeps a phone inside the occupancy caps", function()
            for _, viewport in { Vector2.new(667, 375), Vector2.new(844, 390), Vector2.new(720, 360) } do
                local width, height = fit(viewport.X, viewport.Y)
                expect(width <= viewport.X * 0.86).to.equal(true)
                expect(height <= viewport.Y * 0.80).to.equal(true)
            end
        end)

        it("leaves room above a centred window for the roblox topbar", function()
            -- the vertical cap is what clears the inset, so the gap above must beat it
            for _, viewport in { Vector2.new(667, 375), Vector2.new(844, 390), Vector2.new(720, 360) } do
                local _, height = fit(viewport.X, viewport.Y)
                expect((viewport.Y - height) / 2 >= 36).to.equal(true)
            end
        end)

        it("never returns a size that overflows a plausible screen", function()
            for _, viewport in
                { Vector2.new(640, 360), Vector2.new(667, 375), Vector2.new(390, 844), Vector2.new(1194, 834) }
            do
                local width, height = fit(viewport.X, viewport.Y)
                expect(width <= viewport.X).to.equal(true)
                expect(height <= viewport.Y).to.equal(true)
            end
        end)

        it("holds the floor and the aspect ceiling on a very short screen", function()
            local width, height = fit(1200, 240)
            expect(height).to.equal(windowSizing.minSize.Y)
            expect(width <= height * 1.95).to.equal(true)
        end)

        it("never drops below the minimum width", function()
            local width = fit(300, 700)
            expect(width >= windowSizing.minSize.X).to.equal(true)
        end)

        it("returns whole pixels", function()
            local width, height = fit(823, 431)
            expect(width % 1).to.equal(0)
            expect(height % 1).to.equal(0)
        end)
    end)
end
