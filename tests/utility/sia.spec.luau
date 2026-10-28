local HttpService = game:GetService("HttpService")
local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local SIA = requireUtility("sia")

    -- A client driven by hand: the request is captured, the settings given, no timers.
    local function client(config)
        local sent = {}
        local sia = SIA.new({
            token = "sia_test_token_000000000000",
            lib = "gen2",
            libVersion = "test",
            script = { name = "Spec Hub" },
            config = config or { on = true, detail = 1 },
            manual = true,
            request = function(req)
                table.insert(sent, HttpService:JSONDecode(req.Body))
                return { StatusCode = 200, Body = '{"ok":true}' }
            end,
        })
        return sia, sent
    end
    local function flushed(sia, sent, final)
        sia:_flush(final)
        task.wait()
        return sent[#sent]
    end
    local function row(batch, id)
        for _, t in batch.t do
            if t[1] == id then
                return t
            end
        end
        return nil
    end

    describe("utility.sia", function()
        it("gives an element a short, stable id and a category, never its label", function()
            local sia, sent = client()
            local farm = sia:element("toggle", "Auto Farm Coins", 1)
            expect(farm).to.be.ok()
            expect(string.match(farm, "^[a-z0-9]+$")).to.be.ok()
            expect(sia:element("toggle", "Auto Farm Coins", 1)).to.equal(farm)
            local batch = flushed(sia, sent, false)
            expect(row(batch, farm)[4]).to.equal("autofarm")
            expect(string.find(HttpService:JSONEncode(batch), "Auto Farm", 1, true)).never.to.be.ok()
        end)

        it("sorts labels into categories", function()
            expect(SIA._categoryOf("Silent Aim")).to.equal("silentaim")
            expect(SIA._categoryOf("Player ESP")).to.equal("esp")
            expect(SIA._categoryOf("WalkSpeed")).to.equal("speed")
            expect(SIA._categoryOf("Teleport to spawn")).to.equal("teleport")
            expect(SIA._categoryOf("Save config")).to.equal("settings")
            expect(SIA._categoryOf("Rainbow sword")).to.equal("misc")
        end)

        it("counts uses, three quick presses as one rage click, and keeps values", function()
            local sia, sent = client()
            local buy = sia:element("button", "Buy Egg", 1)
            local speed = sia:element("slider", "Speed", 1)
            for _ = 1, 3 do
                sia:used(buy, "press")
            end
            sia:used(speed, "set", 0.75)
            local batch = flushed(sia, sent, false)
            expect(row(batch, buy)[5]).to.equal(3)
            expect(row(batch, buy)[9]).to.equal(1)
            expect(row(batch, speed)[7]).to.equal(0.75)
            expect(#batch.o).to.equal(4)
        end)

        it("totals start again after each batch", function()
            local sia, sent = client()
            local buy = sia:element("button", "Buy Egg", 1)
            sia:used(buy, "press")
            flushed(sia, sent, false)
            sia:used(buy, "press")
            local second = flushed(sia, sent, false)
            expect(row(second, buy)[5]).to.equal(1)
            expect(second.q).to.equal(1)
        end)

        it("marks a tab's elements seen when it opens", function()
            local sia, sent = client()
            local a = sia:element("toggle", "ESP", 1)
            local b = sia:element("toggle", "Fly", 2)
            sia:tab(1)
            local batch = flushed(sia, sent, false)
            expect(row(batch, a)[8]).to.equal(1)
            expect(row(batch, b)[8]).to.equal(0)
        end)

        it("times a toggle while it's on, and sends the state at close", function()
            local sia, sent = client()
            local farm = sia:element("toggle", "Auto Farm", 1)
            sia:state(farm, 1)
            sia:state(farm, 0)
            sia:state(farm, 1)
            sia:window("open")
            sia:window("minimise")
            sia:window("restore")
            sia:window("close")
            task.wait()
            local batch = sent[#sent]
            expect(batch.e[3]).to.equal(1)
            expect(batch.e[4]).to.equal(1)
            expect(batch.e[5]).to.equal(1)
            expect(#batch.z).to.equal(1)
            expect(batch.z[1][2]).to.equal(1)
        end)

        it("records the key screen, errors and the author's events", function()
            local sia, sent = client()
            sia:keyScreen("shown")
            sia:keyScreen("copied")
            sia:keyScreen("attempt")
            sia:keyScreen("accepted")
            sia:error("x")
            sia:track("Opened Shop!")
            local batch = flushed(sia, sent, false)
            expect(batch.ks[1]).to.equal(1)
            expect(batch.ks[2]).to.equal(1)
            expect(batch.ks[4]).to.equal(1)
            expect(batch.ks[5]).to.equal(1)
            expect(batch.h[1]).to.equal(1)
            expect(batch.ev[1][1]).to.equal("opened_shop_")
        end)

        it("sends no detail on a run outside the detail share", function()
            local sia, sent = client({ on = true, detail = 0 })
            local buy = sia:element("button", "Buy", 1)
            sia:used(buy, "press")
            local batch = flushed(sia, sent, true)
            expect(batch.f).to.equal(0)
            expect(batch.o).never.to.be.ok()
            expect(batch.z).never.to.be.ok()
        end)

        it("sends nothing when the server says off, or after disable", function()
            local off, offSent = client({ on = false })
            off:_flush(true)
            task.wait()
            expect(#offSent).to.equal(0)
            local sia, sent = client()
            sia:disable()
            sia:_flush(true)
            task.wait()
            expect(#sent).to.equal(0)
        end)

        it("runs by itself: fetches its settings, then sends its first batch", function()
            -- The test runner's task.spawn runs at once and task.wait never yields, so the
            -- client's loop only ends when the server answers 403 and turns it off.
            local sent, fetched = {}, 0
            local sia = SIA.new({
                token = "sia_test_token_000000000000",
                lib = "gen2",
                request = function(req)
                    if req.Method == "GET" then
                        fetched += 1
                        return { StatusCode = 200, Body = '{"on":true,"detail":1,"firstBatch":0,"every":3600}' }
                    end
                    table.insert(sent, HttpService:JSONDecode(req.Body))
                    return { StatusCode = 403, Body = '{"stop":true}' }
                end,
            })
            expect(fetched).to.equal(1)
            expect(#sent).to.equal(1)
            expect(sent[1].q).to.equal(0)
            expect(sent[1].d).to.be.ok()
            expect(sia._disabled).to.equal(true)
        end)

        it("stops for the run when the server answers 403", function()
            local sia = SIA.new({
                token = "sia_test_token_000000000000",
                config = { on = true, detail = 0 },
                manual = true,
                request = function()
                    return { StatusCode = 403, Body = "{}" }
                end,
            })
            sia:_flush(false)
            task.wait()
            expect(sia._disabled).to.equal(true)
        end)

        it("reads a kick from Roblox's error prompt and sends it with what was on", function()
            local sia, sent = client()
            local farm = sia:element("toggle", "Auto Farm", 1)
            sia:used(farm, "on", 1)
            local CoreGui = game:GetService("CoreGui")
            local function folder(name, parent)
                local f = Instance.new("Folder")
                f.Name = name
                f.Parent = parent
                return f
            end
            local overlay = folder("promptOverlay", folder("RobloxPromptGui", CoreGui))
            local errorFrame = folder("ErrorFrame", folder("MessageArea", folder("ErrorPrompt", overlay)))
            local label = Instance.new("TextLabel")
            label.Name = "ErrorMessage"
            label.Text = "You were kicked from this experience: exploiting (Error Code: 267)"
            label.Parent = errorFrame
            sia:_watchKicks()
            task.wait()
            CoreGui.RobloxPromptGui:Destroy()
            local kick = sent[#sent].kk
            expect(kick).to.be.ok()
            expect(kick.c).to.equal(267)
            expect(kick.l).to.equal(farm)
            expect(kick.n[1]).to.equal(farm)
        end)

        it("makes a kick reason into a template with no numbers", function()
            local text, category, hash = SIA._kickTemplate("You were detected exploiting (speed 120). Error Code: 267")
            expect(string.find(text, "%d")).never.to.be.ok()
            expect(category).to.equal("anticheat")
            expect(#hash).to.equal(16)
            expect(select(2, SIA._kickTemplate("You have been banned for 7 days"))).to.equal("ban")
            expect(select(2, SIA._kickTemplate("You were kicked for being idle"))).to.equal("idle")
            expect(select(2, SIA._kickTemplate("This server is shutting down"))).to.equal("server")
        end)
    end)
end
