local helpers = (_G :: any).__RAYFIELD_TEST_HELPERS

return function()
    local Window = helpers.requireComponent("window")

    -- UDim2 stores its scales as 32-bit floats, so a value put in as 0.4 reads back as
    -- 0.40000000596. Compare fractions with a tolerance rather than for equality.
    local function near(actual, expected)
        return math.abs(actual - expected) < 0.0001
    end

    describe("component progress and console", function()
        local window

        local function makeTab(properties)
            window = Window.new(properties or {
                name = "New Elements",
                configuration = { autoSave = false, autoLoad = false },
            })
            window.hidden = false
            return window:CreateTab({ name = "Main" })
        end

        afterEach(function()
            if window and not window.unloaded then
                window:Unload()
            end
            window = nil
            helpers.services.UserInputService._setMouseLocation(Vector2.new(120, 80))
            helpers.services.GuiService._setGuiInset(Vector2.new(0, 0))
        end)

        describe("progress", function()
            it("fills the track to the value it's given", function()
                local bar = makeTab():CreateProgress({ name = "Download", value = 0.4 })

                expect(bar.value).to.equal(0.4)
                expect(near(bar.fill.Size.X.Scale, 0.4)).to.equal(true)
                expect(bar.readout.Text).to.equal("40%")

                bar:Set(0.75)
                expect(bar.value).to.equal(0.75)
                expect(bar:Get()).to.equal(0.75)
                expect(bar.readout.Text).to.equal("75%")
            end)

            it("takes a range the way a slider does", function()
                local bar = makeTab():CreateProgress({ name = "Download", range = { 0, 200 }, value = 50 })

                expect(bar:Get()).to.equal(50)
                expect(bar:GetPercentage()).to.equal(0.25)
                expect(bar.readout.Text).to.equal("25%")

                -- a range given backwards is still a range
                bar:SetRange(100, 0)
                expect(bar.min).to.equal(0)
                expect(bar.max).to.equal(100)
                expect(bar:Get()).to.equal(50) -- carried across, still in range
                expect(bar:GetPercentage()).to.equal(0.5)

                -- and the value comes with the range when it no longer fits
                bar:SetRange(0, 10)
                expect(bar:Get()).to.equal(10)
            end)

            it("reads a zero-width range as full rather than dividing by zero", function()
                local bar = makeTab():CreateProgress({ name = "Done", range = { 5, 5 }, value = 5 })
                expect(bar:GetPercentage()).to.equal(1)
                expect(bar.readout.Text).to.equal("100%")
            end)

            it("builds the readout with a formatter when it's given one", function()
                local bar = makeTab():CreateProgress({
                    name = "Download",
                    range = { 0, 8 },
                    value = 3,
                    format = function(value, _, max)
                        return string.format("%d of %d", value, max)
                    end,
                })
                expect(bar.readout.Text).to.equal("3 of 8")

                -- a fixed line still wins over the formatter
                bar:SetText("Paused")
                expect(bar.readout.Text).to.equal("Paused")
            end)

            it("hides the readout when it's told to", function()
                local bar = makeTab():CreateProgress({ name = "Quiet", showValue = false })
                expect(bar.readout.Visible).to.equal(false)
            end)

            it("counts stages when it's stepped", function()
                local bar = makeTab():CreateProgress({ name = "Setup", steps = 5, value = 2 })

                -- steps set the range unless one was given, so the value counts them
                expect(bar.min).to.equal(0)
                expect(bar.max).to.equal(5)
                expect(#bar.stepFrames).to.equal(5)
                expect(bar.readout.Text).to.equal("2/5")

                bar:Set(4)
                expect(bar.readout.Text).to.equal("4/5")

                -- the segments tile the track exactly: the scale shares add up to one whole
                local total = 0
                for _, step in bar.stepFrames do
                    total += step.segment.Size.X.Scale
                end
                expect(math.abs(total - 1) < 0.0001).to.equal(true)
            end)

            it("paints exactly the stages it has reached", function()
                local bar = makeTab():CreateProgress({ name = "Setup", steps = 4, value = 0 })
                bar:_setShown(true, false)

                bar:Set(2)
                expect(bar.stepFrames[1].fill.BackgroundTransparency).to.equal(0)
                expect(bar.stepFrames[2].fill.BackgroundTransparency).to.equal(0)
                expect(bar.stepFrames[3].fill.BackgroundTransparency).to.equal(1)
                expect(bar.stepFrames[4].fill.BackgroundTransparency).to.equal(1)
            end)

            it("has nothing to sweep when it's stepped", function()
                local bar = makeTab():CreateProgress({ name = "Setup", steps = 3, indeterminate = true })
                expect(bar._sweep).to.equal(nil)
            end)

            it("ignores a step count too small to be a row", function()
                local bar = makeTab():CreateProgress({ name = "Setup", steps = 1 })
                expect(bar.steps).to.equal(nil)
                expect(bar.fill).never.to.equal(nil) -- fell back to a continuous track
            end)

            it("clamps anything outside 0 to 1, and reads a bad value as empty", function()
                local bar = makeTab():CreateProgress({ name = "Download" })

                bar:Set(2)
                expect(bar.value).to.equal(1)
                bar:Set(-3)
                expect(bar.value).to.equal(0)
                bar:Set(0 / 0) -- NaN
                expect(bar.value).to.equal(0)
                bar:Set("nonsense" :: any)
                expect(bar.value).to.equal(0)
                expect(bar.readout.Text).to.equal("0%")
            end)

            it("takes a readout of your own and gives the percentage back when it's dropped", function()
                local bar = makeTab():CreateProgress({ name = "Download", value = 0.5, text = "Halfway" })
                expect(bar.readout.Text).to.equal("Halfway")

                bar:SetText(nil)
                expect(bar.readout.Text).to.equal("50%")
            end)

            it("sweeps when there's no value to show, and settles once there is", function()
                local bar = makeTab():CreateProgress({ name = "Syncing", indeterminate = true })

                expect(bar.indeterminate).to.equal(true)
                expect(bar._sweep).never.to.equal(nil)
                -- it never leaves the track, so the track has no need to clip and the fill's
                -- rounded ends are never squared off against the track's own corner
                expect(bar.track.ClipsDescendants).never.to.equal(true)

                -- a real value ends the sweep rather than fighting it
                bar:Set(0.6)
                expect(bar.indeterminate).to.equal(false)
                expect(bar._sweep).to.equal(nil)
                expect(bar.fill.Position.X.Scale).to.equal(0)
            end)

            it("turns the sweep on and off without stacking loops", function()
                local bar = makeTab():CreateProgress({ name = "Syncing", value = 0.2 })
                expect(bar._sweep).to.equal(nil)

                bar:SetIndeterminate(true)
                local first = bar._sweep
                expect(first).never.to.equal(nil)

                bar:SetIndeterminate(true) -- already on: same loop, not a second one
                expect(bar._sweep).to.equal(first)

                bar:SetIndeterminate(false)
                expect(bar._sweep).to.equal(nil)
                expect(near(bar.fill.Size.X.Scale, 0.2)).to.equal(true) -- back to the value it held
                expect(bar.fill.AnchorPoint).to.equal(Vector2.new(0, 0.5)) -- and anchored left again
            end)

            it("sweeps on a repeating tween rather than a loop of its own", function()
                local bar = makeTab():CreateProgress({ name = "Syncing", indeterminate = true })

                -- a tween, not a thread: Roblox repeats it, so there is nothing of ours left
                -- running once the window goes and nothing to cancel by hand
                expect(typeof(bar._sweep)).never.to.equal("thread")
                expect(bar._sweep.Cancel).never.to.equal(nil)
            end)

            it("stops its sweep when it's removed", function()
                local tab = makeTab()
                local bar = tab:CreateProgress({ name = "Syncing", indeterminate = true })
                expect(bar._sweep).never.to.equal(nil)

                bar:Remove()
                expect(bar._sweep).to.equal(nil)
            end)
        end)

        describe("console", function()
            it("holds the height it's given rather than growing with its content", function()
                local block = makeTab():CreateConsole({ name = "Console", height = 150 })
                local before = block.main.Size.Y.Offset

                for index = 1, 40 do
                    block:Append("line " .. index)
                end

                expect(block.panel.Size.Y.Offset).to.equal(150)
                expect(block.main.Size.Y.Offset).to.equal(before)
                expect(block.scroll.AutomaticCanvasSize).to.equal(Enum.AutomaticSize.Y)
                expect(block.scroll.ScrollingDirection).to.equal(Enum.ScrollingDirection.Y)
            end)

            it("never stands shorter than it can usefully be", function()
                local block = makeTab():CreateConsole({ name = "Console", height = 4 })
                expect(block.height).to.equal(48)

                block:SetHeight(300)
                expect(block.height).to.equal(300)
                expect(block.panel.Size.Y.Offset).to.equal(300)

                block:SetHeight(nil :: any)
                expect(block.height).to.equal(120) -- the default, not zero
            end)

            it("appends, replaces and clears its body", function()
                local block = makeTab():CreateConsole({ text = "first" })

                block:Append("second")
                expect(block:Get()).to.equal("first\nsecond")

                block:Set("only")
                expect(block:Get()).to.equal("only")

                -- an empty block doesn't lead with a blank line
                block:Clear()
                block:Append("fresh")
                expect(block:Get()).to.equal("fresh")

                block:Clear()
                expect(block:Get()).to.equal("")
            end)

            it("rolls the oldest lines off once it's full", function()
                local block = makeTab():CreateConsole({ name = "Console", maxLines = 3 })
                block:Clear()

                for index = 1, 6 do
                    block:Append("line " .. index)
                end

                expect(#block.lines).to.equal(3)
                expect(block:Get()).to.equal("line 4\nline 5\nline 6")
            end)

            it("splits a multi-line append into lines so the cap still counts", function()
                local block = makeTab():CreateConsole({ maxLines = 2 })
                block:Clear()
                block:Append("one\ntwo\nthree")

                expect(#block.lines).to.equal(2)
                expect(block:Get()).to.equal("two\nthree")
            end)

            it("says so rather than throwing when there's no clipboard", function()
                local block = makeTab():CreateConsole({ text = "print()" })
                expect(block:Copy()).to.equal(false) -- no executor here to provide one
            end)

            it("renders output as text, not markup", function()
                local block = makeTab():CreateConsole({ text = "<b>not bold</b>" })
                local row = block.lineLabels[1]
                expect(row.RichText).to.equal(false)
                expect(row.Text).to.equal("<b>not bold</b>")
                expect(row.TextWrapped).to.equal(true)
            end)

            it("costs the same per line whether the buffer is empty or full", function()
                local block = makeTab():CreateConsole({ maxLines = 50 })
                block:Clear()

                -- fill it, then keep going: the pool stops growing and rows are recycled
                for index = 1, 200 do
                    block:Append("line " .. index)
                end
                expect(#block.lines).to.equal(50)
                expect(#block.lineLabels).to.equal(50)
                expect(block:Get()).to.equal(table.concat(block.lines, "\n"))

                -- the newest line owns the highest order, so it still sorts last
                local newest, highest = nil, -1
                for _, label in block.lineLabels do
                    if label.LayoutOrder > highest then
                        highest, newest = label.LayoutOrder, label
                    end
                end
                expect(newest.Text).to.equal("line 200")
            end)

            it("stands taller with a title than without one", function()
                local tab = makeTab()
                local titled = tab:CreateConsole({ name = "Console", height = 100 })
                local bare = tab:CreateConsole({ height = 100 })

                expect(titled.title).never.to.equal(nil)
                expect(bare.title).to.equal(nil)
                expect(titled.main.Size.Y.Offset > bare.main.Size.Y.Offset).to.equal(true)
            end)
        end)

        describe("slider drag reporting", function()
            it("tells the callback whether the handle is still down", function()
                local tab = makeTab()
                local seen = {}
                local slider = tab:CreateSlider({
                    name = "Drag",
                    range = { 0, 100 },
                    increment = 1,
                    value = 0,
                    forgetState = true,
                    callback = function(value, dragging)
                        table.insert(seen, { value = value, dragging = dragging })
                    end,
                })
                slider.track.AbsolutePosition = Vector2.new(100, 300)
                slider.track.AbsoluteSize = Vector2.new(200, 14)

                -- a programmatic set is nobody dragging anything
                slider:Set(10)
                expect(seen[1].value).to.equal(10)
                expect(seen[1].dragging).to.equal(false)

                helpers.services.UserInputService._setMouseLocation(Vector2.new(150, 80))
                slider.interact.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
                expect(seen[2].value).to.equal(25)
                expect(seen[2].dragging).to.equal(true) -- the press already counts as dragging

                helpers.services.UserInputService._setMouseLocation(Vector2.new(200, 80))
                helpers.services.RunService.RenderStepped:Fire()
                expect(seen[3].value).to.equal(50)
                expect(seen[3].dragging).to.equal(true)

                -- release: one last call on the settled value, saying the gesture is over
                helpers.services.UserInputService.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
                local last = seen[#seen]
                expect(last.value).to.equal(50)
                expect(last.dragging).to.equal(false)
            end)
        end)

        describe("element lock", function()
            it("dims, blocks input and refuses to fire the callback", function()
                local tab = makeTab()
                local fired = 0
                local toggle = tab:CreateToggle({
                    name = "Auto Farm",
                    value = false,
                    forgetState = true,
                    callback = function()
                        fired += 1
                    end,
                })

                toggle:Set(true)
                expect(fired).to.equal(1)

                toggle:Lock()
                expect(toggle:IsLocked()).to.equal(true)
                expect(toggle.lockScrim).never.to.equal(nil)
                expect(toggle.lockScrim.Visible).to.equal(true)
                expect(toggle.lockScrim.Active).to.equal(true) -- it eats the input itself

                -- the callback is the part that matters: a lock that only greys out is not a lock
                toggle:Set(false)
                expect(fired).to.equal(1)

                toggle:Unlock()
                expect(toggle:IsLocked()).to.equal(false)
                toggle:Set(true)
                expect(fired).to.equal(2)
            end)

            it("says why in the description, and puts the element's own back after", function()
                local button = makeTab():CreateButton({ name = "Teleport", description = "Go to the boss." })
                expect(button.descriptor.titleLabel.Text).to.equal("Go to the boss.")

                button:Lock("Needs a premium key")
                expect(button.descriptor.titleLabel.Text).to.equal("Needs a premium key")

                button:Unlock()
                expect(button.descriptor.titleLabel.Text).to.equal("Go to the boss.")
            end)

            it("keeps the reason dimmed to the locked strength through a reveal", function()
                local button = makeTab():CreateButton({ name = "Teleport", description = "Go to the boss." })
                button:Lock("Needs a premium key")
                button:_setShown(false, false)
                button:_setShown(true, false)
                expect(math.abs(button.descriptor.titleLabel.TextTransparency - 0.55) < 1e-3).to.equal(true)

                button:Unlock()
                button:_setShown(true, false)
                expect(math.abs(button.descriptor.titleLabel.TextTransparency - 0.7) < 1e-3).to.equal(true)
            end)

            it("leaves the element visible rather than covering it up", function()
                local toggle = makeTab():CreateToggle({ name = "Auto Farm", forgetState = true })
                toggle:Lock()

                -- you can still read what is locked: the scrim only dims, and carries nothing
                expect(toggle.lockScrim.BackgroundTransparency > 0.5).to.equal(true)
                expect(#toggle.lockScrim:GetChildren()).to.equal(1) -- the corner, nothing else
            end)

            it("does nothing at all when unlocking something never locked", function()
                local toggle = makeTab():CreateToggle({ name = "Auto Farm", forgetState = true })

                toggle:Unlock()
                expect(toggle:IsLocked()).to.equal(false)
                -- no scrim was built for a state it was already in
                expect(toggle.lockScrim).to.equal(nil)
            end)

            it("takes a new reason while it's already locked", function()
                local button = makeTab():CreateButton({ name = "Teleport", description = "Go to the boss." })

                button:Lock("Needs a premium key")
                button:Lock("Server is full")
                expect(button.descriptor.titleLabel.Text).to.equal("Server is full")

                -- and the element's own description survives, rather than the first reason
                -- being mistaken for it
                button:Unlock()
                expect(button.descriptor.titleLabel.Text).to.equal("Go to the boss.")
            end)

            it("is idempotent, and builds only one shade", function()
                local toggle = makeTab():CreateToggle({ name = "Auto Farm", forgetState = true })

                toggle:Lock()
                local scrim = toggle.lockScrim
                toggle:Lock()
                expect(toggle.lockScrim).to.equal(scrim)

                toggle:Unlock()
                toggle:Unlock()
                expect(toggle:IsLocked()).to.equal(false)
            end)

            it("reaches every element a user can actually operate", function()
                local tab = makeTab()
                local elements = {
                    tab:CreateButton({ name = "Button" }),
                    tab:CreateToggle({ name = "Toggle", forgetState = true }),
                    tab:CreateSlider({ name = "Slider", range = { 0, 10 }, forgetState = true }),
                    tab:CreateInput({ name = "Input", forgetState = true }),
                    tab:CreateKeybind({ name = "Keybind", forgetState = true }),
                    tab:CreateColorPicker({ name = "Colour", forgetState = true }),
                    tab:CreateDropdown({ name = "Dropdown", options = { "A", "B" }, forgetState = true }),
                }

                for _, element in elements do
                    expect(typeof(element.Lock)).to.equal("function")
                    element:Lock()
                    expect(element:IsLocked()).to.equal(true)
                    element:Unlock()
                    expect(element:IsLocked()).to.equal(false)
                end
            end)
        end)

        describe("collapsed pill", function()
            local function collapsed(properties)
                makeTab(properties)
                window:CreateTab({ name = "Other" })
                window.hidden = true
                window.animating = false
                return window
            end

            it("collapses to a badge when it's icon only, and a pill otherwise", function()
                collapsed({
                    name = "Pill",
                    showIconOnly = true,
                    configuration = { autoSave = false, autoLoad = false },
                })
                local _, iconSize = window:_collapsedRect()
                expect(iconSize.X.Offset).to.equal(iconSize.Y.Offset) -- square, so it rounds to a circle
                window:Unload()

                collapsed({ name = "Pill", configuration = { autoSave = false, autoLoad = false } })
                local _, pillSize = window:_collapsedRect()
                expect(pillSize.X.Offset > pillSize.Y.Offset).to.equal(true)
            end)

            it("opens on a tap but not on a drag", function()
                local w = collapsed()
                local uis = helpers.services.UserInputService

                -- a press that barely moves is a tap: it opens
                uis._setMouseLocation(Vector2.new(100, 100))
                w.collapsedInteract.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
                uis._setMouseLocation(Vector2.new(102, 101))
                helpers.services.RunService.RenderStepped:Fire()
                uis.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
                expect(w.hidden).to.equal(false)

                -- and a press that travels is a drag: it moves and stays shut
                w.hidden = true
                w.animating = false
                uis._setMouseLocation(Vector2.new(100, 100))
                w.collapsedInteract.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
                uis._setMouseLocation(Vector2.new(260, 240))
                helpers.services.RunService.RenderStepped:Fire()
                uis.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })

                expect(w.hidden).to.equal(true)
                expect(w._collapsedPosition).never.to.equal(nil)
            end)

            it("stays where it was dragged to on the next collapse", function()
                local w = collapsed()
                w._collapsedPosition = UDim2.fromOffset(400, 250)

                local home = w:_collapsedRect()
                expect(home).to.equal(UDim2.fromOffset(400, 250))
            end)
        end)
    end)
end
