local helpers = (_G :: any).__RAYFIELD_TEST_HELPERS

return function()
    local Window = helpers.requireComponent("window")

    describe("component window workflows", function()
        local window

        local function makeWindow(properties)
            window = Window.new(properties or {
                name = "Spec Window",
                subtitle = "Harness",
                showName = "Spec",
                configuration = {
                    autoSave = false,
                    autoLoad = false,
                },
            })
            return window
        end

        afterEach(function()
            if window and not window.unloaded then
                window:Unload()
            end
            window = nil
        end)

        it("constructs tabs, tags, flags, and common controls", function()
            local clicked = 0
            local toggleValue = nil
            local sliderValue = nil
            local dropdownValue = nil
            local inputValue = nil
            local keyPressed = nil
            local keyChanged = nil
            local colorValue = nil
            local alphaValue = nil

            local w = makeWindow()
            expect(w.name).to.equal("Spec Window")
            expect(w.hidden).to.equal(true)
            expect(#w.tabs).to.equal(1)

            local tag = w:CreateTag({
                text = "Beta",
                icon = 123,
                color = Color3.fromRGB(255, 210, 0),
            })
            tag:SetText("Ready")
            tag:SetIcon(456)
            tag:SetColor(Color3.fromRGB(20, 180, 120))
            tag:Set({
                text = "Live",
                icon = nil,
                color = Color3.fromRGB(40, 80, 200),
            })
            expect(tag.title.Text).to.equal("Live")

            local first = w:CreateTab({ name = "Main", icon = 100 })
            local second = w:CreateTab({ name = "Second" })
            expect(w.selectedTab).to.equal(first)
            second:Select()
            expect(w.selectedTab).to.equal(second)
            first:Select()

            local section = first:CreateSection({ name = "Basics", icon = 101 })
            expect(section.__type).to.equal("Section")

            local button = first:CreateButton({
                name = "Run",
                icon = 102,
                description = "Runs the spec callback",
                callback = function()
                    clicked += 1
                end,
            })
            button.interact.MouseButton1Click:Fire()
            expect(clicked).to.equal(1)

            local toggle = first:CreateToggle({
                name = "Enabled",
                value = false,
                callback = function(value)
                    toggleValue = value
                end,
            })
            toggle:Set(true)
            expect(toggle.value).to.equal(true)
            expect(toggleValue).to.equal(true)
            expect(w:Get(toggle.flag)).to.equal(true)
            expect(w:Set(toggle.flag, false)).to.equal(true)
            expect(toggle.value).to.equal(false)
            w.Flags[toggle.flag] = true
            expect(toggle.value).to.equal(true)

            local slider = first:CreateSlider({
                name = "Volume",
                range = { 10, 0 },
                increment = 0.5,
                value = 3.2,
                suffix = "%",
                callback = function(value)
                    sliderValue = value
                end,
            })
            expect(slider.value).to.equal(3)
            slider:Set(8.7)
            expect(slider.value).to.equal(8.5)
            expect(sliderValue).to.equal(8.5)

            -- the snap grid anchors at range[1]: both endpoints of a non-aligned range stay reachable
            local offGrid = first:CreateSlider({
                name = "OffGrid",
                range = { 0.5, 2.5 },
                increment = 1,
                value = 0.5,
            })
            expect(offGrid.value).to.equal(0.5)
            offGrid:Set(2.5)
            expect(offGrid.value).to.equal(2.5)
            offGrid:Set(100)
            expect(offGrid.value).to.equal(2.5)

            local dropdown = first:CreateDropdown({
                name = "Choice",
                options = { "One", "Two", "Two" },
                value = "One",
                callback = function(value)
                    dropdownValue = value
                end,
            })
            expect(#dropdown.options).to.equal(2)
            dropdown:Set("Two")
            expect(dropdown.value[1]).to.equal("Two")
            expect(dropdownValue).to.equal("Two")
            dropdown:Add("Three")
            dropdown:Add("Three")
            expect(#dropdown.options).to.equal(3)
            dropdown:Remove("One")
            dropdown:Refresh({ "Blue", "Green" })
            dropdown:Set("Green")
            expect(dropdown.selectedLabel.Text).to.equal("Green")
            -- removing the selected option must tell the callback the selection changed
            dropdown:Remove("Green")
            expect(dropdownValue).to.equal(nil)

            local multi = first:CreateDropdown({
                name = "Multi",
                options = { "A", "B", "C" },
                multiSelect = true,
                value = { "A", "B", "A" },
            })
            expect(#multi.value).to.equal(2)
            multi:Set({ "B", "C", "Z" })
            expect(#multi.value).to.equal(2)
            expect(multi.selectedLabel.Text).to.equal("Various")

            local input = first:CreateInput({
                name = "Amount",
                value = "10",
                numeric = true,
                callback = function(value)
                    inputValue = value
                end,
            })
            input:Set("42.5")
            expect(input.value).to.equal("42.5")
            expect(inputValue).to.equal("42.5")
            input.input.Text = "13"
            input.input.FocusLost:Fire()
            expect(input.value).to.equal("13")

            local keybind = first:CreateKeybind({
                name = "Hotkey",
                value = Enum.KeyCode.H,
                callback = function(value)
                    keyPressed = value
                end,
                onChanged = function(value)
                    keyChanged = value
                end,
            })
            keybind:Set("J")
            expect(keybind.value).to.equal(Enum.KeyCode.J)
            expect(keyChanged).to.equal(Enum.KeyCode.J)
            helpers.services.UserInputService.InputBegan:Fire({
                UserInputType = Enum.UserInputType.Keyboard,
                KeyCode = Enum.KeyCode.J,
            }, false)
            expect(keyPressed).to.equal(Enum.KeyCode.J)
            expect(keybind:_serialize()[1]).to.equal("Enum.KeyCode")
            keybind:_deserialize({ "Enum.KeyCode", Enum.KeyCode.K.Value })
            expect(keybind.value).to.equal(Enum.KeyCode.K)
            expect(keyChanged).to.equal(Enum.KeyCode.K)

            local invalidEnumOk = pcall(function()
                keybind:_deserialize({ "Enum.NotARealEnum", Enum.KeyCode.L.Value })
            end)
            expect(invalidEnumOk).to.equal(true)
            expect(keybind.value).to.equal(Enum.KeyCode.K)

            local invalidValueOk = pcall(function()
                keybind:_deserialize({ "Enum.KeyCode", -1 })
            end)
            expect(invalidValueOk).to.equal(true)
            expect(keybind.value).to.equal(Enum.KeyCode.K)

            local colorPicker = first:CreateColorPicker({
                name = "Accent",
                value = Color3.fromRGB(255, 0, 0),
                alpha = 0.5,
                callback = function(color, alpha)
                    colorValue = color
                    alphaValue = alpha
                end,
            })
            colorPicker:Set("#00ff00")
            colorPicker:SetAlpha(0.25)
            expect(colorValue).to.equal(colorPicker.value)
            expect(alphaValue).to.equal(0.25)
            expect(colorPicker:_serialize()).to.equal("00FF0040")
            colorPicker:_deserialize("336699cc")
            expect(colorPicker.alpha).to.equal(0.8)

            local stat = first:CreateStat({
                name = "Users",
                value = 100,
                prefix = "$",
                suffix = "k",
            })
            stat:Set(125)
            stat:Set(100)
            stat:ResetBaseline(80)
            expect(stat.value).to.equal(80)

            local row = first:CreateGroup({ direction = "row" })
            local rowButton = row:CreateButton({ name = "Row Button" })
            local rowToggle = row:CreateToggle({ name = "Row Toggle" })
            local rowStat = row:CreateStat({ name = "Row Stat", compact = true, display = "change" })
            local rowSlider = row:CreateSlider({ name = "Row Slider", value = 1, minimal = true })
            expect(#row.elements).to.equal(4)
            rowButton:MoveToBottom()
            rowToggle:MoveUp()
            rowStat:Set(4)
            rowSlider:Set(2)

            local column = first:CreateGroup({ direction = "column" })
            expect(column:CreateSection({ name = "Column Section" }).__type).to.equal("Section")
            expect(column:CreateDropdown({ name = "Column Dropdown", options = { "X" } }).__type).to.equal("Dropdown")

            w:ChangeTheme("frost")
            w:RegisterTranslations({
                ["zz-test"] = {
                    ["Spec Window"] = "Translated Window",
                    ["Run"] = "Translated Run",
                },
            })
            w:SetLocale("zz-test")
            expect(w.title.Text).to.equal("Translated Window")
            w:SetTranslator(function(source)
                if source == "Run" then
                    return "Hooked Run"
                end
                return nil
            end)
            w:SetLocale("zz-test")
            expect(button.title.Text).to.equal("Hooked Run")

            w:Navigate(first)
            expect(w.elementsLayout.CurrentPage).to.equal(first.tabPage)
            w:Navigate("Second")
            expect(w.elementsLayout.CurrentPage).to.equal(second.tabPage)
            w:Navigate("Missing")

            expect(w:Set("missing", true)).to.equal(false)
            expect(w:Save("")).to.equal(false)
            expect(w:Load("")).to.equal(false)
            expect(type(w:GetPath())).to.equal("string")

            tag:Remove()
            expect(#w.tags).to.equal(0)
        end)

        it("shows, hides, searches, and creates transient surfaces", function()
            local w = makeWindow({
                name = "Surface Window",
                showName = "Surface",
                configuration = {
                    autoSave = false,
                    autoLoad = false,
                },
            })
            local tab = w:CreateTab({ name = "Main" })
            tab:CreateButton({ name = "Visible Button" })
            tab:CreateToggle({ name = "Visible Toggle" })
            tab:CreateSlider({ name = "Visible Slider", value = 25 })
            tab:CreateDropdown({ name = "Visible Dropdown", options = { "Alpha", "Beta" }, value = "Alpha" })
            tab:CreateColorPicker({ name = "Visible Color", value = Color3.fromRGB(20, 40, 60) })
            tab:CreateStat({ name = "Visible Stat", value = 5 })

            w:Show()
            expect(w.hidden).to.equal(false)
            expect(w.hasShownOnce).to.equal(true)

            w:Toast({
                title = "Toast",
                subtitle = "Done",
                icon = 123,
                duration = 0,
            })
            w:Notify({
                title = "Notice",
                content = "Done",
                icon = 123,
                duration = 0,
            })

            local popupCallback = false
            local popup = w:Popup({
                title = "Confirm",
                subtitle = "Spec",
                content = "Pick an option.",
                icon = 123,
                boxes = {
                    { title = "Box", description = "Details", icon = 456 },
                    "Plain Box",
                },
                options = {
                    {
                        text = "Accept",
                        style = "primary",
                        callback = function()
                            popupCallback = true
                        end,
                    },
                    {
                        text = "Delete",
                        style = "danger",
                    },
                },
            })
            expect(popup._closed).to.equal(false)
            popup:Close()
            expect(popup._closed).to.equal(true)
            expect(popupCallback).to.equal(false)

            w.searchAction.interact.MouseButton1Click:Fire()
            expect(w._searching).to.equal(true)
            w.searchInput.Text = "Visible"
            w.searchInput:GetPropertyChangedSignal("Text"):Fire()
            w.searchAction.interact.MouseButton1Click:Fire()
            expect(w._searching).to.equal(false)

            w:ToggleMinimise()
            expect(w.minimised).to.equal(true)
            w:ToggleMinimise()
            expect(w.minimised).to.equal(false)

            w:Hide()
            expect(w.hidden).to.equal(true)
            w:ToggleHide()
            expect(w.hidden).to.equal(false)
            w:ToggleHide()
            expect(w.hidden).to.equal(true)

            tab:Remove()
            expect(table.find(w.tabs, tab)).never.to.be.ok()
        end)
    end)
end
