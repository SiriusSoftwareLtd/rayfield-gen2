local function requireUtility(name)
    local loader = _G.__RAYFIELD_TEST_REQUIRE_UTILITY
    if loader then
        return loader(name)
    end

    return require(game:GetService("ReplicatedStorage").Rayfield.utility[name])
end

return function()
    local image = requireUtility("image")
    local imageCache = requireUtility("imageCache")
    local variables = requireUtility("variables")

    describe("utility.image", function()
        local originalAvatar

        beforeEach(function()
            variables.secureMode = false
            image.onBlock = nil
            originalAvatar = imageCache.avatar
            table.clear(image.rewrites)
            table.clear(image.pending)
        end)

        afterEach(function()
            variables.secureMode = false
            image.onBlock = nil
            imageCache.avatar = originalAvatar
            table.clear(image.rewrites)
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

        it("returns avatar thumbnails directly outside secure mode", function()
            expect(image.avatar(99)).to.equal("rbxthumb://type=AvatarHeadShot&id=99&w=48&h=48")
        end)

        it("delegates avatar thumbnails to the secure cache in secure mode", function()
            local requestedUserId
            local requestedCallback
            variables.secureMode = true
            imageCache.avatar = function(userId, onReady)
                requestedUserId = userId
                requestedCallback = onReady
                return "cached-avatar"
            end

            local callback = function() end
            expect(image.avatar(42, callback)).to.equal("cached-avatar")
            expect(requestedUserId).to.equal(42)
            expect(requestedCallback).to.equal(callback)
        end)

        it("assigns non-image properties without resolving them", function()
            local instance = {}

            image.assign(instance, "Text", 123)

            expect(instance.Text).to.equal(123)
        end)

        it("tracks secure-mode image assignments until the asset is cached", function()
            variables.secureMode = true
            local instance = {
                Parent = {},
            }

            image.assign(instance, "Image", 321)

            expect(instance.Image).to.equal("")
            expect(image.pending[321][1].instance).to.equal(instance)
            expect(image.pending[321][1].property).to.equal("Image")

            image.rewrites[321] = "rbxasset://cached/icon.png"
            imageCache.onCached(321)

            expect(instance.Image).to.equal("rbxasset://cached/icon.png")
            expect(image.pending[321]).never.to.be.ok()
        end)

        it("blocks secure-mode thumbnails and reports the blocked value", function()
            local blocked
            variables.secureMode = true
            image.onBlock = function(value)
                blocked = value
            end

            expect(image.resolve("rbxthumb://type=AvatarHeadShot&id=1&w=48&h=48")).to.equal("")
            expect(blocked).to.equal("rbxthumb://type=AvatarHeadShot&id=1&w=48&h=48")
        end)

        it("reports unsupported values through the block hook", function()
            local blocked
            image.onBlock = function(value)
                blocked = value
            end

            local unsupported = {}
            expect(image.resolve(unsupported)).to.equal("")
            expect(blocked).to.equal(unsupported)
        end)
    end)
end
