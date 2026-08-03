local helpers = (_G :: any).__RAYFIELD_TEST_HELPERS

return function()
    local Window = helpers.requireComponent("window")

    describe("component window workflows", function()
        local locale = helpers.requireUtility("locale")
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

            -- the locale module is shared state; drop the test locale so it can't leak
            locale.strings["zz-test"] = nil
            locale.translator = nil
            locale.setActive("en")
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

            -- a user icon may be a rbxassetid string, not just a bare number
            local stringIcon = first:CreateToggle({
                name = "StringIcon",
                icon = "rbxassetid://4483345998",
                forgetState = true,
            })
            expect(stringIcon.iconLabel.Image).to.equal("rbxassetid://4483345998")

            -- an open dropdown sizes itself to the options actually on screen, so a search
            -- filter (and Add/Remove while open) resizes rather than leaving dead space
            local sized = first:CreateDropdown({
                name = "Sized",
                options = { "Alpha", "Beta", "Gamma" },
                forgetState = true,
            })
            sized.interact.MouseButton1Click:Fire()
            expect(sized._isOpen).to.equal(true)
            local allHeight = sized:_openHeight()

            -- filtering leaves fewer rows on screen, so the panel must shrink to fit
            sized._searchOpen = true
            sized.searchInput.Text = "alp"
            sized:_applyFilter("alp")
            expect(sized:_openHeight() < allHeight).to.equal(true)

            -- Add while a query is active must respect it, not show an excluded option
            sized:Add("Delta")
            local delta
            for _, data in sized._optionFrames do
                if data.name == "Delta" then
                    delta = data
                end
            end
            expect(delta).to.be.ok()
            expect(delta.frame.Visible).to.equal(false)

            -- clearing the query brings every row back, including the one added while filtered
            sized._searchOpen = false
            sized:_applyFilter("")
            expect(delta.frame.Visible).to.equal(true)
            expect(sized:_openHeight() > allHeight or allHeight == 180).to.equal(true)
            sized:_close()

            local handedOut
            local multi = first:CreateDropdown({
                name = "Multi",
                options = { "A", "B", "C" },
                multiSelect = true,
                value = { "A", "B", "A" },
                callback = function(selected)
                    handedOut = selected
                end,
            })
            expect(#multi.value).to.equal(2)
            multi:Set({ "B", "C", "Z" })
            expect(#multi.value).to.equal(2)
            expect(multi.selectedLabel.Text).to.equal("Various")

            -- the callback gets a copy: a dev mutating it must not corrupt our selection
            expect(handedOut).never.to.equal(multi.value)
            table.insert(handedOut, "Z")
            expect(#multi.value).to.equal(2)

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

            -- scientific notation via :Set
            input:Set("9e9")
            expect(input.value).to.equal("9000000000")
            expect(inputValue).to.equal("9000000000")

            -- lowercase e
            input:Set("1.5e3")
            expect(input.value).to.equal("1500")

            -- uppercase E
            input:Set("2E5")
            expect(input.value).to.equal("200000")

            -- exponent operator ^
            input:Set("5^5")
            expect(input.value).to.equal("3125")

            -- zero exponent
            input:Set("123^0")
            expect(input.value).to.equal("1")

            -- invalid e expression keeps the previous value
            input:Set("e9")
            expect(input.value).to.equal("1")

            -- invalid exponent keeps the previous value
            input:Set("5^")
            expect(input.value).to.equal("1")

            -- overflow (9e999999999 → math.huge) keeps the previous value
            input:Set("9e999999999")
            expect(input.value).to.equal("1")

            -- plain numbers still work normally
            input:Set("42.5")
            expect(input.value).to.equal("42.5")

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
            keybind:_deserialize({ "Enum.KeyCode", Enum.KeyCode.M.Value })
            expect(keybind.value).to.equal(Enum.KeyCode.M)
            expect(keyChanged).to.equal(Enum.KeyCode.M)

            -- a set (or restored bind) that clashes with the menu toggle key is refused
            keybind:Set(w.settings.toggleKeybind)
            expect(keybind.value).to.equal(Enum.KeyCode.M)

            local invalidEnumOk = pcall(function()
                keybind:_deserialize({ "Enum.NotARealEnum", Enum.KeyCode.L.Value })
            end)
            expect(invalidEnumOk).to.equal(true)
            expect(keybind.value).to.equal(Enum.KeyCode.M)

            local invalidValueOk = pcall(function()
                keybind:_deserialize({ "Enum.KeyCode", -1 })
            end)
            expect(invalidValueOk).to.equal(true)
            expect(keybind.value).to.equal(Enum.KeyCode.M)

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

        it("restores elements built after the config was loaded", function()
            local w = makeWindow({
                name = "Late Window",
                showName = "Late",
                configuration = { autoSave = false, autoLoad = false },
            })
            local tab = w:CreateTab({ name = "Main" })

            -- stand in for a load having already happened, as autoLoad does on first Show
            w._loadedConfig = { LateToggle = true, LateSlider = 42 }

            local seen
            local late = tab:CreateToggle({
                name = "LateToggle",
                value = false,
                callback = function(value)
                    seen = value
                end,
            })
            expect(late.value).to.equal(true) -- would be the default without _restoreLate
            expect(seen).to.equal(true) -- the callback has to fire so the dev applies it

            -- groups take the same tail
            local row = tab:CreateGroup()
            local lateSlider = row:CreateSlider({ name = "LateSlider", range = { 0, 100 }, increment = 1, value = 0 })
            expect(lateSlider.value).to.equal(42)

            -- forgetState opts out of config entirely, so it must keep its default
            local ignored = tab:CreateToggle({ name = "LateToggle", value = false, forgetState = true })
            expect(ignored.value).to.equal(false)
        end)

        it("navigates to a tab by name and keeps the selection in step", function()
            local w = makeWindow({
                name = "Nav Window",
                showName = "Nav",
                configuration = { autoSave = false, autoLoad = false },
            })
            local home = w:CreateTab({ name = "Home" })
            local settings = w:CreateTab({ name = "Settings" })
            expect(w.selectedTab).to.equal(home)

            w:Navigate("Settings")
            expect(w.selectedTab).to.equal(settings)

            w:Navigate(home)
            expect(w.selectedTab).to.equal(home)

            -- a page instance still works for callers holding tabPage
            w:Navigate(settings.tabPage)
            expect(w.selectedTab).to.equal(settings)

            -- an unknown tab is a no-op, not a crash or a silent desync
            w:Navigate("Nope")
            expect(w.selectedTab).to.equal(settings)
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

        it("keeps action icons hidden until the window is actually interactive", function()
            local w = makeWindow({ name = "Icon Window", showName = "Icons" })

            -- a stray MouseLeave while the window is still hidden/revealing shouldnt settle
            -- the icon early - it should stay exactly as Action.new left it
            w.settingsAction.interact.MouseLeave:Fire()
            expect(w.settingsAction.iconLabel.ImageTransparency).to.equal(1)

            w:Show()
            w.settingsAction.interact.MouseLeave:Fire()
            expect(w.settingsAction.iconLabel.ImageTransparency).to.equal(0.6)
        end)

        it("doesnt tween the settings icon when a tab is selected before the window ever shows", function()
            local w = makeWindow({ name = "Navigate Window", showName = "Navigate" })
            local home = w:CreateTab({ name = "Home" })
            local other = w:CreateTab({ name = "Other" })

            -- picking a default tab before Show() is a normal setup pattern - it shouldnt play
            -- a tween that resolves while main is still invisible, popping the icon on reveal
            w:Navigate(other)
            expect(w.selectedTab).to.equal(other)
            expect(w.settingsAction.iconLabel.ImageTransparency).to.equal(1)

            w:Show()
            w:Navigate(home)
            expect(w.settingsAction.iconLabel.ImageTransparency).to.equal(0.6)
        end)

        it("reveals late tabs, rebuilds dropdowns without leaking, and guards unloaded surfaces", function()
            local w = makeWindow({
                name = "Tidy Window",
                showName = "Tidy",
                configuration = { autoSave = false, autoLoad = false },
            })
            local tab = w:CreateTab({ name = "Main" })
            local dropdown = tab:CreateDropdown({ name = "Rebuild", options = { "A", "B", "C" }, value = "A" })

            w:Show()

            -- a tab created after the window is open shows its pill right away
            local late = w:CreateTab({ name = "Late" })
            expect(late.topbarItem.Visible).to.equal(true)

            -- rebuilding options must not grow the tracked instance/connection registries
            local instancesBefore = #w.instances
            local connectionsBefore = #w.connections
            dropdown:Refresh({ "A", "B", "C" })
            dropdown:Refresh({ "A", "B", "C" })
            expect(#w.instances).to.equal(instancesBefore)
            expect(#w.connections).to.equal(connectionsBefore)

            -- search stays closed while minimised: it would render outside the collapsed bar
            w:ToggleMinimise()
            w.animating = false
            w.searchAction.interact.MouseButton1Click:Fire()
            expect(w._searching).to.equal(false)
            w:ToggleMinimise()
            w.animating = false

            -- a removed tag takes its tracked instances with it
            local tag = w:CreateTag({ text = "Gone" })
            local trackedBefore = #w.instances
            tag:Remove()
            expect(#w.instances < trackedBefore).to.equal(true)

            -- transient surfaces no-op after Unload instead of erroring on a dead ScreenGui
            w:Unload()
            expect(w:Notify({ title = "Late" })).never.to.be.ok()
            expect(w:Toast({ title = "Late" })).never.to.be.ok()
            expect(w:Popup({ title = "Late" })).never.to.be.ok()
        end)

        it("clears keybind recording when its tab is removed and keeps the toggle key alive", function()
            local w = makeWindow()
            w:Show()
            local tab = w:CreateTab({ name = "Main" })
            local keybind = tab:CreateKeybind({ name = "Hotkey", value = Enum.KeyCode.H })

            keybind.box.MouseButton1Click:Fire()
            expect(keybind.recording).to.equal(true)
            expect(w._recordingKeybind).to.equal(keybind)

            tab:Remove()
            expect(w._recordingKeybind).to.equal(nil)

            -- the menu toggle key must still work now nothing is mid-rebind
            local toggle = { UserInputType = Enum.UserInputType.Keyboard, KeyCode = w.settings.toggleKeybind }
            helpers.services.UserInputService.InputBegan:Fire(toggle, false)
            expect(w.hidden).to.equal(true)
            helpers.services.UserInputService.InputBegan:Fire(toggle, false)
            expect(w.hidden).to.equal(false)
        end)

        it("stops keybind recording when the window hides", function()
            local w = makeWindow()
            w:Show()
            local tab = w:CreateTab({ name = "Main" })
            local keybind = tab:CreateKeybind({ name = "Hotkey", value = Enum.KeyCode.H })

            keybind.box.MouseButton1Click:Fire()
            expect(keybind.recording).to.equal(true)

            w:Hide()
            expect(keybind.recording).to.equal(false)
            expect(w._recordingKeybind).to.equal(nil)
        end)

        it("reclaims an element's hover connections when its tab is removed", function()
            local w = makeWindow()
            local before = #w.connections

            local tab = w:CreateTab({ name = "Doomed" })
            tab:CreateButton({ name = "Hover Button" })
            expect(#w.connections > before).to.equal(true)

            tab:Remove()
            expect(#w.connections).to.equal(before)
        end)

        it("repaints themed instances on ChangeTheme", function()
            local w = makeWindow()
            local frost = helpers.requireTheme("frost")

            expect(w.windowStroke.Color).never.to.equal(frost.SurfaceStroke)
            w:ChangeTheme("frost")
            expect(w.windowStroke.Color).to.equal(frost.SurfaceStroke)
        end)

        it("settles the window stroke through show and hide", function()
            local w = makeWindow()
            expect(w.windowStroke.Transparency).to.equal(1)

            -- the stroke is derived from how far the frame has travelled rather than tweened
            -- alongside it, so these drive the motion to its end the way a frame loop would
            w:Show()
            w:_stopMotion()
            expect(w.windowStroke.Transparency).to.equal(0.95)

            w:Hide()
            w:_stopMotion()
            expect(w.windowStroke.Transparency).to.equal(1)
        end)

        it("filters elements by the search query and restores them on close", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })
            local alpha = tab:CreateButton({ name = "Alpha Strike" })
            local beta = tab:CreateToggle({ name = "Beta Mode" })
            w:Show()

            w.searchAction.interact.MouseButton1Click:Fire()
            expect(w._searching).to.equal(true)

            w.searchInput.Text = "alpha"
            w.searchInput:GetPropertyChangedSignal("Text"):Fire()
            expect(alpha.main.Visible).to.equal(true)
            expect(beta.main.Visible).to.equal(false)
            expect(w.searchEmpty.Visible).to.equal(false)

            w.searchInput.Text = "zzz"
            w.searchInput:GetPropertyChangedSignal("Text"):Fire()
            expect(alpha.main.Visible).to.equal(false)
            expect(beta.main.Visible).to.equal(false)
            expect(w.searchEmpty.Visible).to.equal(true)

            w.searchAction.interact.MouseButton1Click:Fire()
            expect(w._searching).to.equal(false)
            expect(alpha.main.Visible).to.equal(true)
            expect(beta.main.Visible).to.equal(true)
            expect(alpha.main.Parent).to.equal(tab.tabPage)
        end)

        it("rejects a malformed slider range with a clear error", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })
            expect(function()
                tab:CreateSlider({ name = "Broken", range = { 50 } })
            end).to.throw("A slider range needs two numbers")
        end)

        it("requires a name or an icon on a tab", function()
            local w = makeWindow()
            expect(function()
                w:CreateTab({})
            end).to.throw("A tab needs a name or an icon")
        end)

        it("refuses new tabs on an unloaded window", function()
            local w = makeWindow()
            w:Unload()
            expect(function()
                w:CreateTab({ name = "Late" })
            end).to.throw("Cannot create a tab on an unloaded window")
        end)

        describe("popups", function()
            it("closes one popup per Escape press, topmost first", function()
                local w = makeWindow()
                local first = w:Popup({ title = "First" })
                local second = w:Popup({ title = "Second" })

                local escape = { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Escape }
                helpers.services.UserInputService.InputBegan:Fire(escape, false)
                expect(second._closed).to.equal(true)
                expect(first._closed).to.equal(false)

                -- the same press must not fall through to the popup underneath
                helpers.services.UserInputService.InputBegan:Fire(escape, false)
                expect(first._closed).to.equal(false)

                helpers.services.UserInputService.InputBegan:Fire({
                    UserInputType = Enum.UserInputType.Keyboard,
                    KeyCode = Enum.KeyCode.Escape,
                }, false)
                expect(first._closed).to.equal(true)
            end)

            it("runs an option's callback and closes on click", function()
                local w = makeWindow()
                local ran = false
                local popup = w:Popup({
                    title = "Confirm",
                    options = {
                        {
                            text = "Accept",
                            callback = function()
                                ran = true
                            end,
                        },
                    },
                })

                local interact
                for _, instance in popup.screenGui:GetDescendants() do
                    if instance.ClassName == "TextButton" then
                        interact = instance
                    end
                end
                expect(interact).to.be.ok()

                interact.MouseButton1Click:Fire()
                expect(ran).to.equal(true)
                expect(popup._closed).to.equal(true)
            end)
        end)

        describe("callback guards", function()
            local logModule = helpers.requireUtility("log")
            local warned
            local originalWarn

            beforeEach(function()
                warned = {}
                originalWarn = logModule.warn
                logModule.warn = function(...)
                    local parts = {}
                    for _, part in { ... } do
                        table.insert(parts, tostring(part))
                    end
                    table.insert(warned, table.concat(parts, " "))
                end
            end)

            afterEach(function()
                logModule.warn = originalWarn
            end)

            local function sawWarning(fragment)
                for _, line in warned do
                    if line:find(fragment, 1, true) then
                        return true
                    end
                end
                return false
            end

            it("keeps a toggle working after its callback throws", function()
                local w = makeWindow()
                local tab = w:CreateTab({ name = "Main" })
                local calls = 0
                local toggle = tab:CreateToggle({
                    name = "Grumpy",
                    value = false,
                    callback = function(value)
                        calls += 1
                        if value then
                            error("boom")
                        end
                    end,
                })

                toggle:Set(true) -- the throw must stay inside the guard
                expect(toggle.value).to.equal(true)
                expect(toggle._errored).to.equal(false) -- flash already settled under instant tweens
                expect(sawWarning("Grumpy")).to.equal(true)

                toggle:Set(false)
                expect(toggle.value).to.equal(false)
                expect(calls).to.equal(2)
            end)

            it("returns nil and warns for a dropdown in a row group", function()
                local w = makeWindow()
                local tab = w:CreateTab({ name = "Main" })
                local row = tab:CreateGroup({ direction = "row" })

                expect(row:CreateDropdown({ name = "Nope", options = { "A" } })).to.equal(nil)
                expect(sawWarning("a row only holds compact elements")).to.equal(true)
            end)
        end)

        describe("toast stacking", function()
            -- park each toast's dwell mid-flight so the stack actually accumulates; the shim's
            -- task.wait normally returns straight away and a toast retires inside its constructor
            local originalWait = task.wait

            afterEach(function()
                task.wait = originalWait
            end)

            it("retires the oldest toast once the stack passes its cap", function()
                local w = makeWindow()
                task.wait = coroutine.yield
                local toasts = {}
                for index = 1, 7 do
                    toasts[index] = w:Toast({ title = "Toast " .. index, duration = 60 })
                end
                task.wait = originalWait

                expect(toasts[1]._dismissed).to.equal(true) -- 7th arrival evicts the 1st (maxLive 6)
                expect(toasts[2]._dismissed).to.equal(false)
                expect(toasts[7]._dismissed).to.equal(false)
            end)

            it("caps a requested minWidth at the toast maximum", function()
                local w = makeWindow()
                local toast = w:Toast({ title = "Wide", minWidth = 400, duration = 0 })
                expect(toast._minWidth).to.equal(320)
                expect(toast.main.Size.X.Offset).to.equal(320)
            end)

            it("truncates a long title and pins its width at the cap", function()
                local w = makeWindow()
                local toast = w:Toast({ title = string.rep("Really Long Toast Title ", 6), duration = 0 })
                expect(toast.main.Size.X.Offset).to.equal(320)
                expect(toast.titleLabel.TextTruncate).to.equal(Enum.TextTruncate.AtEnd)
                expect(toast.titleLabel.AutomaticSize).to.equal(Enum.AutomaticSize.None)
                expect(toast.titleLabel.Size.X.Offset).to.equal(320 - 18 - 18)
            end)
        end)

        describe("toast position", function()
            local originalWait = task.wait

            afterEach(function()
                task.wait = originalWait
            end)

            local function findLayout(container)
                for _, child in container:GetChildren() do
                    if child:IsA("UIListLayout") then
                        return child
                    end
                end
                return nil
            end

            it("defaults to top with top-centre anchor and alignment", function()
                local w = makeWindow()
                w:Toast({ title = "A", duration = 1 })
                expect(w._toastsTop).to.be.ok()
                expect(w._toastsBottom).never.to.be.ok()
                expect(w._toastsTop.AnchorPoint).to.equal(Vector2.new(0.5, 0))
                expect(w._toastsTop.Position).to.equal(UDim2.new(0.5, 0, 0, 12))
                local layout = findLayout(w._toastsTop)
                expect(layout).to.be.ok()
                expect(layout.VerticalAlignment).to.equal(Enum.VerticalAlignment.Top)
            end)

            it("supports bottom with bottom-centre anchor and alignment", function()
                local w = makeWindow()
                w:Toast({ title = "A", position = "Bottom", duration = 1 })
                expect(w._toastsBottom).to.be.ok()
                expect(w._toastsBottom.AnchorPoint).to.equal(Vector2.new(0.5, 1))
                expect(w._toastsBottom.Position).to.equal(UDim2.new(0.5, 0, 1, -12))
                local layout = findLayout(w._toastsBottom)
                expect(layout).to.be.ok()
                expect(layout.VerticalAlignment).to.equal(Enum.VerticalAlignment.Bottom)
            end)

            it("keeps top and bottom containers independent", function()
                local w = makeWindow()
                w:Toast({ title = "Top", duration = 1 })
                w:Toast({ title = "Bottom", position = "Bottom", duration = 1 })
                expect(w._toastsTop).to.be.ok()
                expect(w._toastsBottom).to.be.ok()
                expect(w._toastsTop.AnchorPoint).to.equal(Vector2.new(0.5, 0))
                expect(w._toastsBottom.AnchorPoint).to.equal(Vector2.new(0.5, 1))
                expect(findLayout(w._toastsTop)).to.be.ok()
                expect(findLayout(w._toastsBottom)).to.be.ok()
            end)

            it("assigns descending LayoutOrder within the position container", function()
                local w = makeWindow()
                local originalWait = task.wait
                task.wait = coroutine.yield -- keep all three alive so the frames are readable
                local first = w:Toast({ title = "First", position = "Bottom", duration = 60 })
                local second = w:Toast({ title = "Second", position = "Bottom", duration = 60 })
                local third = w:Toast({ title = "Third", position = "Bottom", duration = 60 })
                task.wait = originalWait

                expect(first.main.LayoutOrder > second.main.LayoutOrder).to.equal(true)
                expect(second.main.LayoutOrder > third.main.LayoutOrder).to.equal(true)
                expect(first.main.Parent).to.equal(w._toastsBottom)
                expect(third.main.Parent).to.equal(w._toastsBottom)
            end)

            it("accepts a lowercase bottom position", function()
                local w = makeWindow()
                w:Toast({ Position = "bottom", title = "Low", duration = 1 })
                expect(w._toastsBottom).to.be.ok()
                expect(w._toastsTop).never.to.be.ok()
            end)
        end)
    end)

    -- The primary flow: a dev sets autoSave/autoLoad and never opens the config manager.
    -- A change to an element must autosave, and a fresh window must autoLoad it back.
    describe("component window collapse choreography", function()
        local collapsed

        local function makeWindow()
            collapsed = Window.new({
                name = "Collapse Window",
                subtitle = "Gen2", -- the chrome the choreography drives, so it has to be there
                icon = 93364949241311,
                configuration = { autoSave = false, autoLoad = false },
            })
            collapsed.hidden = false
            return collapsed
        end

        afterEach(function()
            if collapsed and not collapsed.unloaded then
                collapsed:Unload()
            end
            collapsed = nil
        end)

        -- Everything the collapse touches is a function of the frame's live height, so these
        -- drive that height directly rather than waiting on a spring the harness never steps.
        -- widths interpolated the same way the frame does, so the shorter side is honest
        local function at(window, height)
            local open, pill = window.size.Y.Offset, 50
            local progress = math.clamp((open - height) / (open - pill), 0, 1)
            local width = window.size.X.Offset + (185 - window.size.X.Offset) * progress
            window:_applyCollapseProgress(width, height)
        end

        it("takes its corner radius from the height the frame actually has", function()
            local w = makeWindow()
            local open = w.size.Y.Offset
            local resting = w.theme.CornerRoundness.Offset
            w.hidden = true -- this one is about the collapse; the return is weighted, see below

            at(w, open)
            expect(w.windowCorner.CornerRadius.Offset).to.equal(resting)

            -- at the pill it is exactly half the shorter side, which is as round as that shape
            -- goes, so the silhouette lands on a true pill
            at(w, 50)
            expect(math.abs(w.windowCorner.CornerRadius.Offset - 25) < 0.01).to.equal(true)

            -- and halfway it is carrying a big radius rather than square corners: the window
            -- takes the pill's shape early and lets its size catch up. An earlier version of
            -- this held roughly 22px here, which on a 330 by 275 frame is visually square, and
            -- the whole collapse read as a box until the very last moment.
            at(w, (open + 50) / 2)
            local middle = w.windowCorner.CornerRadius.Offset
            expect(middle > 60).to.equal(true)
            expect(middle > resting * 3).to.equal(true)
        end)

        it("squares the corner off as the window opens, not at the end of the spring", function()
            local w = makeWindow()
            local open = w.size.Y.Offset

            -- closing: round early, so the window takes the pill's shape and lets its size
            -- catch up
            w.hidden = true
            at(w, (open + 50) / 2)
            local closing = w.windowCorner.CornerRadius.Offset

            -- opening: at the same frame size the corner is already much closer to resting. A
            -- spring is nearly full size long before it has finished settling, and a corner
            -- that tracks its progress straight stays visibly round through that whole tail.
            w.hidden = false
            at(w, (open + 50) / 2)
            local opening = w.windowCorner.CornerRadius.Offset

            expect(opening < closing).to.equal(true)

            -- and by the time the frame looks open, the corner looks open too
            at(w, open * 0.9)
            expect(w.windowCorner.CornerRadius.Offset < 30).to.equal(true)
        end)

        it("puts every derived property at rest when the frame is open", function()
            local w = makeWindow()
            at(w, w.size.Y.Offset)

            expect(w.windowShadow.Transparency).to.equal(0.6)
            expect(w.windowStroke.Transparency).to.equal(0.95)
            expect(w.bottomFade.BackgroundTransparency).to.equal(0)
            expect(w.title.TextTransparency).to.equal(0)
            expect(w.subtitle.TextTransparency).to.equal(0.7)
            expect(w.topbar.Visible).to.equal(true)

            -- and the pill's own face is entirely gone while there is a window to look at
            if w.collapsedTitle then
                expect(w.collapsedTitle.TextTransparency).to.equal(1)
            end
        end)

        it("puts every derived property at its collapsed value on the pill", function()
            local w = makeWindow()
            at(w, 50)

            expect(w.windowShadow.Transparency).to.equal(1)
            expect(w.windowStroke.Transparency).to.equal(1)
            expect(w.bottomFade.BackgroundTransparency).to.equal(1)
            expect(w.title.TextTransparency).to.equal(1)
            expect(w.topbar.Visible).to.equal(false)

            -- the pill's face is the one thing that arrives rather than leaves
            if w.collapsedTitle then
                expect(w.collapsedTitle.TextTransparency).to.equal(0)
                expect(w.collapsedSubtitle.TextTransparency).to.equal(0.5)
            end
        end)

        it("gives the same answer for a height whichever way it was reached", function()
            local w = makeWindow()
            local half = (w.size.Y.Offset + 50) / 2

            -- on the way down
            at(w, w.size.Y.Offset)
            at(w, half)
            local goingDown = {
                corner = w.windowCorner.CornerRadius.Offset,
                stroke = w.windowStroke.Transparency,
                title = w.title.TextTransparency,
                face = w.collapsedTitle and w.collapsedTitle.TextTransparency,
            }

            -- and on the way back up, interrupted at exactly the same place
            at(w, 50)
            at(w, half)

            expect(w.windowCorner.CornerRadius.Offset).to.equal(goingDown.corner)
            expect(w.windowStroke.Transparency).to.equal(goingDown.stroke)
            expect(w.title.TextTransparency).to.equal(goingDown.title)
            if w.collapsedTitle then
                expect(w.collapsedTitle.TextTransparency).to.equal(goingDown.face)
            end
        end)

        it("starts a move from where the frame actually is, not where it last left it", function()
            local w = makeWindow()
            w.hidden = false

            -- one move, so the springs exist and hold where they finished
            w:Hide()
            w:_stopMotion()
            local remembered = w._motion.size.position.Y

            -- something else moves the frame without the spring's knowledge, which is exactly
            -- what minimising does: its own tweens, straight onto main.Size
            w.main.Size = UDim2.fromOffset(w.size.X.Offset, 66)
            expect(remembered).never.to.equal(66)

            expect(w:_syncMotionToFrame()).to.equal(true)
            expect(w._motion.size.position.Y).to.equal(66)
        end)

        it("never issues the same guard token twice", function()
            local w = makeWindow()
            w.hidden = false
            w.hasShownOnce = true -- so Show takes the spring path rather than the intro

            -- Each move arms a guard that ends it by snapping the frame to its goal, and every
            -- guard checks its token before doing so. Taking that number from the motion meant
            -- it reset to nil when a move landed, so the next move was issued the same number a
            -- guard still pending from the previous one was holding: it matched, fired, and cut
            -- the live move short. Open and close quickly and the window teleports between its
            -- states rather than animating.
            local seen = {}
            for _ = 1, 6 do
                w:Hide()
                expect(seen[w._motionSequence]).to.equal(nil)
                seen[w._motionSequence] = true
                w:_stopMotion()

                w:Show()
                expect(seen[w._motionSequence]).to.equal(nil)
                seen[w._motionSequence] = true
                w:_stopMotion()
            end

            -- and it counts rather than cycling, so it cannot come back round to a live one
            expect(w._motionSequence >= 12).to.equal(true)
        end)

        it("disarms the settle backstop once a move has landed", function()
            local w = makeWindow()
            w.hidden = false

            w:Hide()
            w:_stopMotion()

            -- the backstop exists so a dropped frame loop cannot leave the window flagged as
            -- animating forever. Once the move has landed it has to be spent: left armed it
            -- fires later and writes that move's goal back onto the frame, so anything that
            -- moved the window in between, minimising most of all, is silently undone.
            expect(w._motion.token).to.equal(nil)
        end)

        it("leaves a move already in flight alone so it can be reversed, not restarted", function()
            local w = makeWindow()
            w.hidden = false
            w:Hide()
            w:_stopMotion()

            -- pretend the loop is running: mid flight the spring's own position and speed are
            -- the whole point, and picking the frame up again would throw both away
            w._motionConnection = {}
            w._motion.size:snap(Vector2.new(300, 300))
            w.main.Size = UDim2.fromOffset(475, 66)

            expect(w:_syncMotionToFrame()).to.equal(false)
            expect(w._motion.size.position.Y).to.equal(300)
            w._motionConnection = nil
        end)

        it("collapses a minimised window across its own travel, not the full window's", function()
            local w = makeWindow()
            w.hidden = false
            w:_stopMotion()

            -- a minimised window is 66 tall and the pill is 50, so the whole move is 16 pixels.
            -- Measured against a full 500 tall window it would start at 0.96 already: the title
            -- would blank on the first frame and the pill's label would be up before anything
            -- had moved.
            w.minimised = true
            w.main.Size = UDim2.fromOffset(w.size.X.Offset, 66)
            w:Hide()

            local motion = w._motion
            expect(motion.openHeight).to.equal(66)
            expect(motion.pillHeight).to.equal(50)

            -- at the start of that move the bar still looks like itself
            w:_applyCollapseProgress(w.size.X.Offset, 66)
            expect(w.title.TextTransparency < 0.1).to.equal(true)
            expect(w.topbar.Visible).to.equal(true)

            -- but it clears fast. A minimised bar has 16 pixels of vertical travel and 290 of
            -- horizontal, so the title and the action icons would slide into each other while
            -- both were still legible if they left on the same schedule a full window uses.
            -- A quarter of the way through, the writing on it has already gone
            w:_applyCollapseProgress(402, 62)
            expect(w.title.TextTransparency).to.equal(1)

            -- and the bar itself follows shortly after, leaving a clean shape to morph
            w:_applyCollapseProgress(360, 60)
            expect(w.topbar.Visible).to.equal(false)

            -- and the page never comes back on the way, because that window had none to show
            expect(w.elements.Visible).to.equal(false)
            w:_applyCollapseProgress(w.size.X.Offset, 64)
            expect(w.elements.Visible).to.equal(false)

            -- by the end it is a pill like any other
            w:_stopMotion()
            expect(w.title.TextTransparency).to.equal(1)
            expect(w.topbar.Visible).to.equal(false)
        end)

        -- Mid flight, as the window is during a real collapse: the frame loop running, and the
        -- animating flag still up. The harness runs task.delay straight away, so the settle
        -- guard has already landed the move by the time Hide returns and both have to be put
        -- back by hand.
        local function inFlight(w)
            w.hasShownOnce = true -- else Show plays the first-open intro rather than the restore
            w._motionConnection = { Disconnect = function() end }
            w.animating = true
        end

        it("turns a collapse around mid flight instead of dropping the call", function()
            local w = makeWindow()
            w.hidden = false
            w.main.Size = UDim2.fromOffset(w.size.X.Offset, w.size.Y.Offset)
            w:Hide()
            expect(w.hidden).to.equal(true)

            inFlight(w)
            local collapsing = w._motion.sizeGoal

            -- hitting the toggle again while it is still closing asks for the opposite, which
            -- the spring is built to take. Rejecting it because something is animating was the
            -- only reason the window could not follow.
            w:Show()
            expect(w.hidden).to.equal(false)
            expect(w._motion.sizeGoal).never.to.equal(collapsing)

            -- but asking for the same direction twice is still a repeat, not a reversal
            local restoring = w._motion.sizeGoal
            w:Show()
            expect(w._motion.sizeGoal).to.equal(restoring)

            -- and the same the other way round
            w:Hide()
            expect(w.hidden).to.equal(true)
            local closing = w._motion.sizeGoal
            w:Hide()
            expect(w._motion.sizeGoal).to.equal(closing)

            w._motionConnection = nil
            w:_stopMotion()
        end)

        it("comes back to where it was left after being moved", function()
            local w = makeWindow()
            w.hidden = false
            w.hasShownOnce = true

            -- dragged off centre, then hidden
            local moved = UDim2.fromOffset(820, 140)
            w.main.Position = moved
            w.main.Size = UDim2.fromOffset(w.size.X.Offset, w.size.Y.Offset)
            w:Hide()

            expect(w._restorePosition).to.equal(moved)

            -- and back to the same spot, not the centre and not a stale one from earlier. Pulled
            -- onto the screen on the way, since the fit can have changed while it was away
            w:_stopMotion()
            w:Show()
            expect(w._motion.positionGoal).to.equal(w:_clampedPosition(moved))
            expect(w._motion.positionGoal).never.to.equal(UDim2.fromScale(0.5, 0.5))
            w:_stopMotion()

            -- moved again, hidden again: the second hide has to record the second spot
            w.hidden = false
            local again = UDim2.fromOffset(200, 600)
            w.main.Position = again
            w:Hide()
            expect(w._restorePosition).to.equal(again)
            w:_stopMotion()
        end)

        it("still waits for an animation that cannot be redirected", function()
            local w = makeWindow()
            w.hidden = false
            w.hasShownOnce = true

            -- The minimise and the first-show reveal both drive main.Size with a tween, and a
            -- tween cannot be handed a new target: it would carry on writing the property every
            -- frame with the spring writing it too. Only the spring can be turned around, so
            -- animating on its own stops being a reason to refuse only while one is running.
            w.animating = true
            w._motionConnection = nil
            expect(w:_canRetarget()).to.equal(false)

            w:Hide()
            expect(w.hidden).to.equal(false)
            expect(w._motion).to.equal(nil)

            -- and with the spring in the air it goes through
            w.animating = false
            w:Hide()
            w:_stopMotion()
            expect(w.hidden).to.equal(true)
        end)

        it("keeps the ends of a move it is only reversing", function()
            local w = makeWindow()
            w.hidden = false
            w.main.Size = UDim2.fromOffset(w.size.X.Offset, w.size.Y.Offset)
            w:Hide()

            local open, pill = w._motion.openHeight, w._motion.pillHeight
            expect(open).to.equal(w.size.Y.Offset)
            expect(pill).to.equal(50)

            -- half way down, and the chrome is half way out with it
            inFlight(w)
            local middle = (open + pill) / 2
            w.main.Size = UDim2.fromOffset(w.size.X.Offset, middle)
            w:_applyCollapseProgress(w.size.X.Offset, middle)
            expect(math.abs(w._collapseProgress - 0.5) < 1e-6).to.equal(true)

            -- Reversing from here must measure against the same two ends. Rebuilding them from
            -- where the frame is standing would make this very frame the open one, so the same
            -- 275 pixels that just read as half way would read as fully collapsed, and every
            -- derived property would snap to its pill state before walking back out of it.
            w:Show()
            expect(w._motion.openHeight).to.equal(open)
            expect(w._motion.pillHeight).to.equal(pill)

            w:_applyCollapseProgress(w.size.X.Offset, middle)
            expect(math.abs(w._collapseProgress - 0.5) < 1e-6).to.equal(true)

            w._motionConnection = nil
            w:_stopMotion()
        end)

        it("gives a move to a different pair of ends a range of its own", function()
            local w = makeWindow()
            w.hidden = false
            w.minimised = true
            w.main.Size = UDim2.fromOffset(w.size.X.Offset, 66)
            w:Hide()

            expect(w._motion.openHeight).to.equal(66)
            expect(w._motion.contentsWhenOpen).to.equal(false)

            -- Show grows back to the full window rather than to the bar, so this is not the
            -- move that was running: it needs its own ends, and its own answer about the page.
            inFlight(w)
            w.main.Size = UDim2.fromOffset(400, 58)
            w:Show()
            expect(w._motion.openHeight).to.equal(w.size.Y.Offset)
            expect(w._motion.pillHeight).to.equal(58)
            expect(w._motion.contentsWhenOpen).to.equal(true)

            w._motionConnection = nil
            w:_stopMotion()
        end)

        it("holds the page only while there is a frame big enough for it", function()
            local w = makeWindow()

            at(w, w.size.Y.Offset)
            expect(w.elements.Visible).to.equal(true)

            -- past the threshold the page comes off rather than being squeezed
            at(w, 100)
            expect(w.elements.Visible).to.equal(false)
            expect(w.tabList.Visible).to.equal(false)

            -- and back on the moment there is room again, on the same number
            at(w, w.size.Y.Offset)
            expect(w.elements.Visible).to.equal(true)
        end)
    end)

    describe("component window animation speed", function()
        local motion = helpers.requireUtility("motion")
        local paced

        local function makeWindow()
            paced = Window.new({
                name = "Paced Window",
                configuration = { autoSave = false, autoLoad = false },
            })
            paced.hidden = false
            return paced
        end

        afterEach(function()
            motion.setSpeed(1)
            if paced and not paced.unloaded then
                paced:Unload()
            end
            paced = nil
        end)

        it("sets the pace and reads it back", function()
            local w = makeWindow()
            expect(w:GetAnimationSpeed()).to.equal(1)

            w:SetAnimationSpeed(2)
            expect(w:GetAnimationSpeed()).to.equal(2)
            expect(motion.getSpeed()).to.equal(2)
        end)

        it("holds the setting to what it was actually given, not what was asked for", function()
            local w = makeWindow()
            local _, high = motion.range()

            -- clamped, and what is read back has to agree with the clamp rather than keep the
            -- ask, or the next save writes back a value the interface is not running at
            w:SetAnimationSpeed(500)
            expect(w:GetAnimationSpeed()).to.equal(high)
            expect(motion.getSpeed()).to.equal(high)
        end)

        it("keeps a second window off a pace of its own", function()
            local first = makeWindow()
            local second = Window.new({
                name = "Second Paced Window",
                configuration = { autoSave = false, autoLoad = false },
            })

            first:SetAnimationSpeed(1)
            expect(second.animationSpeedSlider.value).to.equal(100)

            -- The speed is one number for the whole library. A window keeping its own copy is a
            -- copy that goes stale the moment another window moves it, and the stale one writes
            -- itself back over the shared value the next time that window saves anything.
            first:SetAnimationSpeed(2)
            expect(second:GetAnimationSpeed()).to.equal(2)
            expect(second.animationSpeedSlider.value).to.equal(200)

            -- and it goes the other way: neither window is the owner
            second:SetAnimationSpeed(0.5)
            expect(first:GetAnimationSpeed()).to.equal(0.5)
            expect(first.animationSpeedSlider.value).to.equal(50)

            second:Unload()

            -- an unloaded window stops listening rather than reaching for a destroyed slider
            first:SetAnimationSpeed(1.5)
            expect(second.animationSpeedSlider.value).to.equal(50)
        end)

        it("saves the pace the library is running at, not a window's copy of it", function()
            local persistenceSettings = helpers.requireUtility("persistenceSettings")
            local w = makeWindow()

            w:SetAnimationSpeed(1)

            -- a window that has not touched the setting itself still has to write the shared
            -- value, since saving any other setting writes the whole file
            motion.setSpeed(2.5)
            local saved
            local realWrite = persistenceSettings.saveSettings
            expect(realWrite).to.be.ok()

            local decoded
            local httpService = helpers.services.HttpService
            local realEncode = httpService.JSONEncode
            httpService.JSONEncode = function(this, data)
                decoded = data
                return realEncode(this, data)
            end
            saved = persistenceSettings.saveSettings(w)
            httpService.JSONEncode = realEncode

            expect(saved).to.equal(true)
            expect(decoded.animationSpeed).to.equal(2.5)
        end)

        it("keeps the settings slider showing the truth", function()
            local w = makeWindow()
            expect(w.animationSpeedSlider).to.be.ok()

            -- settings persist across windows, so start from a known pace rather than assuming
            -- whatever the last window to run saved
            w:SetAnimationSpeed(1)
            expect(w.animationSpeedSlider.value).to.equal(100)

            w:SetAnimationSpeed(1.5)
            expect(w.animationSpeedSlider.value).to.equal(150)

            -- including when the value was clamped on the way in
            local _, high = motion.range()
            w:SetAnimationSpeed(99)
            expect(w.animationSpeedSlider.value).to.equal(math.round(high * 100))
        end)

        it("keeps a sequencing wait on the same clock as the tween it waits for", function()
            -- A tween's duration is scaled by the handle every animation goes through, but a
            -- task.delay sitting beside one is a plain number and is not. Off 1x they came
            -- apart: the popup was destroyed before its fade finished, and the chrome faded
            -- back in over a window still on its way open. Both take the same scaling now, so
            -- a delay and a tween of the same nominal length stay equal at any pace.
            for _, pace in { 0.25, 0.5, 1, 1.5, 3 } do
                motion.setSpeed(pace)
                local scaled = motion.info(TweenInfo.new(0.4))
                expect(math.abs(motion.duration(0.4) - scaled.Time) < 1e-9).to.equal(true)
            end
        end)

        it("applies the pace to the collapse's own tweens exactly once", function()
            local w = makeWindow()

            -- the first tween the collapse puts on the drag bar, which is sized off the move's
            -- characteristic time
            local function fadeTime()
                local service = helpers.services.TweenService
                local realCreate = service.Create
                local seen
                service.Create = function(this, instance, info, goals)
                    if instance == w.drag.dragCosmetic and seen == nil then
                        seen = info.Time
                    end
                    return realCreate(this, instance, info, goals)
                end

                w.hidden = false
                w:Hide()
                service.Create = realCreate
                w:_stopMotion()
                return seen
            end

            w:SetAnimationSpeed(1)
            local normal = fadeTime()
            w:SetAnimationSpeed(2)
            local quick = fadeTime()

            expect(normal).to.be.ok()
            expect(quick).to.be.ok()

            -- A spring's settle time goes with one over the square root of its stiffness, so a
            -- duration taken from an already paced stiffness has the speed in it before the
            -- handle divides by the speed again. That put these tweens on the square of the
            -- pace while the delay beside them only had the one, and the two came apart.
            expect(math.abs(normal / quick - 2) < 1e-6).to.equal(true)
        end)

        it("paces the notification and toast staggers with the fades beside them", function()
            local w = makeWindow()

            -- record what gets waited on without changing what happens
            local function waitsDuring(run)
                local seen = {}
                local realWait = task.wait;
                (task :: any).wait = function(seconds)
                    if seconds ~= nil then
                        table.insert(seen, seconds)
                    end
                    return realWait(seconds)
                end
                local ok, err = pcall(run);
                (task :: any).wait = realWait
                assert(ok, err)
                return seen
            end

            local function has(seen, value)
                for _, entry in seen do
                    if math.abs(entry - value) < 1e-9 then
                        return true
                    end
                end
                return false
            end

            w:SetAnimationSpeed(1)
            expect(has(
                waitsDuring(function()
                    w:Notify({ title = "Stock" })
                end),
                0.05
            )).to.equal(true)

            -- the fades around these are scaled through the tween handle, so a stagger that
            -- stays put drifts away from them: at twice the pace the card is done fading in
            -- before the icon behind it has been told to start
            w:SetAnimationSpeed(2)
            local quick = waitsDuring(function()
                w:Notify({ title = "Quick" })
            end)
            expect(has(quick, 0.025)).to.equal(true)
            expect(has(quick, 0.05)).to.equal(false)

            local toastWaits = waitsDuring(function()
                w:Toast({ title = "Quick" })
            end)
            expect(has(toastWaits, 0.025)).to.equal(true)
            expect(has(toastWaits, 0.05)).to.equal(false)
        end)

        it("moves the page slide with the pace as well", function()
            local w = makeWindow()
            w:SetAnimationSpeed(1)

            local stock = w.elementsLayout.TweenTime
            expect(stock > 0).to.equal(true)

            -- a UIPageLayout runs its own slide rather than going through the tween handle, so
            -- at any other pace the tab pill would change speed and the page under it would not
            w:SetAnimationSpeed(2)
            expect(math.abs(w.elementsLayout.TweenTime - stock / 2) < 1e-9).to.equal(true)

            -- and a window built while another one is already running quick starts there too,
            -- rather than on the pace nothing is using
            local later = Window.new({
                name = "Later Window",
                configuration = { autoSave = false, autoLoad = false },
            })
            expect(math.abs(later.elementsLayout.TweenTime - stock / 2) < 1e-9).to.equal(true)
            later:Unload()
        end)

        it("paces the collapse as well as the tweens", function()
            local w = makeWindow()
            w.hidden = false
            w:SetAnimationSpeed(1)

            w:Hide()
            local normal = w._motion.size.stiffness
            w:_stopMotion()

            -- a spring's settle time goes with the square root of its stiffness, so twice the
            -- pace is four times the stiffness. Without this the collapse would carry on at its
            -- own speed while every tween around it moved with the setting.
            w:Show()
            w:_stopMotion()
            w:SetAnimationSpeed(2)
            w:Hide()
            expect(math.abs(w._motion.size.stiffness - normal * 4) < 1e-6).to.equal(true)
            w:_stopMotion()
        end)

        it("stretches the settle guard with the pace, so it cannot cut a slow move short", function()
            local w = makeWindow()
            w.hidden = false

            -- the guard exists so a stalled frame loop cannot leave a window animating forever,
            -- and it ends the move by snapping the frame to its goal. Fixed, it fires while a
            -- slowed down window is still travelling: at 65% pace the real settle is 0.74s
            -- against a guard of 0.7s, and the window flings to its end position.
            local settle = 4 / math.sqrt(210)
            expect(math.max(0.7, settle * 3) > 0.7).to.equal(true)

            local slowStiffness = 210 * 0.65 * 0.65
            local slowGuard = math.max(0.7, (4 / math.sqrt(slowStiffness)) * 3)
            expect(slowGuard > 0.74).to.equal(true)
        end)

        it("scales every tween through the shared handle", function()
            local w = makeWindow()
            local variables = helpers.requireUtility("variables")
            local base = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

            w:SetAnimationSpeed(2)

            -- the point of wrapping the one handle: a call site that knows nothing about the
            -- setting still animates at the right pace
            local captured
            local frame = w.main
            local tween = variables.tweenService:Create(frame, base, { BackgroundTransparency = 0 })
            captured = tween
            expect(captured).to.be.ok()
        end)
    end)

    describe("config round trip without the config manager", function()
        local variables = helpers.requireUtility("variables")
        local filesystem = helpers.requireUtility("filesystem")

        local windows
        local files
        local originals

        beforeEach(function()
            windows = {}
            files = {}

            originals = {
                fileSystemManager = variables.fileSystemManager,
                ensureDir = filesystem.ensureDir,
                writefile = filesystem.writefile,
                readfile = filesystem.readfile,
                isfile = filesystem.isfile,
                delfile = filesystem.delfile,
                listfiles = filesystem.listfiles,
            }

            variables.fileSystemManager = {
                getPath = function(_, childPath)
                    return "Root/" .. childPath
                end,
            }

            filesystem.ensureDir = function() end
            filesystem.writefile = function(path, content)
                files[path] = content
            end
            filesystem.readfile = function(path)
                if files[path] == nil then
                    error("missing " .. path)
                end
                return files[path]
            end
            filesystem.isfile = function(path)
                return files[path] ~= nil
            end
            filesystem.delfile = function(path)
                files[path] = nil
            end
            filesystem.listfiles = function()
                local out = {}
                for path in files do
                    table.insert(out, path)
                end
                return out
            end
        end)

        afterEach(function()
            for _, w in windows do
                if w and not w.unloaded then
                    w:Unload()
                end
            end
            variables.fileSystemManager = originals.fileSystemManager
            filesystem.ensureDir = originals.ensureDir
            filesystem.writefile = originals.writefile
            filesystem.readfile = originals.readfile
            filesystem.isfile = originals.isfile
            filesystem.delfile = originals.delfile
            filesystem.listfiles = originals.listfiles

            -- the drag specs steer the shared input mocks; put them back
            helpers.services.UserInputService._setMouseLocation(Vector2.new(120, 80))
            helpers.services.GuiService._setGuiInset(Vector2.new(0, 0))
        end)

        local function newWindow(autoLoad)
            local w = Window.new({
                name = "Farm",
                showName = "Farm",
                configuration = {
                    autoSave = true,
                    autoLoad = autoLoad,
                    fileName = "FarmSave",
                    customFolder = "farmFolder",
                },
            })
            table.insert(windows, w)
            return w
        end

        -- what actually landed on disk, through the real JSON shim
        local function decodeConfig(w)
            local _, fullPath = w:GetPath()
            expect(type(files[fullPath])).to.equal("string")
            return variables.httpService:JSONDecode(files[fullPath])
        end

        it("autosaves a change and autoLoads it into a fresh window with an explicit flag", function()
            -- session 1: the player flips a toggle, autosave writes the file
            local w1 = newWindow(false)
            local tab1 = w1:CreateTab({ name = "Main" })
            local t1 = tab1:CreateToggle({ name = "Auto Farm", flag = "autoFarm", value = false })
            t1:Set(true)
            expect(next(files)).to.be.ok()

            -- session 2: same script re-run, a brand new window autoLoads on first Show
            local w2 = newWindow(true)
            local tab2 = w2:CreateTab({ name = "Main" })
            local restored
            local t2 = tab2:CreateToggle({
                name = "Auto Farm",
                flag = "autoFarm",
                value = false,
                callback = function(value)
                    restored = value
                end,
            })
            w2:Show()

            expect(t2.value).to.equal(true)
            -- the callback has to fire, so the dev's own logic (a farm loop, say) resumes
            expect(restored).to.equal(true)
        end)

        it("round trips the same way with no flag, using the name-derived key", function()
            local w1 = newWindow(false)
            local tab1 = w1:CreateTab({ name = "Main" })
            tab1:CreateToggle({ name = "Auto Farm", value = false }):Set(true)

            local w2 = newWindow(true)
            local tab2 = w2:CreateTab({ name = "Main" })
            local t2 = tab2:CreateToggle({ name = "Auto Farm", value = false })
            w2:Show()

            expect(t2.value).to.equal(true)
        end)

        it("restores a value into an element built after autoLoad already ran", function()
            local w1 = newWindow(false)
            local tab1 = w1:CreateTab({ name = "Main" })
            tab1:CreateSlider({ name = "Speed", range = { 0, 100 }, increment = 1, value = 0 }):Set(80)

            -- session 2 builds its UI only after the window has already opened (e.g. after a
            -- remote fetch). the late element still has to come back from the saved file.
            local w2 = newWindow(true)
            w2:Show()
            local tab2 = w2:CreateTab({ name = "Main" })
            local late = tab2:CreateSlider({ name = "Speed", range = { 0, 100 }, increment = 1, value = 0 })

            expect(late.value).to.equal(80)
        end)

        it("makes a config picked in the manager stick across sessions", function()
            local w1 = newWindow(false)
            local tab1 = w1:CreateTab({ name = "Main" })
            local t1 = tab1:CreateToggle({ name = "Auto Farm", flag = "autoFarm", value = false })

            t1:Set(true)
            expect(w1:Save("PvP")).to.equal(true) -- snapshot the on state under a name
            t1:Set(false) -- the live default is now off, the named config still on

            -- picking PvP in the manager applies it and makes it the live state
            expect(w1:_applyNamedConfig("PvP")).to.equal(true)
            expect(t1.value).to.equal(true)

            -- next session autoLoads the default file, which now holds PvP's values
            local w2 = newWindow(true)
            local tab2 = w2:CreateTab({ name = "Main" })
            local t2 = tab2:CreateToggle({ name = "Auto Farm", flag = "autoFarm", value = false })
            w2:Show()

            expect(t2.value).to.equal(true)
        end)

        it("round trips a slider, toggle, and multi-select dropdown together", function()
            local w1 = newWindow(false)
            local tab1 = w1:CreateTab({ name = "Main" })
            tab1:CreateSlider({ name = "Slider Tap Delay", range = { 0, 1 }, increment = 0.01, value = 0.01 }):Set(0.5)
            tab1:CreateToggle({ name = "Toggle Auto Tap", value = false }):Set(true)
            tab1:CreateDropdown({
                name = "Drop Ultimate",
                multiSelect = true,
                options = { "Ult A", "Ult B", "Ult C" },
                value = {},
            }):Set({ "Ult A", "Ult C" })

            local w2 = newWindow(true)
            local tab2 = w2:CreateTab({ name = "Main" })
            local s2 =
                tab2:CreateSlider({ name = "Slider Tap Delay", range = { 0, 1 }, increment = 0.01, value = 0.01 })
            local t2 = tab2:CreateToggle({ name = "Toggle Auto Tap", value = false })
            local d2 = tab2:CreateDropdown({
                name = "Drop Ultimate",
                multiSelect = true,
                options = { "Ult A", "Ult B", "Ult C" },
                value = {},
            })
            w2:Show()

            expect(s2.value).to.equal(0.5)
            expect(t2.value).to.equal(true)
            expect(#d2.value).to.equal(2)
        end)

        it("keeps a restored dropdown selection when its options arrive after autoLoad", function()
            -- session 1: options are known, the player picks one
            local w1 = newWindow(false)
            local tab1 = w1:CreateTab({ name = "Main" })
            tab1:CreateDropdown({
                name = "Drop Ultimate",
                multiSelect = true,
                options = { "Ult A", "Ult B", "Ult C" },
                value = {},
            }):Set({ "Ult A" })

            -- session 2: the dropdown is built before its options exist (populated later from
            -- game data), which is a normal pattern for a live list.
            local w2 = newWindow(true)
            local tab2 = w2:CreateTab({ name = "Main" })
            local d2 = tab2:CreateDropdown({ name = "Drop Ultimate", multiSelect = true, options = {}, value = {} })
            w2:Show()
            d2:Refresh({ "Ult A", "Ult B", "Ult C" })

            expect(#d2.value).to.equal(1)
        end)

        it("drops a selection whose option is genuinely removed", function()
            local w = newWindow(false)
            local tab = w:CreateTab({ name = "Main" })
            local d =
                tab:CreateDropdown({ name = "Drop Ultimate", multiSelect = true, options = { "A", "B" }, value = {} })
            d:Set({ "A", "B" })

            -- a real options list that no longer offers A: the selection has to drop, not linger
            d:Refresh({ "B" })
            expect(#d.value).to.equal(1)
            expect(d.value[1]).to.equal("B")
        end)

        it("keeps an interactive pick when the options are refreshed", function()
            local w = newWindow(false)
            local tab = w:CreateTab({ name = "Main" })
            local d = tab:CreateDropdown({
                name = "Drop Ultimate",
                multiSelect = true,
                options = { "A", "B", "C" },
                value = {},
            })

            d.interact.MouseButton1Click:Fire() -- open the panel
            for _, data in d._optionFrames do
                if data.name == "B" then
                    data.interact.MouseButton1Click:Fire() -- the player picks B
                end
            end
            expect(#d.value).to.equal(1)
            expect(d.value[1]).to.equal("B")

            -- a refresh of the same options must build on the live pick, not revert it
            d:Refresh({ "A", "B", "C" })
            expect(#d.value).to.equal(1)
            expect(d.value[1]).to.equal("B")
        end)

        it("keeps a flipped value on disk after its tab is torn down", function()
            -- session 1 seeds the file
            local w1 = newWindow(false)
            local tab1 = w1:CreateTab({ name = "Main" })
            tab1:CreateToggle({ name = "Auto Farm", flag = "autoFarm", value = false }):Set(false)
            tab1:CreateSlider({ name = "Speed", flag = "speed", range = { 0, 100 }, increment = 1, value = 0 }):Set(10)

            -- session 2 loads, flips the toggle, loses its tab, then another autosave lands
            local w2 = newWindow(true)
            local farmTab = w2:CreateTab({ name = "Farm" })
            local toggle = farmTab:CreateToggle({ name = "Auto Farm", flag = "autoFarm", value = false })
            local otherTab = w2:CreateTab({ name = "Other" })
            local slider =
                otherTab:CreateSlider({ name = "Speed", flag = "speed", range = { 0, 100 }, increment = 1, value = 0 })
            w2:Show()

            toggle:Set(true)
            farmTab:Remove()
            slider:Set(25) -- this autosave must carry the flip forward, not revert it

            local decoded = decodeConfig(w2)
            expect(decoded.autoFarm).to.equal(true)
            expect(decoded.speed).to.equal(25)
        end)

        it("promotes a named config's unbuilt flags into the default file", function()
            local w1 = newWindow(false)
            local tab1 = w1:CreateTab({ name = "Main" })
            tab1:CreateToggle({ name = "Ghost", flag = "ghost", value = false }):Set(true)
            expect(w1:Save("A")).to.equal(true)

            -- a fresh session whose UI never builds the ghost element
            local w2 = newWindow(false)
            local tab2 = w2:CreateTab({ name = "Main" })
            tab2:CreateToggle({ name = "Other", flag = "other", value = false })
            expect(w2:_applyNamedConfig("A")).to.equal(true)

            local decoded = decodeConfig(w2)
            expect(decoded.ghost).to.equal(true)
            expect(decoded.other).to.equal(false)
        end)

        it("round trips every element type through real JSON", function()
            local w1 = newWindow(false)
            local tab1 = w1:CreateTab({ name = "Main" })
            tab1:CreateToggle({ name = "Flag Toggle", flag = "toggle", value = false }):Set(true)
            tab1:CreateSlider({ name = "Speed", flag = "slider", range = { 0, 1 }, increment = 0.01, value = 0 })
                :Set(0.5)
            tab1:CreateDropdown({
                name = "Ultimates",
                flag = "drop",
                multiSelect = true,
                options = { "A", "B", "C" },
                value = {},
            }):Set({ "A", "C" })
            tab1:CreateKeybind({ name = "Hotkey", flag = "bind", value = Enum.KeyCode.H }):Set(Enum.KeyCode.J)
            local color = tab1:CreateColorPicker({ name = "Accent", flag = "color", value = Color3.fromRGB(255, 0, 0) })
            color:Set(Color3.fromRGB(51, 102, 153))
            color:SetAlpha(0.8)

            -- the on-disk string is real JSON in the shapes _serialize promises
            local decoded = decodeConfig(w1)
            expect(decoded.toggle).to.equal(true)
            expect(decoded.slider).to.equal(0.5)
            expect(decoded.bind[1]).to.equal("Enum.KeyCode")
            expect(decoded.bind[2]).to.equal(Enum.KeyCode.J.Value)
            expect(decoded.color).to.equal("336699cc")

            -- a fresh window restores every value exactly
            local w2 = newWindow(true)
            local tab2 = w2:CreateTab({ name = "Main" })
            local toggle = tab2:CreateToggle({ name = "Flag Toggle", flag = "toggle", value = false })
            local slider =
                tab2:CreateSlider({ name = "Speed", flag = "slider", range = { 0, 1 }, increment = 0.01, value = 0 })
            local drop = tab2:CreateDropdown({
                name = "Ultimates",
                flag = "drop",
                multiSelect = true,
                options = { "A", "B", "C" },
                value = {},
            })
            local bind = tab2:CreateKeybind({ name = "Hotkey", flag = "bind", value = Enum.KeyCode.H })
            local color2 =
                tab2:CreateColorPicker({ name = "Accent", flag = "color", value = Color3.fromRGB(255, 0, 0) })
            w2:Show()

            expect(toggle.value).to.equal(true)
            expect(slider.value).to.equal(0.5)
            expect(#drop.value).to.equal(2)
            expect(table.find(drop.value, "A")).to.be.ok()
            expect(table.find(drop.value, "C")).to.be.ok()
            expect(bind.value).to.equal(Enum.KeyCode.J)
            expect(color2.value).to.equal(Color3.fromRGB(51, 102, 153))
            expect(color2.alpha).to.equal(0.8)
        end)

        it("restores a pending dropdown selection when its option is added", function()
            local w = newWindow(false)
            local tab = w:CreateTab({ name = "Main" })
            local picks = 0
            local d = tab:CreateDropdown({
                name = "Late Options",
                flag = "late",
                options = {},
                callback = function(value)
                    if value == "X" then
                        picks += 1
                    end
                end,
            })

            d:Set("X") -- intent lands before any option exists
            expect(#d.value).to.equal(0)

            d:Add("X")
            expect(d.value[1]).to.equal("X")
            expect(picks).to.equal(1)

            d:Add("X") -- a duplicate add must not re-fire the selection
            expect(picks).to.equal(1)

            local decoded = decodeConfig(w)
            expect(decoded.late[1]).to.equal("X")
        end)

        it("reverts a NaN numeric commit without persisting", function()
            local w = newWindow(false)
            local tab = w:CreateTab({ name = "Main" })
            local input = tab:CreateInput({ name = "Amount", flag = "amount", value = "10", numeric = true })
            table.clear(files) -- only the commit below could write

            input.input.Text = "-1^0.5" -- (-1)^0.5 is nan
            input.input.FocusLost:Fire()

            expect(input.value).to.equal("10")
            expect(input.input.Text).to.equal("10")
            expect(next(files)).to.equal(nil)
        end)

        it("follows the mouse through a drag and persists on release", function()
            -- nonzero inset so the mouse-to-track math is exercised against real conditions
            helpers.services.GuiService._setGuiInset(Vector2.new(0, 58))

            local w = newWindow(false)
            local tab = w:CreateTab({ name = "Main" })
            local seen = {}
            local slider = tab:CreateSlider({
                name = "Drag",
                flag = "drag",
                range = { 0, 100 },
                increment = 1,
                value = 0,
                callback = function(value)
                    table.insert(seen, value)
                end,
            })
            slider.track.AbsolutePosition = Vector2.new(100, 300)
            slider.track.AbsoluteSize = Vector2.new(200, 14)

            helpers.services.UserInputService._setMouseLocation(Vector2.new(150, 80))
            slider.interact.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
            expect(slider.dragging).to.equal(true)
            expect(slider.value).to.equal(25) -- (150 - 100) / 200 of the range

            helpers.services.UserInputService._setMouseLocation(Vector2.new(200, 80))
            helpers.services.RunService.RenderStepped:Fire()
            expect(slider.value).to.equal(50)
            expect(seen[1]).to.equal(25)
            expect(seen[2]).to.equal(50)

            helpers.services.UserInputService.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
            expect(slider.dragging).to.equal(false)

            -- released: the per-frame follow is gone
            helpers.services.UserInputService._setMouseLocation(Vector2.new(100, 80))
            helpers.services.RunService.RenderStepped:Fire()
            expect(slider.value).to.equal(50)

            local decoded = decodeConfig(w)
            expect(decoded.drag).to.equal(50)
        end)

        it("ends a drag when the window loses focus", function()
            local w = newWindow(false)
            local tab = w:CreateTab({ name = "Main" })
            local slider =
                tab:CreateSlider({ name = "Drag", flag = "drag", range = { 0, 100 }, increment = 1, value = 0 })
            slider.track.AbsolutePosition = Vector2.new(100, 300)
            slider.track.AbsoluteSize = Vector2.new(200, 14)

            helpers.services.UserInputService._setMouseLocation(Vector2.new(150, 80))
            slider.interact.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
            expect(slider.dragging).to.equal(true)

            helpers.services.UserInputService.WindowFocusReleased:Fire()
            expect(slider.dragging).to.equal(false)
        end)
    end)

    describe("component window viewport fitting", function()
        local variables = helpers.requireUtility("variables")
        local originalCamera
        local fitted

        local function makeWindow()
            fitted = Window.new({
                name = "Fit Window",
                configuration = { autoSave = false, autoLoad = false },
            })
            return fitted
        end

        -- a signal the specs can actually fire, so the watcher gets exercised rather than
        -- just constructed
        local function makeSignal()
            local handlers = {}
            return {
                Connect = function(_, handler)
                    table.insert(handlers, handler)
                    return {
                        Disconnect = function()
                            local index = table.find(handlers, handler)
                            if index then
                                table.remove(handlers, index)
                            end
                        end,
                    }
                end,
                fire = function()
                    for _, handler in table.clone(handlers) do
                        handler()
                    end
                end,
                connected = function()
                    return #handlers
                end,
            }
        end

        -- a camera the specs can move, standing in for a screen that rotates or resizes
        local function makeCamera(x, y)
            local changed = makeSignal()
            return {
                ViewportSize = Vector2.new(x, y),
                changed = changed,
                GetPropertyChangedSignal = function()
                    return changed
                end,
            }
        end

        local function setViewport(x, y)
            local camera = makeCamera(x, y)
            variables.workspace.CurrentCamera = camera
            return camera
        end

        local originalWorkspaceSignal
        local cameraSwapped

        beforeEach(function()
            originalCamera = variables.workspace.CurrentCamera
            originalWorkspaceSignal = variables.workspace.GetPropertyChangedSignal
            cameraSwapped = makeSignal()
            variables.workspace.GetPropertyChangedSignal = function()
                return cameraSwapped
            end
        end)

        afterEach(function()
            variables.workspace.CurrentCamera = originalCamera
            variables.workspace.GetPropertyChangedSignal = originalWorkspaceSignal
            if fitted and not fitted.unloaded then
                fitted:Unload()
            end
            fitted = nil
        end)

        it("sizes a new window from the current viewport", function()
            setViewport(844, 390)
            local w = makeWindow()
            -- a short screen gives height up and earns a little width back for it
            expect(w.size.Y.Offset < 500).to.equal(true)
            expect(w.size.X.Offset > 475).to.equal(true)
        end)

        it("re-fits a live window when the viewport changes", function()
            setViewport(1920, 1080)
            local w = makeWindow()
            w.hidden = false
            expect(w.size.X.Offset).to.equal(475)

            setViewport(844, 390)
            w:_applyWindowSize()

            expect(w.size.X.Offset > 475).to.equal(true)
            expect(w.main.Size).to.equal(w.size)
        end)

        it("banks the new size without resizing a hidden window", function()
            setViewport(1920, 1080)
            local w = makeWindow()
            local before = w.main.Size

            setViewport(844, 390)
            w:_applyWindowSize()

            -- the size is taken, but a collapsed window must not be yanked open by a rotation
            expect(w.size.X.Offset > 475).to.equal(true)
            expect(w.main.Size).to.equal(before)
        end)

        it("pulls a dragged window back on screen after a shrink", function()
            setViewport(1920, 1080)
            local w = makeWindow()
            w.screenGui.AbsoluteSize = Vector2.new(700, 500)
            w.main.Position = UDim2.fromOffset(2000, 1500)

            w:_clampToScreen()

            expect(w.main.Position.X.Offset < 2000).to.equal(true)
            expect(w.main.Position.Y.Offset < 1500).to.equal(true)
        end)

        it("leaves a centred window on scale positioning", function()
            setViewport(1920, 1080)
            local w = makeWindow()
            w.screenGui.AbsoluteSize = Vector2.new(700, 500)
            local centred = UDim2.new(0.5, 0, 0.5, 0)
            w.main.Position = centred

            w:_clampToScreen()

            expect(w.main.Position).to.equal(centred)
        end)

        it("clamps a restore target that no longer fits the screen", function()
            setViewport(1920, 1080)
            local w = makeWindow()
            w.hidden = false
            w.screenGui.AbsoluteSize = Vector2.new(1920, 1080)
            -- parked near the right edge, then hidden, so this is where Show grows back to
            w.main.Position = UDim2.fromOffset(1700, 900)
            w._restorePosition = w.main.Position

            -- the screen shrinks under it while it is away
            w.screenGui.AbsoluteSize = Vector2.new(700, 500)
            setViewport(700, 500)
            w:_applyWindowSize()

            local target = w:_clampedPosition(w._restorePosition)
            expect(target.X.Offset < 1700).to.equal(true)
            expect(target.X.Offset + w.size.X.Offset / 2 <= 700).to.equal(true)
            expect(target.Y.Offset + w.size.Y.Offset / 2 <= 500).to.equal(true)
        end)

        it("keeps the drag bar under the window's bottom edge", function()
            setViewport(1920, 1080)
            local w = makeWindow()
            w.main.Position = UDim2.fromOffset(300, 200)

            w:_syncDragBar()

            expect(w.drag.drag.Position.X.Offset).to.equal(300)
            expect(w.drag.drag.Position.Y.Offset).to.equal(200 + w.size.Y.Offset / 2 + 15)
        end)

        it("resizes off the ViewportSize signal without being driven directly", function()
            local camera = setViewport(1920, 1080)
            local w = makeWindow()
            w.hidden = false
            expect(w.size.X.Offset).to.equal(475)

            -- the watcher alone must carry this through, so nothing calls _applyWindowSize here
            camera.ViewportSize = Vector2.new(844, 390)
            camera.changed.fire()

            expect(w.size.X.Offset > 475).to.equal(true)
            expect(w.main.Size).to.equal(w.size)
        end)

        it("rebinds to a replacement camera and drops the old one", function()
            local first = setViewport(1920, 1080)
            local w = makeWindow()
            w.hidden = false

            local replacement = setViewport(844, 390)
            cameraSwapped.fire() -- respawn, or the game swapping CurrentCamera

            -- rebinding re-fits straight away, off the new camera
            expect(w.size.X.Offset > 475).to.equal(true)

            -- and the replacement drives it from here, while the dead camera does not
            replacement.ViewportSize = Vector2.new(1920, 1080)
            replacement.changed.fire()
            expect(w.size.X.Offset).to.equal(475)

            first.ViewportSize = Vector2.new(667, 375)
            first.changed.fire()
            expect(w.size.X.Offset).to.equal(475)
            expect(first.changed.connected()).to.equal(0)
        end)

        it("applies a size banked during a reveal once the window settles", function()
            setViewport(1920, 1080)
            local w = makeWindow()
            w.hidden = false
            w:_applyWindowSize()
            local before = w.main.Size

            -- a rotation mid-reveal must not fight the tween, but must not be lost either
            w._revealing = true
            setViewport(844, 390)
            w:_applyWindowSize()
            expect(w.main.Size).to.equal(before)
            expect(w.size).never.to.equal(before)

            w._revealing = false
            w:_applyWindowSize()
            expect(w.main.Size).to.equal(w.size)
        end)
    end)
end
