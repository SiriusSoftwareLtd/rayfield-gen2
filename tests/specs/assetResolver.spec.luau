local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local assetResolver = requireUtility("assetResolver")
    local network = requireUtility("network")

    describe("utility.assetResolver", function()
        local resolver
        local originalGetRequestFn

        beforeEach(function()
            resolver = assetResolver.new()
            originalGetRequestFn = network.getRequestFn
        end)

        afterEach(function()
            network.getRequestFn = originalGetRequestFn
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

        it("downloads and caches asset content by cache key", function()
            local calls = 0
            local lastRequest

            resolver = assetResolver.new(true, "https://example.invalid/asset?id=%d")
            network.getRequestFn = function()
                return function(request)
                    calls += 1
                    lastRequest = request
                    return { Body = "asset-body" }
                end
            end

            expect(resolver:getAssetContentFromUrl("https://example.invalid/raw", 123)).to.equal("asset-body")
            expect(resolver:getAssetContentFromUrl("https://example.invalid/raw", 123)).to.equal("asset-body")
            expect(calls).to.equal(1)
            expect(lastRequest.Url).to.equal("https://example.invalid/raw")
            expect(lastRequest.Method).to.equal("GET")
        end)

        it("returns nil when no request function is available", function()
            network.getRequestFn = function()
                return nil
            end

            expect(resolver:getAssetContentFromUrl("https://example.invalid/raw", "missing")).never.to.be.ok()
        end)

        it("resolves asset content from ids with the configured download URL", function()
            local requestedUrl
            resolver = assetResolver.new(false, "https://example.invalid/asset?id=%d")
            network.getRequestFn = function()
                return function(request)
                    requestedUrl = request.Url
                    return { Body = "asset-content" }
                end
            end

            expect(resolver:getAssetContentFromId("rbxassetid://456")).to.equal("asset-content")
            expect(requestedUrl).to.equal("https://example.invalid/asset?id=456")
        end)

        it("rejects invalid asset content ids before requesting", function()
            local calls = 0
            network.getRequestFn = function()
                return function()
                    calls += 1
                    return { Body = "asset-content" }
                end
            end

            expect(resolver:getAssetContentFromId("not-an-asset")).never.to.be.ok()
            expect(calls).to.equal(0)
        end)
    end)
end
