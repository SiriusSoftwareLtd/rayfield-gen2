local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestEZModule = ReplicatedStorage:FindFirstChild("TestEZ")
if not TestEZModule then
    error("ReplicatedStorage.TestEZ is required. Run `make test-place` or use the Avant Plugin to run .spec tests.")
end

local TestEZ = require(TestEZModule)
local testsRoot = ReplicatedStorage:WaitForChild("Tests")

local results = TestEZ.TestBootstrap:run({ testsRoot }, TestEZ.Reporters.TextReporter, {
    showTimingInfo = true,
})

if results.failureCount > 0 then
    error(string.format("%d TestEZ tests failed.", results.failureCount))
end
