local function requireUtility(name)
    local loader = _G.__RAYFIELD_TEST_REQUIRE_UTILITY
    if loader then
        return loader(name)
    end

    return require(game:GetService("ReplicatedStorage").Rayfield.utility[name])
end

return function()
    local image = requireUtility("image")
    local variables = requireUtility("variables")

    describe("utility.image", function()
        beforeEach(function()
            variables.secureMode = false
            image.onBlock = nil
            table.clear(image.pending)
        end)

        it("normalizes empty image values", function()
            expect(image.resolve(nil)).to.equal("")
            expect(image.resolve(0)).to.equal("")
            expect(image.resolve("")).to.equal("")
        end)

        it("converts numeric ids to rbxassetid URIs outside secure mode", function()
            expect(image.resolve(123)).to.equal("rbxassetid://123")
        end)

        it("passes Roblox asset and thumbnail URIs through outside secure mode", function()
            expect(image.resolve("rbxasset://textures/icon.png")).to.equal("rbxasset://textures/icon.png")
            expect(image.resolve("rbxthumb://type=AvatarHeadShot&id=1&w=48&h=48")).to.equal(
                "rbxthumb://type=AvatarHeadShot&id=1&w=48&h=48"
            )
            expect(image.resolve("rbxassetid://456")).to.equal("rbxassetid://456")
        end)

        it("uses cached rewrites before raw ids", function()
            image.rewrites[123] = "rbxasset://cached/icon.png"

            expect(image.resolve(123)).to.equal("rbxasset://cached/icon.png")

            image.rewrites[123] = nil
        end)
    end)
end
