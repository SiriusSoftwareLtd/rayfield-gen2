local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local persistenceSettings = requireUtility("persistenceSettings")
    local filesystem = requireUtility("filesystem")
    local variables = requireUtility("variables")

    describe("utility.persistenceSettings", function()
        local originalFileSystemManager
        local originalHttpService
        local originalFilesystem
        local files
        local encodedData
        local decodedData
        local ensuredDir

        local function makeWindow()
            return {
                settings = {
                    toggleKeybind = Enum.KeyCode.RightShift,
                    mouseOverride = false,
                    keepOnScreen = true,
                    welcomeToast = false,
                    haptics = true,
                },
            }
        end

        beforeEach(function()
            files = {}
            encodedData = nil
            decodedData = {}
            ensuredDir = nil

            originalFileSystemManager = variables.fileSystemManager
            originalHttpService = variables.httpService
            originalFilesystem = {
                ensureDir = filesystem.ensureDir,
                writefile = filesystem.writefile,
                isfile = filesystem.isfile,
                readfile = filesystem.readfile,
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
                    return "settings-json"
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
            filesystem.delfile = originalFilesystem.delfile
        end)

        it("returns the shared settings path", function()
            local dir, fullPath = persistenceSettings.getSettingsPath()

            expect(dir).to.equal("Root/Settings")
            expect(fullPath).to.equal("Root/Settings/rayfield.rfld")
        end)

        it("saves settings to disk", function()
            expect(persistenceSettings.saveSettings(makeWindow())).to.equal(true)
            expect(ensuredDir).to.equal("Root/Settings")
            expect(files["Root/Settings/rayfield.rfld"]).to.equal("settings-json")
            expect(encodedData.toggleKeybind[1]).to.equal(tostring(Enum.KeyCode))
            expect(encodedData.toggleKeybind[2]).to.equal(Enum.KeyCode.RightShift.Value)
            expect(encodedData.keepOnScreen).to.equal(true)
            expect(encodedData.haptics).to.equal(true)
        end)

        it("parks a whole copy before it overwrites the real file", function()
            local written = {}
            filesystem.writefile = function(path, content)
                table.insert(written, path)
                files[path] = content
            end

            expect(persistenceSettings.saveSettings(makeWindow())).to.equal(true)
            expect(written[1]).to.equal("Root/Settings/rayfield.rfld.saving")
            expect(written[2]).to.equal("Root/Settings/rayfield.rfld")
            -- the parked copy goes once the real file is whole again
            expect(files["Root/Settings/rayfield.rfld.saving"]).never.to.be.ok()
        end)

        it("recovers settings from the parked copy when the real file is torn", function()
            local window = makeWindow()
            files["Root/Settings/rayfield.rfld"] = "torn"
            files["Root/Settings/rayfield.rfld.saving"] = "settings-json"
            variables.httpService.JSONDecode = function(_, text)
                if text == "torn" then
                    error("decode failed")
                end
                return { haptics = false }
            end

            expect(persistenceSettings.loadSettings(window)).to.equal(true)
            expect(window.settings.haptics).to.equal(false)
            -- and the wreck gets put right, so the next load reads it straight
            expect(files["Root/Settings/rayfield.rfld"]).to.equal("settings-json")
            expect(files["Root/Settings/rayfield.rfld.saving"]).never.to.be.ok()
        end)

        it("returns false when settings encoding or writing fails", function()
            variables.httpService.JSONEncode = function()
                error("encode failed")
            end
            expect(persistenceSettings.saveSettings(makeWindow())).to.equal(false)

            variables.httpService.JSONEncode = function()
                return "settings-json"
            end
            filesystem.writefile = function()
                error("write failed")
            end
            expect(persistenceSettings.saveSettings(makeWindow())).to.equal(false)
        end)

        it("loads persisted booleans and serialized enum keybinds", function()
            local window = makeWindow()
            files["Root/Settings/rayfield.rfld"] = "settings-json"
            decodedData = {
                toggleKeybind = { tostring(Enum.KeyCode), Enum.KeyCode.RightControl.Value },
                mouseOverride = true,
                keepOnScreen = false,
                welcomeToast = true,
                haptics = false,
            }

            expect(persistenceSettings.loadSettings(window)).to.equal(true)
            expect(window.settings.toggleKeybind).to.equal(Enum.KeyCode.RightControl)
            expect(window.settings.mouseOverride).to.equal(true)
            expect(window.settings.keepOnScreen).to.equal(false)
            expect(window.settings.welcomeToast).to.equal(true)
            expect(window.settings.haptics).to.equal(false)
        end)

        it("ignores non-boolean persisted settings", function()
            local window = makeWindow()
            files["Root/Settings/rayfield.rfld"] = "settings-json"
            decodedData = {
                mouseOverride = "yes",
                keepOnScreen = "no",
                welcomeToast = 1,
                haptics = 0,
            }

            expect(persistenceSettings.loadSettings(window)).to.equal(true)
            expect(window.settings.mouseOverride).to.equal(false)
            expect(window.settings.keepOnScreen).to.equal(true)
            expect(window.settings.welcomeToast).to.equal(false)
            expect(window.settings.haptics).to.equal(true)
        end)

        it("persists the last used config name", function()
            local window = makeWindow()
            window.settings.lastConfig = "PvP Loadout"

            expect(persistenceSettings.saveSettings(window)).to.equal(true)
            expect(encodedData.lastConfig).to.equal("PvP Loadout")
        end)

        it("restores the last used config name", function()
            local window = makeWindow()
            files["Root/Settings/rayfield.rfld"] = "settings-json"
            decodedData = { lastConfig = "PvP Loadout" }

            expect(persistenceSettings.loadSettings(window)).to.equal(true)
            expect(window.settings.lastConfig).to.equal("PvP Loadout")
        end)

        it("ignores a non-string last config", function()
            local window = makeWindow()
            window.settings.lastConfig = "keep"
            files["Root/Settings/rayfield.rfld"] = "settings-json"
            decodedData = { lastConfig = 42 }

            expect(persistenceSettings.loadSettings(window)).to.equal(true)
            expect(window.settings.lastConfig).to.equal("keep")
        end)

        it("returns false when settings are missing, unreadable, or invalid", function()
            expect(persistenceSettings.loadSettings(makeWindow())).to.equal(false)

            files["Root/Settings/rayfield.rfld"] = "settings-json"
            filesystem.readfile = function()
                error("read failed")
            end
            expect(persistenceSettings.loadSettings(makeWindow())).to.equal(false)

            filesystem.readfile = function(path)
                return files[path]
            end
            variables.httpService.JSONDecode = function()
                error("decode failed")
            end
            expect(persistenceSettings.loadSettings(makeWindow())).to.equal(false)
        end)

        it("rejects valid JSON whose root is not a table", function()
            local window = makeWindow()
            files["Root/Settings/rayfield.rfld"] = "settings-json"
            -- JSONDecode returns scalars for e.g. "5"; a corrupt file must not throw
            decodedData = 5

            expect(persistenceSettings.loadSettings(window)).to.equal(false)
            expect(window.settings.toggleKeybind).to.equal(Enum.KeyCode.RightShift)
        end)
    end)
end
