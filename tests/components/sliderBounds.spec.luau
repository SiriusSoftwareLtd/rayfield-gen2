local helpers = (_G :: any).__RAYFIELD_TEST_HELPERS

return function()
    local Window = helpers.requireComponent("window")

    describe("component slider bounds", function()
        local window

        local function makeSlider(properties)
            window = Window.new({
                name = "Slider Bounds",
                configuration = { autoSave = false, autoLoad = false },
            })
            local tab = window:CreateTab({ name = "Main" })
            return tab:CreateSlider(properties)
        end

        afterEach(function()
            if window and not window.unloaded then
                window:Unload()
            end
            window = nil

            helpers.services.UserInputService._setMouseLocation(Vector2.new(120, 80))
            helpers.services.UserInputService._setMouseButtonPressed(false)
            helpers.services.GuiService._setGuiInset(Vector2.new(0, 0))
        end)

        -- The harness lays nothing out, so the track is given a width and a place on screen by hand
        local function placeTrack(slider, left, width)
            slider.track.AbsolutePosition = Vector2.new(left, 0)
            slider.track.AbsoluteSize = Vector2.new(width, 14)
        end

        local function pointAt(x)
            helpers.services.UserInputService._setMouseLocation(Vector2.new(x, 8))
        end

        -- Where the pill lands, in pixels from the left of the track. It sits centred on the
        -- fill's leading edge, and the fill is a fraction of the track.
        -- rounded to the pixel it actually renders at: UDim scales are float32, so a scale of
        -- 0.9 across 200px comes back a fraction under 180
        local function pillCentre(slider, width)
            local fill = slider.progress.Size.X
            return math.round(fill.Scale * width + fill.Offset)
        end

        local function pillEdges(slider, width)
            local centre = pillCentre(slider, width)
            local half = slider.handle.Size.X.Offset / 2
            return centre - half, centre + half
        end

        local function finite(n)
            return n == n and n ~= math.huge and n ~= -math.huge
        end

        it("hangs half a pill past each end of the track", function()
            local slider = makeSlider({
                name = "Volume",
                range = { 0, 100 },
                increment = 1,
                value = 0,
                forgetState = true,
            })

            for _, width in { 420, 222, 160, 60 } do
                placeTrack(slider, 0, width)

                slider:Set(0)
                slider:_renderProgress()
                local half = slider.handle.Size.X.Offset / 2
                local left = pillEdges(slider, width)
                expect(left).to.equal(-half) -- centre on the track's left edge

                slider:Set(100)
                slider:_renderProgress()
                local _, right = pillEdges(slider, width)
                expect(right).to.equal(width + half) -- and on its right edge at the top
            end
        end)

        it("puts the pill's centre exactly on the value", function()
            local slider = makeSlider({
                name = "Volume",
                range = { 0, 100 },
                increment = 1,
                value = 0,
                forgetState = true,
            })

            local width = 200
            placeTrack(slider, 0, width)

            for _, case in { { 0, 0 }, { 25, 50 }, { 50, 100 }, { 100, 200 } } do
                slider:Set(case[1])
                slider:_renderProgress()
                expect(pillCentre(slider, width)).to.equal(case[2])
            end
        end)

        it("maps the pointer over the whole track", function()
            local slider = makeSlider({
                name = "Volume",
                range = { 0, 100 },
                increment = 1,
                value = 0,
                forgetState = true,
            })

            placeTrack(slider, 100, 200)

            -- a quarter along the track is a quarter of the range, with no inset to account for
            pointAt(150)
            slider.interact.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
            expect(slider.value).to.equal(25)

            pointAt(200)
            helpers.services.RunService.RenderStepped:Fire()
            expect(slider.value).to.equal(50)

            -- past either end clamps rather than running away
            pointAt(20)
            helpers.services.RunService.RenderStepped:Fire()
            expect(slider.value).to.equal(0)

            pointAt(9999)
            helpers.services.RunService.RenderStepped:Fire()
            expect(slider.value).to.equal(100)

            helpers.services.UserInputService.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
            expect(slider.dragging).to.equal(false)
        end)

        it("carries the pill with the fill instead of positioning it twice", function()
            local slider = makeSlider({
                name = "Volume",
                range = { 0, 100 },
                value = 40,
                forgetState = true,
            })

            placeTrack(slider, 0, 200)
            slider:_renderProgress()

            -- the pill lives inside the fill, pinned to its leading edge, so the fill's size is
            -- the only thing that has to move. A second position would be a second thing to drift.
            expect(slider.handle.Position.X.Scale).to.equal(1)
            expect(slider.handle.Position.X.Offset).to.equal(0)
            expect(slider.handle.AnchorPoint.X).to.equal(0.5)

            local before = slider.handle.Position
            slider:Set(90)
            slider:_renderProgress()
            expect(slider.handle.Position).to.equal(before)
            expect(pillCentre(slider, 200)).to.equal(180)
        end)

        it("stays finite on a track narrower than the pill", function()
            local slider = makeSlider({
                name = "Volume",
                range = { 0, 100 },
                value = 50,
                forgetState = true,
            })

            placeTrack(slider, 0, 10) -- pill is 35 at rest
            slider:_renderProgress()

            local left, right = pillEdges(slider, 10)
            expect(finite(left)).to.equal(true)
            expect(finite(right)).to.equal(true)
            expect(slider.progress.Size.X.Scale >= 0).to.equal(true)

            -- and a drag on it still reads a value rather than dividing by nothing
            pointAt(5)
            slider.interact.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
            expect(finite(slider.value)).to.equal(true)
            helpers.services.UserInputService.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
        end)

        it("ignores a drag before the track has been laid out", function()
            local slider = makeSlider({
                name = "Volume",
                range = { 0, 100 },
                value = 50,
                forgetState = true,
            })

            placeTrack(slider, 0, 0)

            pointAt(40)
            slider.interact.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
            expect(slider.value).to.equal(50) -- untouched, no divide by zero
            helpers.services.UserInputService.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })

            -- once it is laid out the same render puts the pill where the value says
            placeTrack(slider, 0, 200)
            slider:_renderProgress()
            expect(pillCentre(slider, 200)).to.equal(100)
        end)

        it("grows the pill for a drag without moving what the fill owns", function()
            local slider = makeSlider({
                name = "Volume",
                range = { 0, 100 },
                value = 50,
                forgetState = true,
            })

            placeTrack(slider, 0, 200)
            slider:_renderProgress()

            local restWidth = slider.handle.Size.X.Offset
            slider:_setHeld(true)
            expect(slider.handle.Size.X.Offset > restWidth).to.equal(true)

            -- growing is symmetric about the centre, so the value the pill points at is unmoved
            expect(pillCentre(slider, 200)).to.equal(100)

            slider:_setHeld(false)
            expect(slider.handle.Size.X.Offset).to.equal(restWidth)
        end)
    end)
end
