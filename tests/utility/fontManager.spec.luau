local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local fontManager = requireUtility("fontManager")
    local filesystem = requireUtility("filesystem")

    describe("utility.fontManager", function()
        local originalFilesystem
        local originalHttpService
        local originalGetCustomAsset
        local originalFontNew
        local files
        local folders
        local fallback
        -- a real face body starts with a font signature; anything else never reaches disk
        local fontBinary = "\0\1\0\0font-binary"

        beforeEach(function()
            files = {}
            folders = {}
            fallback = Font.fromEnum(Enum.Font.SourceSans)

            originalFilesystem = {
                ensureFolder = filesystem.ensureFolder,
                isfile = filesystem.isfile,
                readfile = filesystem.readfile,
                writefile = filesystem.writefile,
                delfile = filesystem.delfile,
            }
            originalHttpService = {
                JSONDecode = game:GetService("HttpService").JSONDecode,
                JSONEncode = game:GetService("HttpService").JSONEncode,
            }
            originalGetCustomAsset = getfenv().getcustomasset
            originalFontNew = Font.new

            filesystem.ensureFolder = function(path)
                folders[path] = true
            end
            filesystem.isfile = function(path)
                return files[path] ~= nil
            end
            filesystem.readfile = function(path)
                return files[path]
            end
            filesystem.writefile = function(path, content)
                files[path] = content
            end
            filesystem.delfile = function(path)
                files[path] = nil
            end

            game:GetService("HttpService").JSONDecode = function()
                return {
                    name = "SpecFont",
                    faces = {
                        {
                            name = "Regular",
                            weight = 400,
                            style = "normal",
                            assetId = "rbxassetid://456",
                        },
                    },
                }
            end
            game:GetService("HttpService").JSONEncode = function(_, data)
                expect(data.name).to.equal("SpecFont")
                return "encoded-manifest"
            end
            getfenv().getcustomasset = function(path)
                return "asset://" .. path
            end
        end)

        afterEach(function()
            filesystem.ensureFolder = originalFilesystem.ensureFolder
            filesystem.isfile = originalFilesystem.isfile
            filesystem.readfile = originalFilesystem.readfile
            filesystem.writefile = originalFilesystem.writefile
            filesystem.delfile = originalFilesystem.delfile
            game:GetService("HttpService").JSONDecode = originalHttpService.JSONDecode
            game:GetService("HttpService").JSONEncode = originalHttpService.JSONEncode
            getfenv().getcustomasset = originalGetCustomAsset
            Font.new = originalFontNew
        end)

        local function makeManager(useCache)
            return fontManager.new("Fonts", false, useCache, nil, {
                saveToDisk = true,
                skipCache = not useCache,
                fallbackFont = fallback,
            })
        end

        it("creates managers with cache and fallback options", function()
            local manager = makeManager(true)

            expect(folders.Fonts).to.equal(true)
            expect(manager.rootFolder).to.equal("Fonts")
            expect(manager.defaultOptions.fallbackFont).to.equal(fallback)
            expect(type(manager.fontCache)).to.equal("table")
        end)

        it("returns fallback fonts for invalid ids or disabled disk saving", function()
            local manager = makeManager(true)

            expect(manager:loadFont(nil)).to.equal(fallback)
            expect(manager:resolve("not-a-number")).never.to.be.ok()

            manager.assetResolver.resolve = function(_, id)
                return id
            end
            expect(manager:loadFont(123, nil, nil, false, true)).to.equal(fallback)
        end)

        it("resolves cached fonts and creates missing cached variants", function()
            local manager = makeManager(true)
            local regular = Font.new("asset://regular", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
            manager.fontCache[123] = {
                customId = "asset://regular",
                manifest = {},
                loadedFromDisk = true,
                variants = {
                    [tostring(Enum.FontWeight.Regular) .. "|" .. tostring(Enum.FontStyle.Normal)] = regular,
                },
            }
            manager.assetResolver.resolve = function(_, id)
                return id
            end

            expect(manager[123]).to.equal(regular)
            expect(manager:resolve(123)).to.equal(regular)
            expect(manager:getFontFromId(123)).to.equal(regular)

            local bold = manager:loadFont(123, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
            expect(bold.Family).to.equal("asset://regular")
            expect(
                manager.fontCache[123].variants[tostring(Enum.FontWeight.Bold) .. "|" .. tostring(Enum.FontStyle.Normal)]
            ).to.equal(bold)
        end)

        it("drops corrupt cached fonts and falls back", function()
            local manager = makeManager(true)
            manager.assetResolver.resolve = function(_, id)
                return id
            end
            manager.fontCache[123] = {
                customId = "asset://broken",
                manifest = {},
                loadedFromDisk = true,
                variants = {},
            }
            Font.new = function()
                error("font failed")
            end

            expect(manager:loadFont(123)).to.equal(fallback)
            expect(manager.fontCache[123]).never.to.be.ok()
        end)

        it("loads manifests, localizes faces, writes a local manifest, and caches the font", function()
            local manager = makeManager(true)
            manager._debug = false
            files["Fonts/123.json"] = "stored-manifest"
            manager.assetResolver.resolve = function(_, id)
                return tonumber(id) or 456
            end
            manager.assetResolver.getAssetContentFromId = function(_, id)
                expect(id).to.equal(456)
                return fontBinary
            end

            local loaded = manager:loadFont("123")

            expect(loaded.Family).to.equal("asset://Fonts/SpecFont/manifest.json")
            expect(files["Fonts/SpecFont/Regular.ttf"]).to.equal(fontBinary)
            expect(files["Fonts/SpecFont/manifest.json"]).to.equal("encoded-manifest")
            expect(
                manager.fontCache[123].variants[tostring(Enum.FontWeight.Regular) .. "|" .. tostring(
                    Enum.FontStyle.Normal
                )]
            ).to.equal(loaded)
        end)

        it("returns the fallback when the manifest shape is invalid and drops the cached file", function()
            local manager = makeManager(true)
            manager._debug = false
            files["Fonts/123.json"] = "stored-manifest"
            game:GetService("HttpService").JSONDecode = function()
                return { name = "NoFaces" }
            end

            expect(manager:loadFont(123)).to.equal(fallback)
            -- a poisoned cached manifest would otherwise be re-read (and fail) forever
            expect(files["Fonts/123.json"]).never.to.be.ok()
        end)

        it("only writes a downloaded manifest to disk once it validates", function()
            local manager = makeManager(true)
            manager._debug = false
            manager.assetResolver.resolve = function(_, id)
                return tonumber(id) or 456
            end
            manager.assetResolver.getAssetContentFromId = function(_, id)
                return if id == 123 then "downloaded-manifest" else fontBinary
            end

            -- invalid body: nothing may land on disk
            game:GetService("HttpService").JSONDecode = function()
                return { name = "NoFaces" }
            end
            expect(manager:loadFont(123)).to.equal(fallback)
            expect(files["Fonts/123.json"]).never.to.be.ok()

            -- valid body: cached for the next session
            game:GetService("HttpService").JSONDecode = function()
                return {
                    name = "SpecFont",
                    faces = {
                        { name = "Regular", weight = 400, style = "normal", assetId = "rbxassetid://456" },
                    },
                }
            end
            expect(manager:loadFont(123, nil, nil, nil, true)).never.to.equal(fallback)
            expect(files["Fonts/123.json"]).to.equal("downloaded-manifest")
        end)

        it("returns the fallback when no file API exists", function()
            local manager = makeManager(true)
            manager._debug = false
            manager.assetResolver.resolve = function(_, id)
                return tonumber(id) or 456
            end
            filesystem.isfile = nil

            expect(manager:loadFont(123)).to.equal(fallback)
        end)

        it("sanitizes hostile manifest names before touching disk", function()
            local manager = makeManager(true)
            manager._debug = false
            files["Fonts/123.json"] = "stored-manifest"
            game:GetService("HttpService").JSONDecode = function()
                return {
                    name = "../../escape",
                    faces = {
                        { name = "../Regular", weight = 400, style = "normal", assetId = "rbxassetid://456" },
                    },
                }
            end
            game:GetService("HttpService").JSONEncode = function()
                return "encoded-manifest"
            end
            manager.assetResolver.resolve = function(_, id)
                return tonumber(id) or 456
            end
            manager.assetResolver.getAssetContentFromId = function()
                return fontBinary
            end

            manager:loadFont(123)

            expect(files["Fonts/escape/Regular.ttf"]).to.equal(fontBinary)
            for storedPath in files do
                expect(storedPath:find("%.%.")).never.to.be.ok()
            end
        end)

        it("rejects face bodies that arent fonts instead of writing them to disk", function()
            local manager = makeManager(true)
            manager._debug = false
            files["Fonts/123.json"] = "stored-manifest"
            manager.assetResolver.resolve = function(_, id)
                return tonumber(id) or 456
            end
            manager.assetResolver.getAssetContentFromId = function()
                return "<html>error page</html>"
            end

            -- a poisoned .ttf is never re-downloaded (we only fetch when the file is missing),
            -- so writing one would break the font for every session after
            expect(manager:loadFont(123)).to.equal(fallback)
            expect(files["Fonts/SpecFont/Regular.ttf"]).never.to.be.ok()
            expect(files["Fonts/SpecFont/manifest.json"]).never.to.be.ok()
        end)

        it("accepts every font signature we know", function()
            for _, signature in { "\0\1\0\0", "OTTO", "true", "ttcf", "wOFF", "wOF2" } do
                local manager = makeManager(true)
                manager._debug = false
                files = {}
                files["Fonts/123.json"] = "stored-manifest"
                manager.assetResolver.resolve = function(_, id)
                    return tonumber(id) or 456
                end
                manager.assetResolver.getAssetContentFromId = function()
                    return signature .. "rest-of-the-face"
                end

                expect(manager:loadFont(123)).never.to.equal(fallback)
                expect(files["Fonts/SpecFont/Regular.ttf"]).to.equal(signature .. "rest-of-the-face")
            end
        end)

        it("returns the fallback when a face cannot be made local", function()
            local manager = makeManager(true)
            manager._debug = false
            files["Fonts/123.json"] = "stored-manifest"
            manager.assetResolver.resolve = function(_, id)
                return tonumber(id) or 456
            end
            manager.assetResolver.getAssetContentFromId = function()
                return fontBinary
            end
            getfenv().getcustomasset = function(assetPath)
                if assetPath:find("%.ttf$") then
                    error("no capability")
                end
                return "asset://" .. assetPath
            end

            -- a partial failure must not fall back to the remote asset id: that fetch is
            -- exactly what secure mode exists to prevent
            expect(manager:loadFont(123)).to.equal(fallback)
            expect(files["Fonts/SpecFont/manifest.json"]).never.to.be.ok()
        end)
    end)
end
