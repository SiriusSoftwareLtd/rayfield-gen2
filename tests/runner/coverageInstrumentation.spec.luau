local helpers = (_G :: any).__RAYFIELD_TEST_HELPERS
local coverage = (_G :: any).__RAYFIELD_COVERAGE
local luau = require("@lune/luau") :: any

-- runs instrumented source with hit tracking wired up, returning whatever it returns
local function runInstrumented(path, instrumented, fileCoverage)
    coverage.files[path] = fileCoverage
    local chunk = luau.load(instrumented, {
        debugName = path,
        environment = { _G = _G },
    })
    return chunk()
end

return function()
    describe("coverage instrumentation", function()
        afterEach(function()
            coverage.files["tests/fixtures/instrumentation.luau"] = nil
        end)

        it("tracks long brackets while classifying coverable lines", function()
            local _instrumented, fileCoverage = helpers.instrumentSource(
                "tests/fixtures/instrumentation.luau",
                [===[
local value = [[
}
]]
local also = [=[
(
]=]
--[=[
{
]=]
if value
then
    value = value .. also
else
    value = "fallback"
end
local data = {
    alpha = 1,
    beta = 2,
}
return data
]===]
            )

            expect(fileCoverage.coverable[1]).to.equal(true)
            expect(fileCoverage.coverable[2]).never.to.be.ok()
            expect(fileCoverage.coverable[5]).never.to.be.ok()
            expect(fileCoverage.coverable[8]).never.to.be.ok()
            expect(fileCoverage.coverable[10]).to.equal(true)
            expect(fileCoverage.coverable[11]).never.to.be.ok()
            expect(fileCoverage.coverable[12]).to.equal(true)
            expect(fileCoverage.coverable[13]).never.to.be.ok()
            expect(fileCoverage.coverable[14]).to.equal(true)
            expect(fileCoverage.coverable[16]).to.equal(true)
            expect(fileCoverage.coverable[17]).never.to.be.ok()
            expect(fileCoverage.coverable[20]).to.equal(true)
        end)

        it("covers a multi-line Connect callback body only when it runs", function()
            local path = "tests/fixtures/instrumentation.luau"
            local instrumented, fileCoverage = helpers.instrumentSource(
                path,
                [===[
local stored = nil
local signal = {}
function signal.Connect(_, callback)
    stored = callback
end
signal:Connect(function()
    local ran = true
    return ran
end)
return stored
]===]
            )

            -- the body lines are coverable statements now, not swallowed by depth
            expect(fileCoverage.coverable[6]).to.equal(true)
            expect(fileCoverage.coverable[7]).to.equal(true)
            expect(fileCoverage.coverable[8]).to.equal(true)
            expect(fileCoverage.coverable[9]).never.to.be.ok()

            local callback = runInstrumented(path, instrumented, fileCoverage)

            -- registering the callback covers the registration line, not the body
            expect(fileCoverage.hits[6]).to.equal(true)
            expect(fileCoverage.hits[7]).never.to.be.ok()
            expect(fileCoverage.hits[8]).never.to.be.ok()

            callback()

            expect(fileCoverage.hits[7]).to.equal(true)
            expect(fileCoverage.hits[8]).to.equal(true)
        end)

        it("tracks nested function bodies at their own depth", function()
            local _instrumented, fileCoverage = helpers.instrumentSource(
                "tests/fixtures/instrumentation.luau",
                [===[
local runner = {}
runner.start = function(callback)
    callback(function()
        local inner = true
        return inner
    end)
end
runner.short(function() local one = 1 end)
return runner
]===]
            )

            expect(fileCoverage.coverable[2]).to.equal(true)
            expect(fileCoverage.coverable[3]).to.equal(true)
            expect(fileCoverage.coverable[4]).to.equal(true)
            expect(fileCoverage.coverable[5]).to.equal(true)
            expect(fileCoverage.coverable[6]).never.to.be.ok()
            expect(fileCoverage.coverable[7]).never.to.be.ok()
            -- a single-line body cant take a mid-line hit; the registration line is all we get
            expect(fileCoverage.coverable[8]).to.equal(true)
            expect(fileCoverage.coverable[9]).to.equal(true)
        end)

        it("keeps the context open across inner if/for blocks", function()
            local _instrumented, fileCoverage = helpers.instrumentSource(
                "tests/fixtures/instrumentation.luau",
                [===[
local signal = {}
signal.run(function()
    if true then
        local a = 1
    end
    for index = 1, 2 do
        local b = index
    end
    local pick = if a then 1 else 2
    local after = true
    return after
end)
return signal
]===]
            )

            expect(fileCoverage.coverable[3]).to.equal(true)
            expect(fileCoverage.coverable[4]).to.equal(true)
            expect(fileCoverage.coverable[6]).to.equal(true)
            expect(fileCoverage.coverable[7]).to.equal(true)
            -- inner ends and the expression if didnt pop the callback context
            expect(fileCoverage.coverable[9]).to.equal(true)
            expect(fileCoverage.coverable[10]).to.equal(true)
            expect(fileCoverage.coverable[11]).to.equal(true)
            expect(fileCoverage.coverable[12]).never.to.be.ok()
            expect(fileCoverage.coverable[13]).to.equal(true)
        end)

        it("skips long brackets inside a callback body", function()
            local _instrumented, fileCoverage = helpers.instrumentSource(
                "tests/fixtures/instrumentation.luau",
                [===[
local capture = {}
capture.run(function()
    local blob = [[
}) end
]]
    local after = blob
    return after
end)
]===]
            )

            expect(fileCoverage.coverable[3]).to.equal(true)
            expect(fileCoverage.coverable[4]).never.to.be.ok()
            expect(fileCoverage.coverable[5]).never.to.be.ok()
            expect(fileCoverage.coverable[6]).to.equal(true)
            expect(fileCoverage.coverable[7]).to.equal(true)
        end)

        it("fails loudly on unterminated long brackets", function()
            expect(function()
                helpers.instrumentSource("tests/fixtures/broken-long-string.luau", "local value = [=[\n")
            end).to.throw("unsupported unterminated long string")
        end)
    end)
end
