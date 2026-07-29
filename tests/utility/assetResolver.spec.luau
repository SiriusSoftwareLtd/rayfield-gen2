local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local assetResolver = requireUtility("assetResolver")
    local network = requireUtility("network")
    local httpService = game:GetService("HttpService")

    describe("utility.assetResolver", function()
        local resolver
        local originalGetRequestFn
        local originalJsonEncode
        local originalJsonDecode
        local encodedValues

        beforeEach(function()
            resolver = assetResolver.new()
            originalGetRequestFn = network.getRequestFn
            originalJsonEncode = httpService.JSONEncode
            originalJsonDecode = httpService.JSONDecode
            encodedValues = {}
            httpService.JSONEncode = function(_, value)
                local token = "json:" .. tostring(#encodedValues + 1)
                table.insert(encodedValues, value)
                return token
            end
            httpService.JSONDecode = function(_, token)
                local index = tonumber(tostring(token):match("^json:(%d+)$"))
                if not index or encodedValues[index] == nil then
                    error("invalid json")
                end
                return encodedValues[index]
            end
        end)

        afterEach(function()
            network.getRequestFn = originalGetRequestFn
            httpService.JSONEncode = originalJsonEncode
            httpService.JSONDecode = originalJsonDecode
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

            resolver = assetResolver.new(true, "https://example.invalid/asset?id=%s")
            network.getRequestFn = function()
                return function(request)
                    calls += 1
                    lastRequest = request
                    return { StatusCode = 200, Body = "asset-body" }
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
            local lastRequest
            resolver = assetResolver.new(false, "https://example.invalid/asset?id=%s")
            network.getRequestFn = function()
                return function(request)
                    lastRequest = request
                    return { StatusCode = 200, Body = "asset-content" }
                end
            end

            expect(resolver:getAssetContentFromId("rbxassetid://456")).to.equal("asset-content")
            expect(lastRequest.Url).to.equal("https://example.invalid/asset?id=456")
            expect(lastRequest.Method).to.equal("GET")
            expect(lastRequest.Headers["X-Rayfield-Secure-Mode"]).to.equal("true")
        end)

        it("uses the custom proxy default and preserves decimal strings", function()
            local requestedUrls = {}
            network.getRequestFn = function()
                return function(request)
                    table.insert(requestedUrls, request.Url)
                    return { StatusCode = 200, Body = "asset-content" }
                end
            end

            expect(resolver:getAssetContentFromId("123")).to.equal("asset-content")
            expect(resolver:getAssetContentFromId("rbxassetid://12345678901234567890")).to.equal("asset-content")
            expect(requestedUrls[1]).to.equal("https://proxy.sirius.menu/assets/123")
            expect(requestedUrls[2]).to.equal("https://proxy.sirius.menu/assets/12345678901234567890")
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
            expect(resolver:getAssetContentFromId("rbxassetid://12x")).never.to.be.ok()
            expect(resolver:getAssetContentFromId("123456789012345678901")).never.to.be.ok()
            expect(resolver:getAssetContentFromId(1.5)).never.to.be.ok()
            expect(calls).to.equal(0)
        end)

        it("posts batch ids with secure headers and preserves result order", function()
            local lastRequest
            resolver = assetResolver.new(true, nil, "https://example.invalid/assets/batch")
            network.getRequestFn = function()
                return function(request)
                    lastRequest = request
                    return {
                        StatusCode = 200,
                        Body = httpService:JSONEncode({
                            results = {
                                { status = 200, dataBase64 = "b25l", cacheStatus = "miss", cacheHit = false },
                                { status = 404, error = "missing" },
                                { status = 200, dataBase64 = "dHdv" },
                            },
                        }),
                    }
                end
            end

            local results = resolver:getAssetContentsFromIds({ "1", "2", "rbxassetid://3" })
            local requestBody = httpService:JSONDecode(lastRequest.Body)

            expect(lastRequest.Url).to.equal("https://example.invalid/assets/batch")
            expect(lastRequest.Method).to.equal("POST")
            expect(lastRequest.Headers["X-Rayfield-Secure-Mode"]).to.equal("true")
            expect(requestBody.assetIds[1]).to.equal("1")
            expect(requestBody.assetIds[3]).to.equal("3")
            expect(results[1].content).to.equal("one")
            expect(results[2].content).never.to.be.ok()
            expect(results[2].status).to.equal(404)
            expect(results[2].error).to.equal("missing")
            expect(results[3].content).to.equal("two")
        end)

        it("chunks batch requests at 25 ids", function()
            local calls = 0
            local chunkSizes = {}
            local ids = {}
            for id = 1, 52 do
                table.insert(ids, tostring(id))
            end
            network.getRequestFn = function()
                return function(request)
                    calls += 1
                    local body = httpService:JSONDecode(request.Body)
                    table.insert(chunkSizes, #body.assetIds)
                    local items = {}
                    for _ in body.assetIds do
                        table.insert(items, { status = 200, dataBase64 = "eA==" })
                    end
                    return { StatusCode = 200, Body = httpService:JSONEncode({ results = items }) }
                end
            end

            local results = resolver:getAssetContentsFromIds(ids)

            expect(calls).to.equal(3)
            expect(chunkSizes[1]).to.equal(25)
            expect(chunkSizes[2]).to.equal(25)
            expect(chunkSizes[3]).to.equal(2)
            expect(results[52].content).to.equal("x")
        end)

        it("uses batch cache hits and bypasses them when forced", function()
            local calls = 0
            resolver = assetResolver.new(true)
            network.getRequestFn = function()
                return function()
                    calls += 1
                    return {
                        StatusCode = 200,
                        Body = httpService:JSONEncode({
                            results = {
                                { status = 200, dataBase64 = if calls == 1 then "b25l" else "dHdv" },
                            },
                        }),
                    }
                end
            end

            expect(resolver:getAssetContentsFromIds({ "7" })[1].content).to.equal("one")
            local cached = resolver:getAssetContentsFromIds({ "7" })[1]
            expect(cached.content).to.equal("one")
            expect(cached.cacheHit).to.equal(true)
            expect(resolver:getAssetContentsFromIds({ "7" }, true)[1].content).to.equal("two")
            expect(calls).to.equal(2)
        end)

        it("does not cache malformed outer batch responses or failed items", function()
            local calls = 0
            network.getRequestFn = function()
                return function()
                    calls += 1
                    if calls == 1 then
                        return { StatusCode = 200, Body = "not-json" }
                    elseif calls == 2 then
                        return {
                            StatusCode = 200,
                            Body = httpService:JSONEncode({
                                results = {
                                    { status = 500, error = "upstream", dataBase64 = "YmFk" },
                                },
                            }),
                        }
                    end
                    return {
                        StatusCode = 200,
                        Body = httpService:JSONEncode({
                            results = {
                                { status = 200, dataBase64 = "Z29vZA==" },
                            },
                        }),
                    }
                end
            end

            expect(resolver:getAssetContentsFromIds({ "8" })[1].content).never.to.be.ok()
            expect(resolver:getAssetContentsFromIds({ "8" })[1].content).never.to.be.ok()
            expect(resolver:getAssetContentsFromIds({ "8" })[1].content).to.equal("good")
            expect(calls).to.equal(3)
        end)

        it("rejects failed responses instead of caching their bodies", function()
            local responses = {
                { StatusCode = 404, Body = "<html>not found</html>" },
                { Success = false, Body = "rate limited" },
                { Body = "" },
                { Body = "no status of any kind" }, -- unknown shape, so we cant call it a success
                "not-a-table",
            }
            local call = 0

            resolver = assetResolver.new(true, "https://example.invalid/asset?id=%s")
            network.getRequestFn = function()
                return function()
                    call += 1
                    return responses[call]
                end
            end

            for index = 1, #responses do
                expect(resolver:getAssetContentFromUrl("https://example.invalid/raw", "key")).never.to.be.ok()
                expect(call).to.equal(index) -- a failure must not be cached, so every call refetches
            end
        end)

        it("accepts responses that report success", function()
            resolver = assetResolver.new(true, "https://example.invalid/asset?id=%s")
            network.getRequestFn = function()
                return function()
                    return { StatusCode = 200, Body = "good-body" }
                end
            end

            expect(resolver:getAssetContentFromUrl("https://example.invalid/raw", "ok")).to.equal("good-body")
        end)

        it("evicts the oldest cached bodies instead of growing forever", function()
            local calls = 0
            resolver = assetResolver.new(true, "https://example.invalid/asset?id=%s")
            network.getRequestFn = function()
                return function()
                    calls += 1
                    return { StatusCode = 200, Body = "body-" .. calls }
                end
            end

            -- well past the cap, so the first keys must have been dropped
            for key = 1, 32 do
                resolver:getAssetContentFromUrl("https://example.invalid/raw", key)
            end

            local held = 0
            for _ in resolver.contentCache do
                held += 1
            end
            expect(held).to.equal(8)
            expect(resolver.contentCache[1]).never.to.be.ok()
            expect(resolver.contentCache[32]).to.equal("body-32")

            -- an evicted key refetches, and a still-held one doesnt
            expect(resolver:getAssetContentFromUrl("https://example.invalid/raw", 1)).to.equal("body-33")
            expect(resolver:getAssetContentFromUrl("https://example.invalid/raw", 32)).to.equal("body-32")
            expect(calls).to.equal(33)
        end)

        it("bypasses the session cache when forced", function()
            local calls = 0
            resolver = assetResolver.new(true, "https://example.invalid/asset?id=%s")
            network.getRequestFn = function()
                return function()
                    calls += 1
                    return { StatusCode = 200, Body = "body-" .. calls }
                end
            end

            expect(resolver:getAssetContentFromUrl("https://example.invalid/raw", "key")).to.equal("body-1")
            expect(resolver:getAssetContentFromUrl("https://example.invalid/raw", "key")).to.equal("body-1")
            expect(resolver:getAssetContentFromUrl("https://example.invalid/raw", "key", true)).to.equal("body-2")
            expect(calls).to.equal(2)
        end)
    end)
end
