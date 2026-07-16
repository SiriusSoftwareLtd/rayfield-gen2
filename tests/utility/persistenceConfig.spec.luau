local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local persistenceConfig = requireUtility("persistenceConfig")
    local filesystem = requireUtility("filesystem")
    local variables = requireUtility("variables")

    describe("utility.persistenceConfig", function()
        local originalFileSystemManager
        local originalHttpService
        local originalFilesystem
        local files
        local listedFiles
        local ensuredDir
        local encodedData
        local decodedData

        local function makeWindow()
            return {
                name = "Main Window",
                configuration = {
                    fileName = "Main",
                },
                controls = {},
                _loading = false,
            }
        end

        beforeEach(function()
            files = {}
            listedFiles = {}
            ensuredDir = nil
            encodedData = nil
            decodedData = {}

            originalFileSystemManager = variables.fileSystemManager
            originalHttpService = variables.httpService
            originalFilesystem = {
                ensureDir = filesystem.ensureDir,
                writefile = filesystem.writefile,
                isfile = filesystem.isfile,
                readfile = filesystem.readfile,
                listfiles = filesystem.listfiles,
                delfile = filesystem.delfile,
            }

            variables.fileSystemManager = {
                getPath = function(_, childPath)
                    return "Root/" .. childPath
                end,
            }
            variables.httpService = {
                JSONEncode = function(_, data)
                    encodedData = data
                    return "encoded-json"
                end,
                JSONDecode = function(_, _text)
                    return decodedData
                end,
            }

            filesystem.ensureDir = function(dir)
                ensuredDir = dir
            end
            filesystem.writefile = function(path, content)
                files[path] = content
            end
            filesystem.isfile = function(path)
                return files[path] ~= nil
            end
            filesystem.readfile = function(path)
                return files[path]
            end
            filesystem.listfiles = function()
                return listedFiles
            end
            filesystem.delfile = function(path)
                files[path] = nil
            end
        end)

        afterEach(function()
            variables.fileSystemManager = originalFileSystemManager
            variables.httpService = originalHttpService
            filesystem.ensureDir = originalFilesystem.ensureDir
            filesystem.writefile = originalFilesystem.writefile
            filesystem.isfile = originalFilesystem.isfile
            filesystem.readfile = originalFilesystem.readfile
            filesystem.listfiles = originalFilesystem.listfiles
            filesystem.delfile = originalFilesystem.delfile
        end)

        it("returns the same path helper as persistencePaths", function()
            local window = makeWindow()
            local dir, fullPath = persistenceConfig.getPath(window, "Alt")

            expect(dir).to.equal("Root/Configurations")
            expect(fullPath).to.equal("Root/Configurations/Alt.rfld")
        end)

        it("saves serializable controls and skips controls that fail serialization", function()
            local window = makeWindow()
            window.controls = {
                Alpha = {
                    _serialize = function()
                        return "serialized"
                    end,
                },
                Beta = {
                    value = 42,
                },
                Broken = {
                    _serialize = function()
                        error("cannot serialize")
                    end,
                },
            }

            expect(persistenceConfig.save(window)).to.equal(true)
            expect(ensuredDir).to.equal("Root/Configurations")
            expect(files["Root/Configurations/Main.rfld"]).to.equal("encoded-json")
            expect(encodedData.Alpha).to.equal("serialized")
            expect(encodedData.Beta).to.equal(42)
            expect(encodedData.Broken).never.to.be.ok()
        end)

        it("returns false when encoding fails", function()
            variables.httpService.JSONEncode = function()
                error("encode failed")
            end

            expect(persistenceConfig.save(makeWindow())).to.equal(false)
        end)

        it("returns false when writing fails", function()
            filesystem.writefile = function()
                error("write failed")
            end

            expect(persistenceConfig.save(makeWindow())).to.equal(false)
        end)

        it("parks a whole copy before it overwrites the real file", function()
            local written = {}
            filesystem.writefile = function(path, content)
                table.insert(written, path)
                files[path] = content
            end

            expect(persistenceConfig.save(makeWindow())).to.equal(true)
            expect(written[1]).to.equal("Root/Configurations/Main.rfld.saving")
            expect(written[2]).to.equal("Root/Configurations/Main.rfld")
            -- the parked copy goes once the real file is whole again
            expect(files["Root/Configurations/Main.rfld.saving"]).never.to.be.ok()
        end)

        it("leaves the real file alone when the parked copy reads back short", function()
            filesystem.readfile = function()
                return "truncated"
            end
            files["Root/Configurations/Main.rfld"] = "previous"

            expect(persistenceConfig.save(makeWindow())).to.equal(false)
            expect(files["Root/Configurations/Main.rfld"]).to.equal("previous")
        end)

        it("recovers from the parked copy when the real file is torn", function()
            local window = makeWindow()
            local setValue
            files["Root/Configurations/Main.rfld"] = "torn"
            files["Root/Configurations/Main.rfld.saving"] = "stored-json"
            variables.httpService.JSONDecode = function(_, text)
                if text == "torn" then
                    error("decode failed")
                end
                return { Alpha = 7 }
            end
            window.controls = {
                Alpha = {
                    Set = function(_, value)
                        setValue = value
                    end,
                },
            }

            expect(persistenceConfig.load(window)).to.equal(true)
            expect(setValue).to.equal(7)
            -- the wreck is replaced rather than backed up, nothing was lost
            expect(files["Root/Configurations/Main.rfld"]).to.equal("stored-json")
            expect(files["Root/Configurations/Main (Incorrect Format).rfld"]).never.to.be.ok()
            expect(files["Root/Configurations/Main.rfld.saving"]).never.to.be.ok()
        end)

        it("never resurrects a deleted config from a parked copy", function()
            local window = makeWindow()
            files["Root/Configurations/Main.rfld"] = "stored-json"
            files["Root/Configurations/Main.rfld.saving"] = "stored-json"

            expect(persistenceConfig.delete(window, "Main")).to.equal(true)
            expect(files["Root/Configurations/Main.rfld.saving"]).never.to.be.ok()
            expect(persistenceConfig.load(window)).to.equal(false)
        end)

        it("loads values through control deserializers and setters", function()
            local window = makeWindow()
            local setValue
            local deserialized
            local nilSet = "not-called"
            files["Root/Configurations/Main.rfld"] = "stored-json"
            decodedData = {
                Alpha = 7,
                Beta = "stored",
                NilControl = nil,
            }
            window.controls = {
                Alpha = {
                    Set = function(_, value)
                        setValue = value
                    end,
                },
                Beta = {
                    _deserialize = function(_, value)
                        deserialized = value
                    end,
                },
                NilControl = {
                    _canBeNil = true,
                    Set = function(_, value)
                        nilSet = value
                    end,
                },
                Missing = {
                    Set = function()
                        error("should not be called")
                    end,
                },
            }

            expect(persistenceConfig.load(window)).to.equal(true)
            expect(window._loading).to.equal(false)
            expect(setValue).to.equal(7)
            expect(deserialized).to.equal("stored")
            expect(nilSet).never.to.be.ok()
            -- kept so elements built after the load can still restore themselves
            expect(window._loadedConfig.Alpha).to.equal(7)
        end)

        it("applies a single control from a decoded config", function()
            local applied
            local deserialized
            persistenceConfig.applyTo({
                flag = "Alpha",
                Set = function(_, value)
                    applied = value
                end,
            }, 12)
            expect(applied).to.equal(12)

            -- a deserializer wins over Set when the control has one
            persistenceConfig.applyTo({
                flag = "Beta",
                _deserialize = function(_, value)
                    deserialized = value
                end,
                Set = function()
                    error("should not be called")
                end,
            }, "raw")
            expect(deserialized).to.equal("raw")

            -- nil is skipped unless the control opts in
            persistenceConfig.applyTo({
                flag = "Gamma",
                Set = function()
                    error("should not be called")
                end,
            }, nil)

            -- a throwing control is warned about, not propagated
            persistenceConfig.applyTo({
                flag = "Delta",
                Set = function()
                    error("boom")
                end,
            }, 1)
        end)

        it("backs up and deletes invalid configuration files", function()
            local window = makeWindow()
            files["Root/Configurations/Main.rfld"] = "not-json"
            variables.httpService.JSONDecode = function()
                error("decode failed")
            end

            expect(persistenceConfig.load(window)).to.equal(false)
            expect(files["Root/Configurations/Main (Incorrect Format).rfld"]).to.equal("not-json")
            expect(files["Root/Configurations/Main.rfld"]).never.to.be.ok()
        end)

        it("treats a scalar JSON root as an invalid file", function()
            local window = makeWindow()
            local applied = "not-called"
            files["Root/Configurations/Main.rfld"] = "5"
            decodedData = 5
            window.controls = {
                Alpha = {
                    Set = function(_, value)
                        applied = value
                    end,
                },
            }

            expect(persistenceConfig.load(window)).to.equal(false)
            expect(applied).to.equal("not-called")
            expect(files["Root/Configurations/Main (Incorrect Format).rfld"]).to.equal("5")
            expect(files["Root/Configurations/Main.rfld"]).never.to.be.ok()
        end)

        it("derives the backup name from the real config path", function()
            local window = makeWindow()
            -- getConfigPath sanitizes this to "My Hub.rfld"; the backup must match it
            window.configuration.fileName = "My: Hub"
            files["Root/Configurations/My Hub.rfld"] = "not-json"
            variables.httpService.JSONDecode = function()
                error("decode failed")
            end

            expect(persistenceConfig.load(window)).to.equal(false)
            expect(files["Root/Configurations/My Hub (Incorrect Format).rfld"]).to.equal("not-json")
        end)

        it("numbers each corrupt backup instead of overwriting the last", function()
            local window = makeWindow()
            variables.httpService.JSONDecode = function()
                error("decode failed")
            end

            files["Root/Configurations/Main.rfld"] = "first-wreck"
            expect(persistenceConfig.load(window)).to.equal(false)
            files["Root/Configurations/Main.rfld"] = "second-wreck"
            expect(persistenceConfig.load(window)).to.equal(false)

            -- the first backup is the salvageable one, it must survive the second corruption
            expect(files["Root/Configurations/Main (Incorrect Format).rfld"]).to.equal("first-wreck")
            expect(files["Root/Configurations/Main (Incorrect Format 2).rfld"]).to.equal("second-wreck")
        end)

        it("keeps an outer load's guard up when a control callback loads again", function()
            local window = makeWindow()
            local guardDuringNested
            local nested = false
            files["Root/Configurations/Main.rfld"] = "stored-json"
            files["Root/Configurations/Other.rfld"] = "stored-json"
            decodedData = { Alpha = 1 }
            window.controls = {
                Alpha = {
                    Set = function()
                        if nested then
                            return
                        end
                        nested = true
                        persistenceConfig.load(window, "Other")
                        guardDuringNested = window._loading
                    end,
                },
            }

            expect(persistenceConfig.load(window)).to.equal(true)
            -- the nested load used to drop the guard here, so the rest of the outer restore autosaved
            expect(guardDuringNested).to.equal(true)
            expect(window._loading).to.equal(false)
        end)

        it("resets the loading flag even when applying the config throws", function()
            local window = makeWindow()
            files["Root/Configurations/Main.rfld"] = "stored-json"
            decodedData = { Alpha = 1 }
            -- iterating the controls throws; the flag must still come back down
            window.controls = setmetatable({}, {
                __iter = function()
                    error("iteration failed")
                end,
            })

            expect(persistenceConfig.load(window)).to.equal(true)
            expect(window._loading).to.equal(false)
        end)

        it("returns false from load and delete when no file API exists", function()
            filesystem.isfile = nil

            expect(persistenceConfig.load(makeWindow())).to.equal(false)
            expect(persistenceConfig.delete(makeWindow(), "Main")).to.equal(false)
        end)

        it("carries forward loaded flags no current control owns", function()
            local window = makeWindow()
            window.controls = {
                Alpha = { value = 1 },
            }
            -- Late's element isn't built yet; Alpha's control must still win over its old value
            window._loadedConfig = { Late = "saved", Alpha = "stale" }
            window._loadedConfigPath = "Root/Configurations/Main.rfld"

            expect(persistenceConfig.save(window)).to.equal(true)
            expect(encodedData.Late).to.equal("saved")
            expect(encodedData.Alpha).to.equal(1)
        end)

        it("only carries loaded flags into the config they came from", function()
            local window = makeWindow()
            files["Root/Configurations/A.rfld"] = "stored-json"
            decodedData = { Late = "saved" }

            expect(persistenceConfig.load(window, "A")).to.equal(true)

            -- saving somewhere else must not smuggle A's unbuilt flags into B
            expect(persistenceConfig.save(window, "B")).to.equal(true)
            expect(encodedData.Late).never.to.be.ok()

            expect(persistenceConfig.save(window, "A")).to.equal(true)
            expect(encodedData.Late).to.equal("saved")
        end)

        it("returns false when the configuration file is missing or unreadable", function()
            expect(persistenceConfig.load(makeWindow())).to.equal(false)

            files["Root/Configurations/Main.rfld"] = "stored-json"
            filesystem.readfile = function()
                error("read failed")
            end

            expect(persistenceConfig.load(makeWindow())).to.equal(false)
        end)

        it("lists saved configurations in deterministic order", function()
            listedFiles = {
                "Root/Configurations/zeta.rfld",
                "Root/Configurations/Beta (Incorrect Format).rfld",
                "Root/Configurations/Beta (Incorrect Format 2).rfld",
                "Root/Configurations/alpha.rfld.saving",
                "Root/Configurations/alpha.rfld",
            }

            local names = persistenceConfig.list(makeWindow())

            expect(table.concat(names, ",")).to.equal("alpha,zeta")
        end)

        it("returns an empty list when listing files fails", function()
            filesystem.listfiles = function()
                error("list failed")
            end

            local names = persistenceConfig.list(makeWindow())

            expect(#names).to.equal(0)
        end)

        it("deletes saved configurations and rejects invalid delete requests", function()
            local window = makeWindow()
            files["Root/Configurations/Main.rfld"] = "stored-json"

            expect(persistenceConfig.delete(window, "")).to.equal(false)
            expect(persistenceConfig.delete(window, "Missing")).to.equal(false)
            expect(persistenceConfig.delete(window, "Main")).to.equal(true)
            expect(files["Root/Configurations/Main.rfld"]).never.to.be.ok()
        end)
    end)
end
