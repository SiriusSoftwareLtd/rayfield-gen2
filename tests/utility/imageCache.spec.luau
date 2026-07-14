local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local imageCache = requireUtility("imageCache")
    local filesystem = requireUtility("filesystem")
    local variables = requireUtility("variables")
    local constants = requireUtility("constants")

    describe("utility.imageCache", function()
        local originalFilesystem
        local originalGetCustomAsset
        local originalAssetResolver
        local originalJsonDecode
        local originalWait
        local originalOnCached
        local files

        beforeEach(function()
            files = {}
            table.clear(imageCache.rewrites)
            originalOnCached = imageCache.onCached
            imageCache.onCached = nil

            originalFilesystem = {
                ensureFolder = filesystem.ensureFolder,
                isfile = filesystem.isfile,
                writefile = filesystem.writefile,
            }
            originalGetCustomAsset = getfenv().getcustomasset
            originalAssetResolver = {
                getAssetContentFromUrl = variables.assetResolver.getAssetContentFromUrl,
            }
            originalJsonDecode = variables.httpService.JSONDecode
            originalWait = task.wait

            filesystem.ensureFolder = function(path)
                files[path] = files[path] or true
            end
            filesystem.isfile = function(path)
                return type(files[path]) == "string"
            end
            filesystem.writefile = function(path, content)
                files[path] = content
            end
            variables.assetResolver.getAssetContentFromUrl = function(_, url)
                return "body:" .. tostring(url)
            end
            variables.httpService.JSONDecode = function()
                return {
                    data = {
                        {
                            state = "Completed",
                            imageUrl = "https://cdn.example/avatar.png",
                        },
                    },
                }
            end
            task.wait = function() end
        end)

        afterEach(function()
            table.clear(imageCache.rewrites)
            imageCache.onCached = originalOnCached
            filesystem.ensureFolder = originalFilesystem.ensureFolder
            filesystem.isfile = originalFilesystem.isfile
            filesystem.writefile = originalFilesystem.writefile
            getfenv().getcustomasset = originalGetCustomAsset
            variables.assetResolver.getAssetContentFromUrl = originalAssetResolver.getAssetContentFromUrl
            variables.httpService.JSONDecode = originalJsonDecode
            task.wait = originalWait
        end)

        it("returns all failures when custom assets are unavailable", function()
            getfenv().getcustomasset = nil
            local settled

            local ok, missing = imageCache.preload(function(failed)
                settled = failed
            end)

            expect(ok).to.equal(false)
            expect(missing).to.equal(settled)
        end)

        it("uses existing cached manifest icons", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            filesystem.isfile = function()
                return true
            end
            local settled

            local ok, missing = imageCache.preload(function(failed)
                settled = failed
            end)

            expect(ok).to.equal(true)
            expect(missing).to.equal(0)
            expect(settled).to.equal(0)
            expect(imageCache.rewrites[constants.icons.close]).to.be.ok()
        end)

        it("downloads missing manifest icons and reports settled failures", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            local cachedIds = {}
            imageCache.onCached = function(id)
                cachedIds[id] = true
            end
            local settled

            local ok, missing = imageCache.preload(function(failed)
                settled = failed
            end)

            expect(ok).to.equal(false)
            expect(missing).to.be.ok()
            expect(settled).to.equal(0)
            expect(cachedIds[constants.icons.close]).to.equal(true)
            expect(imageCache.rewrites[constants.icons.close]).to.be.ok()
        end)

        it("returns cached avatars from disk", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            filesystem.isfile = function(path)
                return path:match("avatar_42%.png$") ~= nil
            end

            expect(imageCache.avatar(42)).to.be.ok()
            expect(imageCache.avatar("42")).to.equal("")
        end)

        it("fetches avatars in the background and calls the ready callback", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            local readyUri

            expect(imageCache.avatar(99, function(uri)
                readyUri = uri
            end)).to.equal("")

            expect(readyUri).to.be.ok()
        end)

        it("ignores malformed thumbnail responses while polling avatars", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            local decodeCalls = 0
            variables.httpService.JSONDecode = function()
                decodeCalls += 1
                if decodeCalls == 1 then
                    error("malformed json")
                elseif decodeCalls == 2 then
                    return {
                        data = "not-a-list",
                    }
                elseif decodeCalls == 3 then
                    return {
                        data = {
                            "not-an-entry",
                        },
                    }
                end
                return {
                    data = {
                        {
                            state = "Completed",
                            imageUrl = "https://cdn.example/avatar.png",
                        },
                    },
                }
            end
            local readyUri

            expect(imageCache.avatar(101, function(uri)
                readyUri = uri
            end)).to.equal("")

            expect(decodeCalls).to.equal(4)
            expect(readyUri).to.be.ok()
        end)

        it("leaves avatars unresolved when thumbnail polling never completes", function()
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
            variables.httpService.JSONDecode = function()
                return {
                    data = {
                        {
                            state = "Pending",
                        },
                    },
                }
            end
            local readyUri = "not-called"

            expect(imageCache.avatar(100, function(uri)
                readyUri = uri
            end)).to.equal("")
            expect(readyUri).to.equal("not-called")
        end)
    end)
end
