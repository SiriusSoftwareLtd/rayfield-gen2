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

        it("caps the height at exactly 70% of the screen", function()
            -- pinned, so lowering the cap fails here instead of sliding through the bounds
            -- checks below. 360 lands a pixel under because 360 * 0.70 is not exact in floats.
            local _, small = fit(800, 360)
            expect(small).to.equal(251)
            local _, medium = fit(844, 390)
            expect(medium).to.equal(273)
            local _, large = fit(955, 440)
            expect(large).to.equal(308)
            local _, windowed = fit(1280, 600)
            expect(windowed).to.equal(420)
        end)

        it("keeps a phone inside the occupancy caps", function()
            for _, viewport in { Vector2.new(667, 375), Vector2.new(844, 390), Vector2.new(720, 360) } do
                local width, height = fit(viewport.X, viewport.Y)
                expect(width <= viewport.X * 0.86).to.equal(true)
                expect(height <= viewport.Y * 0.70).to.equal(true)
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

        it("holds the aspect ceiling against the height it actually ships", function()
            -- the cap has to be measured off the whole-pixel height, not the fraction it came
            -- from, or the shipped width can sit a pixel over it
            for _, viewport in
                { Vector2.new(1200, 240), Vector2.new(400, 201), Vector2.new(640, 260), Vector2.new(900, 300) }
            do
                local width, height = fit(viewport.X, viewport.Y)
                expect(width <= height * 1.95).to.equal(true)
            end
        end)

        it("keeps the minimum as a floor while the screen can afford it", function()
            local width = fit(400, 700)
            expect(width >= windowSizing.minSize.X).to.equal(true)
        end)

        it("gives the floor up rather than overflow a screen too small for it", function()
            -- both of these clear the plausibility check but cannot hold the minimum size
            local narrowWidth, narrowHeight = fit(240, 700)
            expect(narrowWidth <= 240).to.equal(true)
            expect(narrowWidth < windowSizing.minSize.X).to.equal(true)
            expect(narrowHeight <= 700).to.equal(true)

            local shortWidth, shortHeight = fit(1200, 240)
            expect(shortHeight <= 240).to.equal(true)
            expect(shortHeight < windowSizing.minSize.Y).to.equal(true)
            expect(shortWidth <= 1200).to.equal(true)
        end)

        it("holds the occupancy caps down to the smallest believed viewport", function()
            for _, viewport in
                { Vector2.new(200, 200), Vector2.new(240, 700), Vector2.new(1200, 240), Vector2.new(210, 380) }
            do
                local width, height = fit(viewport.X, viewport.Y)
                expect(width <= viewport.X * 0.86).to.equal(true)
                expect(height <= viewport.Y * 0.70).to.equal(true)
            end
        end)

        it("returns whole pixels", function()
            local width, height = fit(823, 431)
            expect(width % 1).to.equal(0)
            expect(height % 1).to.equal(0)
        end)

        it("keeps a hand-picked size instead of re-fitting it", function()
            -- the whole point of the separate path: a size the screen would never pick for
            -- itself survives, where fit would hand back the default for the same screen
            local size = windowSizing.clampUserSize(Vector2.new(900, 640), Vector2.new(1920, 1080))
            expect(size.X).to.equal(900)
            expect(size.Y).to.equal(640)
        end)

        it("lets a hand-picked size have the screen, less a margin", function()
            -- the occupancy caps are a judgement about a size we choose for a screen; a size
            -- dragged out by hand is entitled to the screen it was dragged across
            for _, viewport in { Vector2.new(1920, 1080), Vector2.new(844, 390), Vector2.new(200, 200) } do
                local size = windowSizing.clampUserSize(Vector2.new(9999, 9999), viewport)
                expect(size.X).to.equal(viewport.X - 40)
                expect(size.Y).to.equal(viewport.Y - 40)
            end

            -- pinned against the automatic caps, so a change back to them fails here
            local desktop = windowSizing.clampUserSize(Vector2.new(9999, 9999), Vector2.new(1920, 1080))
            expect(desktop.X > 1920 * 0.86).to.equal(true)
            expect(desktop.Y > 1080 * 0.7).to.equal(true)
        end)

        it("holds a hand-picked size to a floor of its own, above the automatic one", function()
            -- the automatic floor is what a small screen has to live with; there is room here,
            -- so a hand-dragged window stops where its own layout stops drawing properly
            local size = windowSizing.clampUserSize(Vector2.new(10, 10), Vector2.new(1920, 1080))
            expect(size.X).to.equal(windowSizing.manualMinSize.X)
            expect(size.Y).to.equal(windowSizing.manualMinSize.Y)
            expect(windowSizing.manualMinSize.X > windowSizing.minSize.X).to.equal(true)
        end)

        it("gives the floor up rather than overflow a screen too small for a hand-picked size", function()
            local size = windowSizing.clampUserSize(Vector2.new(400, 400), Vector2.new(240, 700))
            expect(size.X < windowSizing.manualMinSize.X).to.equal(true)
            expect(size.X).to.equal(200)
        end)

        it("leaves a hand-picked size alone when the viewport is missing or implausible", function()
            -- a camera mid-init reports one of these, and clamping against it would pull a
            -- window the user just dragged out back to the floor for the rest of the session
            for _, viewport in { nil, Vector2.new(0, 0), Vector2.new(640, 120) } do
                local size = windowSizing.clampUserSize(Vector2.new(900, 640), viewport)
                expect(size.X).to.equal(900)
                expect(size.Y).to.equal(640)
            end
        end)

        it("returns whole pixels for a hand-picked size", function()
            local size = windowSizing.clampUserSize(Vector2.new(823.4, 431.7), Vector2.new(1920, 1080))
            expect(size.X % 1).to.equal(0)
            expect(size.Y % 1).to.equal(0)
        end)
    end)
end
