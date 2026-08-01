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

            w:Show()
            expect(w.windowStroke.Transparency).to.equal(0.95)

            w:Hide()
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

    describe("component window resizing", function()
        local variables = helpers.requireUtility("variables")
        local originalCamera
        local originalMouseLocation
        local resized
        local mouse = Vector2.new(0, 0)

        local function makeWindow()
            resized = Window.new({
                name = "Resize Window",
                configuration = { autoSave = false, autoLoad = false },
            })
            resized.hidden = false
            resized.resize:_refresh()
            resized.resize:_setShown(true, false)
            return resized
        end

        -- these specs drive the reconcile by hand, so the camera only has to be connectable
        local function setViewport(x, y)
            variables.workspace.CurrentCamera = {
                ViewportSize = Vector2.new(x, y),
                GetPropertyChangedSignal = function()
                    return {
                        Connect = function()
                            return { Disconnect = function() end }
                        end,
                    }
                end,
            }
        end

        local function grab()
            resized.resize.grip.InputBegan:Fire({ UserInputType = { Name = "MouseButton1" } }, false)
        end

        local function moveTo(x, y)
            mouse = Vector2.new(x, y)
            helpers.services.UserInputService.InputChanged:Fire({ UserInputType = { Name = "MouseMovement" } })
        end

        local function release()
            helpers.services.UserInputService.InputEnded:Fire({ UserInputType = { Name = "MouseButton1" } })
        end

        -- one frame long enough that the follow closes the whole gap, so the specs assert where
        -- the window lands rather than a point part-way along the glide
        local function settle()
            helpers.services.RunService.RenderStepped:Fire(1)
            helpers.services.RunService.RenderStepped:Fire(1)
        end

        beforeEach(function()
            originalCamera = variables.workspace.CurrentCamera
            originalMouseLocation = helpers.services.UserInputService.GetMouseLocation
            mouse = Vector2.new(0, 0)
            helpers.services.UserInputService.GetMouseLocation = function()
                return mouse
            end
            setViewport(1920, 1080)
        end)

        afterEach(function()
            variables.workspace.CurrentCamera = originalCamera
            helpers.services.UserInputService.GetMouseLocation = originalMouseLocation
            if resized and not resized.unloaded then
                resized:Unload()
            end
            resized = nil
        end)

        it("builds the grip and follows the resizable setting", function()
            local w = makeWindow()
            expect(w.resize).to.be.ok()
            expect(w.resize.grip.Parent).to.equal(w.main)
            expect(w.resize.grip.Visible).to.equal(true)

            w.resize:SetEnabled(false)
            expect(w.settings.resizable).to.equal(false)
            expect(w.resize.grip.Visible).to.equal(false)

            w.resize:SetEnabled(true)
            expect(w.resize.grip.Visible).to.equal(true)
        end)

        it("brings the mark in after the window it sits on, and takes it off first", function()
            local w = makeWindow()

            w.resize:_setShown(false, false)
            expect(w.resize.mark.ImageTransparency).to.equal(1)

            w.resize:_setShown(true, false)
            expect(w.resize.mark.ImageTransparency).to.equal(0)

            -- the animated path goes through a tween, which the harness lands immediately
            w.resize:_setShown(false)
            expect(w.resize.mark.ImageTransparency).to.equal(1)
        end)

        it("takes the grip away from a window with no corner to grab", function()
            local w = makeWindow()

            w.minimised = true
            w.resize:_refresh()
            expect(w.resize.grip.Visible).to.equal(false)

            w.minimised = false
            w.hidden = true
            w.resize:_refresh()
            expect(w.resize.grip.Visible).to.equal(false)
        end)

        it("takes a hand-picked size and holds it to the screen", function()
            local w = makeWindow()
            local applied = w:_applyUserSize(Vector2.new(900, 640))

            expect(applied.X).to.equal(900)
            expect(w.size.X.Offset).to.equal(900)
            expect(w.main.Size).to.equal(w.size)

            -- a size the screen cant carry is held, but the ask is remembered as given
            local held = w:_applyUserSize(Vector2.new(9999, 9999))
            expect(held.X < 9999).to.equal(true)
            expect(w._userSize.X).to.equal(9999)
        end)

        it("banks a hand-picked size without resizing a hidden window", function()
            local w = makeWindow()
            local before = w.main.Size
            w.hidden = true

            w:_applyUserSize(Vector2.new(900, 640))

            expect(w.size.X.Offset).to.equal(900)
            expect(w.main.Size).to.equal(before)
        end)

        it("keeps a hand-picked size through a viewport change instead of re-fitting it", function()
            local w = makeWindow()
            w:_applyUserSize(Vector2.new(900, 640))

            setViewport(844, 390)
            w:_applyWindowSize()

            expect(w.size.X.Offset).to.equal(844 - 40)
            expect(w.size.Y.Offset).to.equal(390 - 40)

            -- and comes back in full once there is room for it again
            setViewport(1920, 1080)
            w:_applyWindowSize()
            expect(w.size.X.Offset).to.equal(900)
            expect(w.size.Y.Offset).to.equal(640)
        end)

        it("drops back to the fitted size on reset", function()
            local w = makeWindow()
            w:_applyUserSize(Vector2.new(900, 640))
            expect(w.size.X.Offset).to.equal(900)

            w:_resetUserSize()

            expect(w._userSize).to.equal(nil)
            expect(w.size.X.Offset).to.equal(475)

            -- a reset with nothing to undo is a no-op rather than a re-fit
            w:_resetUserSize()
            expect(w.size.X.Offset).to.equal(475)
        end)

        it("grows the window by twice the distance the grip is dragged", function()
            local w = makeWindow()
            local before = Vector2.new(w.size.X.Offset, w.size.Y.Offset)

            moveTo(400, 300)
            grab()
            moveTo(500, 380)
            settle()

            -- the window is centre-anchored, so both edges move and the corner under the cursor
            -- only covers half of whatever the size gains
            expect(w.size.X.Offset).to.equal(before.X + 200)
            expect(w.size.Y.Offset).to.equal(before.Y + 160)
        end)

        it("leaves the window centred while it resizes", function()
            local w = makeWindow()
            local before = w.main.Position

            moveTo(400, 300)
            grab()
            moveTo(500, 380)
            settle()

            expect(w.main.Position).to.equal(before)
        end)

        it("eases toward the size rather than jumping to it", function()
            local w = makeWindow()
            local before = w.size.X.Offset

            moveTo(400, 300)
            grab()
            moveTo(600, 300)

            -- a short frame closes only part of the gap, so the window is still on its way
            helpers.services.RunService.RenderStepped:Fire(1 / 60)
            local midway = w.size.X.Offset
            expect(midway > before).to.equal(true)
            expect(midway < before + 400).to.equal(true)

            settle()
            expect(w.size.X.Offset).to.equal(before + 400)
        end)

        it("holds the drag inside what the screen can carry", function()
            local w = makeWindow()

            moveTo(0, 0)
            grab()
            moveTo(4000, 4000)
            settle()

            expect(w.size.X.Offset).to.equal(1920 - 40)
            expect(w.size.Y.Offset).to.equal(1080 - 40)
        end)

        it("holds the drag at the minimum size", function()
            local w = makeWindow()
            local sizing = helpers.requireUtility("windowSizing")

            moveTo(400, 300)
            grab()
            moveTo(0, 0)
            settle()

            expect(w.size.X.Offset).to.equal(sizing.manualMinSize.X)
            expect(w.size.Y.Offset).to.equal(sizing.manualMinSize.Y)
        end)

        it("stops resizing once the grip is released", function()
            local w = makeWindow()
            moveTo(400, 300)
            grab()
            moveTo(500, 400)
            settle()
            local held = w.size

            release()
            moveTo(900, 900)
            settle()

            expect(w.size).to.equal(held)
        end)

        it("snaps back to the fitted size on a double click", function()
            local w = makeWindow()
            w:_applyUserSize(Vector2.new(900, 640))
            expect(w.size.X.Offset).to.equal(900)

            -- two presses inside the double-click window: the first arms the shortcut, the
            -- second takes it, and the window glides back rather than jumping
            moveTo(400, 300)
            grab()
            release()
            grab()
            settle()

            expect(w.size.X.Offset).to.equal(475)
            expect(w._userSize).to.equal(nil)
        end)

        it("drops a grab that goes stale under it", function()
            local w = makeWindow()
            moveTo(400, 300)
            grab()

            -- hidden mid-drag: the grab must die here rather than wake up later and yank the
            -- window out to wherever the cursor drifted while it was away
            w.hidden = true
            settle()
            local held = w.size

            w.hidden = false
            moveTo(1200, 1200)
            settle()
            expect(w.size).to.equal(held)
        end)

        it("ignores a grab while resizing is switched off", function()
            local w = makeWindow()
            w.resize:SetEnabled(false)
            local before = w.size

            moveTo(400, 300)
            grab()
            moveTo(600, 600)
            settle()

            expect(w.size).to.equal(before)
        end)

        it("ignores a grab the interface already handled, and input that is neither click nor touch", function()
            local w = makeWindow()
            local before = w.size

            moveTo(400, 300)
            w.resize.grip.InputBegan:Fire({ UserInputType = { Name = "MouseButton1" } }, true)
            w.resize.grip.InputBegan:Fire({ UserInputType = { Name = "Keyboard" } }, false)
            moveTo(600, 600)
            helpers.services.UserInputService.InputEnded:Fire({ UserInputType = { Name = "Keyboard" } })
            settle()

            expect(w.size).to.equal(before)
        end)

        it("takes a touch by where it reports itself, not the mouse", function()
            local w = makeWindow()
            local before = w.size.X.Offset

            mouse = Vector2.new(0, 0)
            w.resize.grip.InputBegan:Fire({
                UserInputType = { Name = "Touch" },
                Position = Vector3.new(400, 300, 0),
            }, false)
            helpers.services.UserInputService.InputChanged:Fire({
                UserInputType = { Name = "Touch" },
                Position = Vector3.new(500, 300, 0),
            })
            settle()

            expect(w.size.X.Offset).to.equal(before + 200)
        end)

        it("leans the bracket toward the corner and settles it again", function()
            local w = makeWindow()
            local mark = w.resize.mark
            w.resize.grip.AbsolutePosition = Vector2.new(400, 400)
            w.resize.grip.AbsoluteSize = Vector2.new(54, 54)

            -- close to the far edge of the grip first, then right into the corner: the mark is
            -- longest reaching out from the window and shortest at the corner itself
            mouse = Vector2.new(410, 410)
            w.resize.grip.MouseEnter:Fire()
            local entered = mark.Size.X.Offset

            -- further into the corner is a longer arm, not just a brighter one
            mouse = Vector2.new(450, 440)
            w.resize.grip.InputChanged:Fire({ UserInputType = { Name = "MouseMovement" } })
            local near = mark.Size.X.Offset
            expect(near < entered).to.equal(true)

            w.resize.grip.MouseLeave:Fire()
            expect(mark.Size.X.Offset).to.equal(18)
        end)

        it("releases a grab when the client loses focus", function()
            local w = makeWindow()
            moveTo(400, 300)
            grab()
            moveTo(500, 400)
            settle()
            local held = w.size

            helpers.services.UserInputService.WindowFocusReleased:Fire()
            moveTo(900, 900)
            settle()

            expect(w.size).to.equal(held)
        end)

        it("reflows a slider between its two layouts when the window crosses the width it needs", function()
            local w = makeWindow()
            w.hasShownOnce = true
            local tab = w:CreateTab({ name = "Main" })
            local slider = tab:CreateSlider({
                name = "Volume",
                range = { 0, 100 },
                increment = 1,
                value = 40,
                forgetState = true,
            })

            -- built wide, and the first pass lands at once because there is nothing to watch yet
            slider.main.AbsoluteSize = Vector2.new(455, 65)
            slider:_applyLayout()
            expect(slider._layoutMode).to.equal("wide")
            expect(slider.track.AnchorPoint).to.equal(Vector2.new(1, 0.5))
            expect(slider.containerLayout.FillDirection).to.equal(Enum.FillDirection.Vertical)

            -- pulled in past what the wide layout needs: the track heads for the bottom edge,
            -- and the labels land in their row once the fade has taken them off screen
            slider.main.AbsoluteSize = Vector2.new(360, 65)
            slider:_applyLayout()
            expect(slider._layoutMode).to.equal("narrow")
            expect(slider.track.AnchorPoint).to.equal(Vector2.new(0.5, 1))

            slider:_finishReflow(slider._reflowPass, "narrow")
            expect(slider.containerLayout.FillDirection).to.equal(Enum.FillDirection.Horizontal)
            expect(slider.title.TextTransparency).to.equal(0)

            -- and back out again
            slider.main.AbsoluteSize = Vector2.new(455, 65)
            slider:_applyLayout()
            slider:_finishReflow(slider._reflowPass, "wide")
            expect(slider.track.AnchorPoint).to.equal(Vector2.new(1, 0.5))
            expect(slider.containerLayout.FillDirection).to.equal(Enum.FillDirection.Vertical)
        end)

        it("drops a reflow that a newer one has already replaced", function()
            local w = makeWindow()
            w.hasShownOnce = true
            local tab = w:CreateTab({ name = "Main" })
            local slider = tab:CreateSlider({ name = "Volume", range = { 0, 100 }, value = 40, forgetState = true })

            slider.main.AbsoluteSize = Vector2.new(455, 65)
            slider:_applyLayout()
            slider.main.AbsoluteSize = Vector2.new(360, 65)
            slider:_applyLayout()
            slider:_finishReflow(slider._reflowPass, "narrow")

            -- a pass the resize has already moved past must not put its layout back on screen
            slider:_finishReflow(slider._reflowPass - 1, "wide")
            expect(slider.containerLayout.FillDirection).to.equal(Enum.FillDirection.Horizontal)
        end)

        it("travels a row child only when the packing moved it to another line", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })
            local row = tab:CreateGroup({ direction = "row" })
            local first = row:CreateButton({ name = "First" })
            local second = row:CreateButton({ name = "Second" })

            -- the layout owns the position of what it lays out, so each row child rides inside
            -- a slot it can be animated within
            expect(second._slot).to.be.ok()
            expect(second.main.Parent).to.equal(second._slot)
            expect(first._slot.LayoutOrder).to.equal(first.main.LayoutOrder)

            -- both on one line to begin with
            row.main.AbsoluteSize = Vector2.new(900, 41)
            row:_shareWidth()
            expect(first._line).to.equal(1)
            expect(second._line).to.equal(1)

            -- THE regression this guards: the window moves under the group every frame of a
            -- resize, so the slot's screen position changes constantly. None of that is a wrap,
            -- and none of it may start an animation.
            second.main.Position = UDim2.fromOffset(0, 0)
            second._slot.AbsolutePosition = Vector2.new(600, 900)
            row:_slideIntoPlace(second)
            expect(second.main.Position).to.equal(UDim2.fromOffset(0, 0))

            -- narrow enough to push the second child onto its own line: now it has somewhere to
            -- travel from, and the layout hands it over on the next position change
            row.main.AbsoluteSize = Vector2.new(second._minSlotWidth + 20, 41)
            row:_shareWidth()
            expect(second._line).to.equal(2)
            expect(second._travelFrom).to.be.ok()

            row:_slideIntoPlace(second)
            expect(second._travelFrom).to.equal(nil)

            -- and the hand-over is spent: a second call has nothing left to act on
            second.main.Position = UDim2.fromOffset(0, 0)
            row:_slideIntoPlace(second)
            expect(second.main.Position).to.equal(UDim2.fromOffset(0, 0))
        end)

        it("holds a line's break width until there is room to spare", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })
            local row = tab:CreateGroup({ direction = "row" })
            local one = row:CreateButton({ name = "One" })
            local two = row:CreateButton({ name = "Two" })

            local padding = row.layout.Padding.Offset
            local both = one._minSlotWidth + padding + two._minSlotWidth

            -- a width that just holds both
            row.main.AbsoluteSize = Vector2.new(both + 40, 41)
            row:_shareWidth()
            expect(two._line).to.equal(1)

            -- one pixel under, and the second child is pushed down
            row.main.AbsoluteSize = Vector2.new(both, 41)
            row:_shareWidth()
            expect(two._line).to.equal(2)

            -- back to the width it broke at is not enough to bring it up again, or a drag held
            -- there would flip it every frame
            row.main.AbsoluteSize = Vector2.new(both + 4, 41)
            row:_shareWidth()
            expect(two._line).to.equal(2)

            -- clear of the band, and it comes back
            row.main.AbsoluteSize = Vector2.new(both + 40, 41)
            row:_shareWidth()
            expect(two._line).to.equal(1)
        end)

        it("shares a line's width between the children on it", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })
            local row = tab:CreateGroup({ direction = "row" })
            local one = row:CreateButton({ name = "One" })
            local two = row:CreateButton({ name = "Two" })

            -- wide enough for both: the spare width is split between them
            row.main.AbsoluteSize = Vector2.new(600, 41)
            row:_shareWidth()
            expect(#row:_packRows(600)).to.equal(1)
            expect(one._slot.Size.X.Offset).to.equal(two._slot.Size.X.Offset)
            expect(one._slot.Size.X.Offset > one._minSlotWidth).to.equal(true)

            -- and it is very nearly the whole line: a couple of pixels are left back so the
            -- layout has to break its lines where the packing did, rather than a rounding error
            -- away from it
            local padding = row.layout.Padding.Offset
            local filled = one._slot.Size.X.Offset + two._slot.Size.X.Offset + padding
            expect(filled <= 600).to.equal(true)
            expect(filled > 600 - 6).to.equal(true)
        end)

        it("lands a slot's width at once and eases only what is inside it", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })
            local row = tab:CreateGroup({ direction = "row" })
            local child = row:CreateButton({ name = "One" })

            -- the layout measures the slot to decide where its lines break, so a slot easing
            -- into a width would have it re-deciding against a width still on its way
            child.main.AbsoluteSize = Vector2.new(150, 41)
            row:_setSlotWidth(child, 400, true)
            expect(child._slot.Size.X.Offset).to.equal(400)
            expect(child.main.Size.X.Scale).to.equal(1) -- the harness lands the tween at once

            -- with nothing to ease from, it simply takes the slot
            child.main.AbsoluteSize = Vector2.new(0, 41)
            row:_setSlotWidth(child, 300, true)
            expect(child._slot.Size.X.Offset).to.equal(300)
            expect(child.main.Size).to.equal(UDim2.new(1, 0, 0, child.main.Size.Y.Offset))

            -- a width it already has is not worth touching
            local held = child.main.Size
            row:_setSlotWidth(child, 300, true)
            expect(child.main.Size).to.equal(held)
        end)

        it("holds the slider's layout inside the band around its threshold", function()
            local w = makeWindow()
            w.hasShownOnce = true
            local tab = w:CreateTab({ name = "Main" })
            local slider = tab:CreateSlider({ name = "Volume", range = { 0, 100 }, value = 40, forgetState = true })

            slider.main.AbsoluteSize = Vector2.new(600, 65)
            slider:_applyLayout()
            expect(slider._layoutMode).to.equal("wide")

            -- under what the wide layout needs, so it stacks
            slider.main.AbsoluteSize = Vector2.new(400, 65)
            slider:_applyLayout()
            slider:_finishReflow(slider._reflowPass, "narrow")
            expect(slider._layoutMode).to.equal("narrow")

            -- back to exactly the threshold is not room to spare, so it stays stacked rather
            -- than trading layouts every frame a drag is held there
            slider.main.AbsoluteSize = Vector2.new(437, 65)
            slider:_applyLayout()
            expect(slider._layoutMode).to.equal("narrow")

            -- clear of the band, and the wide layout comes back
            slider.main.AbsoluteSize = Vector2.new(500, 65)
            slider:_applyLayout()
            slider:_finishReflow(slider._reflowPass, "wide")
            expect(slider._layoutMode).to.equal("wide")
        end)

        it("leaves the width sharing alone where it is not the row's to do", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })

            -- a column stacks, so there is no line to share out
            local column = tab:CreateGroup({ direction = "column" })
            column:CreateToggle({ name = "Stacked" })
            expect(column:_shareWidth()).to.equal(nil)

            -- a row holding a nested column has a child with no slot, and the engine keeps it
            local row = tab:CreateGroup({ direction = "row" })
            row:CreateButton({ name = "Leaf" })
            local nested = row:CreateGroup({ direction = "column" })
            nested:CreateToggle({ name = "Inside" })
            row.main.AbsoluteSize = Vector2.new(600, 41)
            expect(row:_shareWidth()).to.equal(nil)

            -- and nothing to share before the group has a width at all
            local unbuilt = tab:CreateGroup({ direction = "row" })
            unbuilt:CreateButton({ name = "Early" })
            unbuilt.main.AbsoluteSize = Vector2.new(0, 0)
            expect(unbuilt:_shareWidth()).to.equal(nil)
        end)

        it("lands a held-back height once the expansion it was waiting on is done", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })
            local row = tab:CreateGroup({ direction = "row" })
            local child = row:CreateButton({ name = "One" })

            child.main.AbsoluteSize = Vector2.new(150, 41)
            child._pendingSlotHeight = 70
            row:_setSlotWidth(child, 400, true)

            -- the harness lands the tween at once, so the held height is applied with it
            expect(child._pendingSlotHeight).to.equal(nil)
            expect(child.main.Size).to.equal(UDim2.new(1, 0, 0, 70))
        end)

        it("hands a height change over to the row while it is still easing into a width", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })
            local row = tab:CreateGroup({ direction = "row" })
            local slider = row:CreateSlider({ name = "Row Slider", range = { 0, 100 }, value = 10 })

            slider._slotExpanding = true
            local before = slider.main.Size
            slider:_setMainHeight(70, true)
            expect(slider.main.Size).to.equal(before)
            expect(slider._pendingSlotHeight).to.equal(70)

            slider._slotExpanding = false
            slider:_setMainHeight(65, false)
            expect(slider.main.Size.Y.Offset).to.equal(65)
        end)

        it("leaves a row child alone while the window is not on screen", function()
            local w = makeWindow()
            local tab = w:CreateTab({ name = "Main" })
            local row = tab:CreateGroup({ direction = "row" })
            local child = row:CreateButton({ name = "Only" })

            child._slot.AbsolutePosition = Vector2.new(300, 100)
            row:_slideIntoPlace(child)

            w.hidden = true
            child._slot.AbsolutePosition = Vector2.new(20, 160)
            row:_slideIntoPlace(child)
            expect(child.main.Position).to.equal(UDim2.fromOffset(0, 0))

            -- a child with no slot at all (a row that never wrapped it) is a no-op
            child._slot = nil
            row:_slideIntoPlace(child)
            expect(child.main.Position).to.equal(UDim2.fromOffset(0, 0))
        end)

        it("holds the bottom fade above the corner radius as the window grows", function()
            local w = makeWindow()
            local radius = w.bottomFadeCorner.CornerRadius.Offset

            w:_applyUserSize(Vector2.new(600, 500))
            local shortWindow = w.bottomFade.Size.Y.Offset

            -- the fade is authored to shrink as the window grows; past a point it would round
            -- tighter than the window and cut a line across the base
            w:_applyUserSize(Vector2.new(600, 900))
            local tallWindow = w.bottomFade.Size.Y.Offset

            expect(shortWindow > tallWindow or tallWindow == radius * 2).to.equal(true)
            expect(tallWindow >= radius * 2).to.equal(true)
        end)
    end)
end
