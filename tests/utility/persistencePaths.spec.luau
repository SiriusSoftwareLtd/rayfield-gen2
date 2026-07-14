local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local paths = requireUtility("persistencePaths")
    local variables = requireUtility("variables")

    describe("utility.persistencePaths", function()
        local originalFileSystemManager

        beforeEach(function()
            originalFileSystemManager = variables.fileSystemManager
            variables.fileSystemManager = {
                getPath = function(_, childPath)
                    return "Root/" .. childPath
                end,
            }
        end)

        afterEach(function()
            variables.fileSystemManager = originalFileSystemManager
        end)

        it("builds sanitized configuration paths with custom folders", function()
            local window = {
                name = "Window Name",
                configuration = {
                    customFolder = "Profiles/../Main",
                    fileName = "User/One",
                },
            }

            local dir, fullPath = paths.getConfigPath(window)

            expect(dir).to.equal("Root/Configurations/Profiles//Main")
            expect(fullPath).to.equal("Root/Configurations/Profiles//Main/UserOne.rfld")
        end)

        it("uses explicit configuration names before window defaults", function()
            local window = {
                name = "Window Name",
                configuration = {
                    fileName = "Default",
                },
            }

            local _, fullPath = paths.getConfigPath(window, "Named/Config")

            expect(fullPath).to.equal("Root/Configurations/NamedConfig.rfld")
        end)

        it("falls back to a default file name when sanitized names are empty", function()
            local window = {
                name = "..",
                configuration = {
                    fileName = "../",
                },
            }

            local _, fullPath = paths.getConfigPath(window)

            expect(fullPath).to.equal("Root/Configurations/Configuration.rfld")
        end)

        it("builds the shared settings path", function()
            local dir, fullPath = paths.getSettingsPath()

            expect(dir).to.equal("Root/Settings")
            expect(fullPath).to.equal("Root/Settings/rayfield.rfld")
        end)
    end)
end
