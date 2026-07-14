--!nocheck

-- Unit tests for Rayfield's pure utilities. They use Roblox globals (Color3, ColorSequence, ...) so
-- they run in a Roblox host (Studio, or a runner), not the static check gate. Pass the Rayfield
-- module in and call it:
--
--   local passed, failed, report = require(path.to.spec)(game.ReplicatedStorage.Rayfield)
--
-- Returns (passed, failed, report). Extend as pure utilities grow; the 1.1 work is wiring this into
-- TestEZ + CI and covering the components / secure-mode paths (which need executor globals).

return function(rayfield)
    local path = require(rayfield.utility.path)
    local flagNames = require(rayfield.utility.flagNames)
    local colors = require(rayfield.utility.colors)
    local assetResolver = require(rayfield.utility.assetResolver)
    local image = require(rayfield.utility.image)

    local passed, failed, report = 0, 0, {}
    local function check(name, cond)
        if cond then
            passed += 1
        else
            failed += 1
            table.insert(report, "FAIL: " .. name)
        end
    end

    -- path
    check("join basic", path.join("a", "b") == "a/b")
    check("join empty child returns base", path.join("a", "") == "a")
    check("join nil child returns base", path.join("a", nil) == "a")
    check("sanitizeFile strips separators", path.sanitizeFile("a/b\\c") == "abc")
    check("sanitizeFile removes ..", not path.sanitizeFile("../x"):find("%.%."))
    check("sanitizeFolder removes ..", not path.sanitizeFolder("a/../b"):find("%.%."))
    check("basename takes the last segment", path.basename("a/b/c.rfld") == "c.rfld")
    check("basename passes a lone name", path.basename("solo") == "solo")

    -- flagNames
    check("deriveFlag joins words", flagNames.deriveFlagFromName("My Toggle") == "MyToggle")
    check("deriveFlag capitalises", flagNames.deriveFlagFromName("hello world") == "HelloWorld")
    check("deriveFlag drops symbols", flagNames.deriveFlagFromName("Auto-Farm!") == "AutoFarm")

    -- colors
    check("contrast on white is black", colors.contrastColor(Color3.new(1, 1, 1)) == Color3.fromRGB(0, 0, 0))
    check("contrast on black is white", colors.contrastColor(Color3.new(0, 0, 0)) == Color3.fromRGB(255, 255, 255))
    check("toColorSequence wraps a Color3", typeof(colors.toColorSequence(Color3.new(1, 0, 0))) == "ColorSequence")
    check(
        "toColorSequence passes a sequence through",
        typeof(colors.toColorSequence(ColorSequence.new(Color3.new(1, 0, 0)))) == "ColorSequence"
    )

    -- assetResolver.resolve (pure normalisation)
    local ar = assetResolver.new()
    check("resolve keeps a number", ar:resolve(123) == 123)
    check("resolve reads an rbxassetid string", ar:resolve("rbxassetid://456") == 456)
    check("resolve passes rbxasset through", ar:resolve("rbxasset://x") == "rbxasset://x")
    check("resolve rejects junk", ar:resolve({}) == nil)

    -- image.resolve outside secure mode
    check("image.resolve number to rbxassetid", image.resolve(123) == "rbxassetid://123")
    check("image.resolve passes rbxasset through", image.resolve("rbxasset://y") == "rbxasset://y")
    check("image.resolve treats zero as empty", image.resolve(0) == "")

    return passed, failed, table.concat(report, "\n")
end
