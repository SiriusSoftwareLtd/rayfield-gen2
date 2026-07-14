--!strict

local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local persistenceSettings = requireUtility("persistenceSettings")
    local filesystem = requireUtility("filesystem")
    local variables = requireUtility("variables")

    describe("utility.persistenceSettings", function()
        local originalFileSystemManager
        local originalHttpService
        local originalFilesystem
        local files: any
        local encodedData: any
        local decodedData: any
        local ensuredDir: any

        local function makeWindow(): any
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
        end)

        afterEach(function()
            variables.fileSystemManager = originalFileSystemManager
            variables.httpService = originalHttpService
            filesystem.ensureDir = originalFilesystem.ensureDir
            filesystem.writefile = originalFilesystem.writefile
            filesystem.isfile = originalFilesystem.isfile
            filesystem.readfile = originalFilesystem.readfile
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
                toggleKeybind = { tostring(Enum.KeyCode), Enum.KeyCode.RightControl.Value } :: { any },
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
    end)
end
