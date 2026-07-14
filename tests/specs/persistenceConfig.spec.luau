local function requireUtility(name)
    local loader = _G.__RAYFIELD_TEST_REQUIRE_UTILITY
    if loader then
        return loader(name)
    end

    return require(game:GetService("ReplicatedStorage").Rayfield.utility[name])
end

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
