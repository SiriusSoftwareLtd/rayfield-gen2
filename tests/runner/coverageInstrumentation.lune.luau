--!strict

local helpers = ((_G :: any).__RAYFIELD_TEST_HELPERS or require(script.Parent.Parent.TestHelpers)) :: any

return function()
    describe("coverage instrumentation", function()
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

        it("fails loudly on unterminated long brackets", function()
            local ok, err = pcall(function()
                helpers.instrumentSource("tests/fixtures/broken-long-string.luau", "local value = [=[\n")
            end)

            expect(ok).to.equal(false)
            expect(tostring(err):find("unsupported unterminated long string") ~= nil).to.equal(true)
        end)
    end)
end
