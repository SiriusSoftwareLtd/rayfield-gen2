local function requireUtility(name)
    local loader = _G.__RAYFIELD_TEST_REQUIRE_UTILITY
    if loader then
        return loader(name)
    end

    return require(game:GetService("ReplicatedStorage").Rayfield.utility[name])
end

return function()
    local assetResolver = requireUtility("assetResolver")

    describe("utility.assetResolver", function()
        local resolver

        beforeEach(function()
            resolver = assetResolver.new()
        end)

        it("keeps numeric asset ids", function()
            expect(resolver:resolve(123)).to.equal(123)
        end)

        it("parses rbxassetid strings", function()
            expect(resolver:resolve("rbxassetid://456")).to.equal(456)
        end)

        it("passes asset and thumbnail URIs through", function()
            expect(resolver:resolve("rbxasset://textures/icon.png")).to.equal("rbxasset://textures/icon.png")
            expect(resolver:resolve("rbxthumb://type=AvatarHeadShot&id=1&w=48&h=48")).to.equal(
                "rbxthumb://type=AvatarHeadShot&id=1&w=48&h=48"
            )
        end)

        it("rejects unsupported inputs", function()
            expect(resolver:resolve({})).never.to.be.ok()
            expect(resolver:resolve("not-an-asset")).never.to.be.ok()
        end)
    end)
end
