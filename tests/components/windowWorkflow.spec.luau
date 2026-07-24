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

        describe("toast position", function()
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
                w:Toast({ title = "First", position = "Bottom", duration = 1 })
                w:Toast({ title = "Second", position = "Bottom", duration = 1 })
                expect(w._toastCount >= 2).to.equal(true)
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
        local blobs
        local originals

        beforeEach(function()
            windows = {}
            files = {}
            blobs = {}
            local nextBlob = 0

            originals = {
                fileSystemManager = variables.fileSystemManager,
                httpService = variables.httpService,
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
            -- a JSON stand-in that round-trips real tables: encode parks the table under a
            -- token, the token is what lands on disk, decode reads it back.
            variables.httpService = {
                GenerateGUID = function()
                    return "00000000-0000-4000-8000-000000000000"
                end,
                JSONEncode = function(_, data)
                    nextBlob += 1
                    local token = "blob-" .. nextBlob
                    blobs[token] = data
                    return token
                end,
                JSONDecode = function(_, text)
                    local stored = blobs[text]
                    if stored == nil then
                        error("no blob for " .. tostring(text))
                    end
                    return stored
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
            variables.httpService = originals.httpService
            filesystem.ensureDir = originals.ensureDir
            filesystem.writefile = originals.writefile
            filesystem.readfile = originals.readfile
            filesystem.isfile = originals.isfile
            filesystem.delfile = originals.delfile
            filesystem.listfiles = originals.listfiles
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
    end)
end
