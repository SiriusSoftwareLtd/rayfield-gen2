local helpers = (_G :: any).__RAYFIELD_TEST_HELPERS
local requireUtility = helpers.requireUtility

return function()
    local heartbeat = requireUtility("heartbeat")
    local log = requireUtility("log")

    local TOKEN = "81074364b461f8da81bad6fdc363c3b927f884d6fc28d806a15ee50ca1e68c78"
    local URL = "https://www.sentivel.com/api/heartbeat/" .. TOKEN

    -- a live-looking environment that records what it would have sent instead of sending it.
    -- spawn runs the loop inline, so a spec sees every ping the window would have made
    local function fakeEnvironment(overrides: { [string]: any }?)
        local sent, waits = {}, {}
        local env = {
            isStudio = false,
            get = function(url)
                table.insert(sent, url)
                return 200
            end,
            spawn = function(callback)
                callback()
            end,
            wait = function(seconds)
                table.insert(waits, seconds)
            end,
        }
        if overrides then
            for key, value in overrides do
                env[key] = value
            end
        end
        return env, sent, waits
    end

    -- alive for the first `count` checks, then unloaded
    local function aliveFor(count: number)
        local checks = 0
        return function()
            checks += 1
            return checks <= count
        end
    end

    describe("utility.heartbeat resolve", function()
        it("takes the full ping URL as-is", function()
            expect(heartbeat.resolve(URL)).to.equal(URL)
        end)

        it("builds the ping URL from a bare token", function()
            expect(heartbeat.resolve(TOKEN)).to.equal(URL)
        end)

        it("forgives what a copy and paste drags along", function()
            expect(heartbeat.resolve("  " .. URL .. "\n")).to.equal(URL)
            expect(heartbeat.resolve(URL .. "/")).to.equal(URL)
            expect(heartbeat.resolve("\t" .. TOKEN .. " ")).to.equal(URL)
        end)

        it("sends the bare domain and plain http to www over https", function()
            expect(heartbeat.resolve("https://sentivel.com/api/heartbeat/" .. TOKEN)).to.equal(URL)
            expect(heartbeat.resolve("http://www.sentivel.com/api/heartbeat/" .. TOKEN)).to.equal(URL)
            expect(heartbeat.resolve("HTTPS://WWW.Sentivel.com/api/heartbeat/" .. TOKEN)).to.equal(URL)
        end)

        it("lowercases the token, the only case Sentivel matches", function()
            expect(heartbeat.resolve(string.upper(TOKEN))).to.equal(URL)
            expect(heartbeat.resolve("https://www.sentivel.com/api/heartbeat/" .. string.upper(TOKEN))).to.equal(URL)
        end)

        it("takes a link pasted without its scheme", function()
            expect(heartbeat.resolve("www.sentivel.com/api/heartbeat/" .. TOKEN)).to.equal(URL)
            expect(heartbeat.resolve("sentivel.com/api/heartbeat/" .. TOKEN)).to.equal(URL)
        end)

        it("reads the default port and a trailing dot as the same host", function()
            expect(heartbeat.resolve("https://www.sentivel.com:443/api/heartbeat/" .. TOKEN)).to.equal(URL)
            expect(heartbeat.resolve("https://www.sentivel.com./api/heartbeat/" .. TOKEN)).to.equal(URL)
        end)

        it("strips the no-break and zero-width spaces a copy drags along", function()
            expect(heartbeat.resolve("\194\160" .. URL .. "\194\160")).to.equal(URL)
            expect(heartbeat.resolve("\226\128\139" .. TOKEN .. "\239\187\191")).to.equal(URL)
        end)

        it("refuses something far too long to be a link, without chewing on it", function()
            local url, reason = heartbeat.resolve(string.rep(" ", 200000) .. TOKEN)
            expect(url).never.to.be.ok()
            expect(string.find(reason, "too long", 1, true)).to.be.ok()
        end)

        it("refuses another port", function()
            local url = heartbeat.resolve("https://www.sentivel.com:8443/api/heartbeat/" .. TOKEN)
            expect(url).never.to.be.ok()
        end)

        it("refuses anything that is not a string", function()
            local url, reason = heartbeat.resolve(nil)
            expect(url).never.to.be.ok()
            expect(reason).to.equal("heartbeat takes your Sentivel ping URL or token as a string, got nil")

            local _, numeric = heartbeat.resolve(12345)
            expect(numeric).to.equal("heartbeat takes your Sentivel ping URL or token as a string, got number")
        end)

        it("refuses an empty link", function()
            local url, reason = heartbeat.resolve("   ")
            expect(url).never.to.be.ok()
            expect(string.find(reason, "empty", 1, true)).to.be.ok()
        end)

        it("refuses every host but Sentivel", function()
            for _, target in
                {
                    "https://example.com/api/heartbeat/" .. TOKEN,
                    "https://sentivel.com.evil.io/api/heartbeat/" .. TOKEN,
                    "https://evil.io/?https://www.sentivel.com/api/heartbeat/" .. TOKEN,
                    "https://user@www.sentivel.com/api/heartbeat/" .. TOKEN,
                    "ftp://www.sentivel.com/api/heartbeat/" .. TOKEN,
                }
            do
                local url, reason = heartbeat.resolve(target)
                expect(url).never.to.be.ok()
                expect(reason).to.equal("heartbeat only pings Sentivel. Use the ping URL from your heartbeat monitor")
            end
        end)

        it("refuses a Sentivel link that is not a ping URL", function()
            for _, target in
                {
                    "https://www.sentivel.com/",
                    "https://www.sentivel.com",
                    "https://www.sentivel.com/dashboard/monitors/" .. TOKEN,
                    "https://www.sentivel.com/api/heartbeat/" .. TOKEN .. "/extra",
                    "https://www.sentivel.com/api/heartbeat/" .. TOKEN .. "?status=up",
                }
            do
                local url, reason = heartbeat.resolve(target)
                expect(url).never.to.be.ok()
                expect(string.find(reason, "isn't a heartbeat ping URL", 1, true)).to.be.ok()
            end
        end)

        it("spots a monitor ID pasted in place of the ping URL", function()
            local url, reason = heartbeat.resolve("fe297588-5f4d-4c45-ba97-0715cf36e8fc")
            expect(url).never.to.be.ok()
            expect(string.find(reason, "monitor ID", 1, true)).to.be.ok()
        end)

        it("refuses a token that is cut short or not hex", function()
            for _, target in { string.sub(TOKEN, 1, 20), "not-a-token", string.rep("z", 64), string.rep("a", 129) } do
                local url, reason = heartbeat.resolve(target)
                expect(url).never.to.be.ok()
                expect(reason).to.be.ok()
            end
        end)
    end)

    describe("utility.heartbeat start", function()
        local originalWarn
        local warnings

        beforeEach(function()
            originalWarn = log.warn
            warnings = {}
            log.warn = function(message)
                table.insert(warnings, message)
            end
        end)

        afterEach(function()
            log.warn = originalWarn
        end)

        it("pings on open, then once a period for as long as the window is up", function()
            local spawned = 0
            local env, sent, waits = fakeEnvironment({
                spawn = function(callback)
                    spawned += 1
                    callback()
                end,
            })

            expect(heartbeat.start(TOKEN, aliveFor(3), env)).to.equal(true)
            expect(spawned).to.equal(1)
            expect(#sent).to.equal(3)
            for _, url in sent do
                expect(url).to.equal(URL)
            end
            expect(#waits).to.equal(3)
            expect(waits[1]).to.equal(heartbeat.period)
            expect(#warnings).to.equal(0)
        end)

        it("paces pings five minutes apart", function()
            expect(heartbeat.period).to.equal(300)
        end)

        it("sends nothing once the window is gone", function()
            local env, sent = fakeEnvironment()

            expect(heartbeat.start(TOKEN, aliveFor(0), env)).to.equal(true)
            expect(#sent).to.equal(0)
        end)

        it("keeps going through a ping that throws", function()
            local calls = 0
            local env = fakeEnvironment({
                get = function()
                    calls += 1
                    error("HTTP 500 (Internal Server Error)")
                end,
            })

            expect(heartbeat.start(URL, aliveFor(2), env)).to.equal(true)
            expect(calls).to.equal(2)
            expect(#warnings).to.equal(0)
        end)

        it("keeps going through other failures Sentivel reports", function()
            local calls = 0
            local env = fakeEnvironment({
                get = function()
                    calls += 1
                    return 503
                end,
            })

            heartbeat.start(URL, aliveFor(3), env)
            expect(calls).to.equal(3)
            expect(#warnings).to.equal(0)
        end)

        it("stops, and says so, when Sentivel doesn't know the token", function()
            local calls = 0
            local env = fakeEnvironment({
                get = function()
                    calls += 1
                    return 404
                end,
            })

            expect(heartbeat.start(URL, aliveFor(10), env)).to.equal(true)
            expect(calls).to.equal(heartbeat.giveUpAfter)
            expect(#warnings).to.equal(1)
            expect(string.find(warnings[1], "doesn't recognise", 1, true)).to.be.ok()
        end)

        it("hands a link to the newest window, so a rebuilt window isn't turned away", function()
            -- the first window's loop is parked in its wait when the second one starts
            local parked
            local env, sent = fakeEnvironment({
                spawn = function(callback)
                    if parked == nil then
                        parked = coroutine.create(callback)
                        coroutine.resume(parked)
                    else
                        callback()
                    end
                end,
                wait = function()
                    if coroutine.running() == parked then
                        coroutine.yield()
                    end
                end,
            })

            expect(heartbeat.start(TOKEN, function()
                return true
            end, env)).to.equal(true)
            expect(#sent).to.equal(1)

            -- the second window takes the link over and pings straight away
            expect(heartbeat.start(URL, aliveFor(2), env)).to.equal(true)
            expect(#sent).to.equal(3)

            -- the first loop wakes, sees it no longer owns the link, and retires without a ping
            coroutine.resume(parked)
            expect(coroutine.status(parked)).to.equal("dead")
            expect(#sent).to.equal(3)
        end)

        it("rides out a stray 404, since only a run of them means the token is gone", function()
            local answers = { 404, 404, 200, 404, 404, 200 }
            local calls = 0
            local env = fakeEnvironment({
                get = function()
                    calls += 1
                    return answers[calls]
                end,
            })

            heartbeat.start(URL, aliveFor(#answers), env)
            expect(calls).to.equal(#answers)
            expect(#warnings).to.equal(0)
        end)

        it("doesn't count a ping that threw toward giving up", function()
            local calls = 0
            local env = fakeEnvironment({
                get = function()
                    calls += 1
                    if calls % 2 == 0 then
                        error("timeout")
                    end
                    return 404
                end,
            })

            heartbeat.start(URL, aliveFor(6), env)
            expect(calls).to.equal(6)
            expect(#warnings).to.equal(0)
        end)

        it("warns once and starts nothing for a bad link", function()
            local env, sent = fakeEnvironment()

            expect(heartbeat.start("https://example.com/api/heartbeat/" .. TOKEN, aliveFor(5), env)).to.equal(false)
            expect(#sent).to.equal(0)
            expect(#warnings).to.equal(1)
            expect(warnings[1]).to.equal(
                "Rayfield: heartbeat only pings Sentivel. Use the ping URL from your heartbeat monitor."
            )
        end)

        it("stays quiet in Studio, where runs are playtests", function()
            local env, sent = fakeEnvironment({ isStudio = true })

            expect(heartbeat.start(TOKEN, aliveFor(5), env)).to.equal(false)
            expect(#sent).to.equal(0)
            expect(#warnings).to.equal(0)
        end)

        it("still checks the link in Studio, so a typo shows up before release", function()
            local env = fakeEnvironment({ isStudio = true })

            expect(heartbeat.start("oops", aliveFor(5), env)).to.equal(false)
            expect(#warnings).to.equal(1)
        end)

        it("says so when the executor has no way to send it", function()
            local env = fakeEnvironment()
            env.get = nil

            expect(heartbeat.start(TOKEN, aliveFor(5), env)).to.equal(false)
            expect(#warnings).to.equal(1)
            expect(string.find(warnings[1], "HTTP function", 1, true)).to.be.ok()
        end)

        it("reads Studio from the live environment when none is passed", function()
            -- the spec runner reports Studio, so the live path must decline without sending
            expect(heartbeat.start(TOKEN, aliveFor(5))).to.equal(false)
            expect(#warnings).to.equal(0)
        end)
    end)

    describe("utility.heartbeat transport", function()
        it("prefers the executor request function, as a GET, and hands back the status", function()
            local received
            local get = heartbeat.transport({
                request = function(options)
                    received = options
                    return { StatusCode = 404, Body = "" }
                end,
            }, {})

            expect(get).to.be.ok()
            expect(get(URL)).to.equal(404)
            expect(received.Url).to.equal(URL)
            expect(received.Method).to.equal("GET")
        end)

        it("reads a status code handed back as a string", function()
            local get = heartbeat.transport({
                request = function()
                    return { StatusCode = "404" }
                end,
            }, {})
            expect(get(URL)).to.equal(404)
        end)

        it("reports no status when the request function returns nothing useful", function()
            local get = heartbeat.transport({
                request = function()
                    return nil
                end,
            }, {})
            expect(get(URL)).never.to.be.ok()

            local odd = heartbeat.transport({
                request = function()
                    return { StatusCode = "OK" }
                end,
            }, {})
            expect(odd(URL)).never.to.be.ok()
        end)

        it("falls back to HttpGet on the data model", function()
            local calledOn, calledWith
            local dataModel = {}
            dataModel.HttpGet = function(self, url)
                calledOn, calledWith = self, url
                return ""
            end

            local get = heartbeat.transport({}, dataModel)
            expect(get).to.be.ok()
            expect(get(URL)).never.to.be.ok()
            expect(calledOn).to.equal(dataModel)
            expect(calledWith).to.equal(URL)
        end)

        it("reads a 404 out of the error HttpGet throws, and swallows the rest", function()
            local message = "HTTP 404 (Not Found)"
            local dataModel = {}
            dataModel.HttpGet = function()
                error(message)
            end

            local get = heartbeat.transport({}, dataModel)
            expect(get(URL)).to.equal(404)
            message = "HTTP 503 (Service Unavailable)"
            expect(get(URL)).never.to.be.ok()
        end)

        it("survives a data model that throws on HttpGet", function()
            local locked = setmetatable({}, {
                __index = function()
                    error("HttpGet is not a valid member of DataModel")
                end,
            })

            expect(heartbeat.transport({}, locked)).never.to.be.ok()
        end)

        it("returns nil when there is nothing to send with", function()
            expect(heartbeat.transport({}, {})).never.to.be.ok()
        end)

        it("looks at the real environment and game when given neither", function()
            -- the runner has no executor request and a game with no HttpGet
            expect(heartbeat.transport()).never.to.be.ok()
        end)
    end)
end
