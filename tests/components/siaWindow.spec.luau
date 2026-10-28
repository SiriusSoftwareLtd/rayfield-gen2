local helpers = (_G :: any).__RAYFIELD_TEST_HELPERS
local HttpService = game:GetService("HttpService")

-- SIA inside a real window: elements register with their type and tab, a player's
-- actions count and a script's own Set doesn't, values are kept, and the settings switch
-- turns it off. The test environment is Studio, where the window never starts SIA
-- by itself, so each test hands it a client driven by hand.
return function()
    local Window = helpers.requireComponent("window")
    local SIA = helpers.requireUtility("sia")

    describe("component window sia", function()
        local window
        local sent

        local function makeWindow()
            window = Window.new({
                name = "Spec Window",
                subtitle = "Harness",
                showName = "Spec",
                configuration = { autoSave = false, autoLoad = false },
            })
            sent = {}
            window._sia = SIA.new({
                token = "sia_test_token_000000000000",
                lib = "gen2",
                config = { on = true, detail = 1 },
                manual = true,
                request = function(req)
                    table.insert(sent, HttpService:JSONDecode(req.Body))
                    return { StatusCode = 200, Body = "{}" }
                end,
            })
            return window
        end

        local function batch()
            window._sia:_flush(false)
            task.wait()
            return sent[#sent]
        end

        afterEach(function()
            if window and not window.unloaded then
                window:Unload()
            end
            window = nil
        end)

        it("registers elements with their type and tab", function()
            makeWindow()
            local tab = window:CreateTab({ name = "Main" })
            local toggle = tab:CreateToggle({ name = "Auto Farm", value = true, callback = function() end })
            local slider =
                tab:CreateSlider({ name = "Speed", range = { 0, 100 }, value = 25, callback = function() end })
            expect(toggle._sia).to.be.ok()
            expect(toggle._siaKind).to.equal("toggle")
            expect(slider._siaKind).to.equal("slider")
            local b = batch()
            local byId = {}
            for _, t in b.t do
                byId[t[1]] = t
            end
            expect(byId[toggle._sia][2]).to.equal("toggle")
            expect(byId[toggle._sia][4]).to.equal("autofarm")
            expect(byId[toggle._sia][7]).to.equal(1) -- starts on
            expect(math.abs(byId[slider._sia][7] - 0.25) < 1e-6).to.equal(true)
        end)

        it("counts a player's toggle, not a script's Set", function()
            makeWindow()
            local tab = window:CreateTab({ name = "Main" })
            local toggle = tab:CreateToggle({ name = "ESP", callback = function() end })
            toggle:Set(true)
            local afterSet = batch()
            for _, t in afterSet.t do
                if t[1] == toggle._sia then
                    expect(t[5]).to.equal(0)
                    expect(t[7]).to.equal(1) -- the value is still kept
                end
            end
            toggle:_performToggle()
            local afterPlayer = batch()
            for _, t in afterPlayer.t do
                if t[1] == toggle._sia then
                    expect(t[5]).to.equal(1)
                end
            end
        end)

        it("records a press on a locked element as dead", function()
            makeWindow()
            local tab = window:CreateTab({ name = "Main" })
            local button = tab:CreateButton({ name = "Buy", callback = function() end })
            button.locked = true
            window:_runGuarded(button, function() end)
            local b = batch()
            local ordered = b.o or {}
            expect(ordered[#ordered][3]).to.equal("dead")
        end)

        it("counts a callback that errors", function()
            makeWindow()
            local tab = window:CreateTab({ name = "Main" })
            local button = tab:CreateButton({ name = "Boom", callback = function() end })
            window:_runGuarded(button, function()
                error("boom")
            end)
            task.wait()
            expect(batch().h[1]).to.equal(1)
        end)

        it("marks a tab's elements seen when it's selected", function()
            makeWindow()
            local tab = window:CreateTab({ name = "Main" })
            local toggle = tab:CreateToggle({ name = "Fly", callback = function() end })
            tab:Select(true)
            local b = batch()
            for _, t in b.t do
                if t[1] == toggle._sia then
                    expect(t[8]).to.equal(1)
                end
            end
        end)

        it("stops when the player turns it off in settings", function()
            makeWindow()
            local sia = window._sia
            window.settings.usageAnalytics = false
            sia:disable()
            window._sia = nil
            window:_siaUsed({ _sia = "x" }, "press")
            sia:_flush(true)
            task.wait()
            expect(#sent).to.equal(0)
        end)

        it("sends tab names and element labels once", function()
            makeWindow()
            local tab = window:CreateTab({ name = "Farming" })
            window._sia:tabName(#window.tabs, tab.name)
            local toggle = tab:CreateToggle({ name = "Auto Farm", callback = function() end })
            local b = batch()
            local names, labels = {}, {}
            for _, t in b.tn or {} do
                names[t[2]] = true
            end
            for _, l in b.lb or {} do
                labels[l[1]] = l[2]
            end
            expect(names.Farming).to.equal(true)
            expect(labels[toggle._sia]).to.equal("Auto Farm")
            expect(batch().lb).to.equal(nil)
        end)

        it("closes the run when the window unloads", function()
            makeWindow()
            window:Unload()
            task.wait()
            expect(sent[#sent].e[5]).to.equal(1)
        end)
    end)
end
