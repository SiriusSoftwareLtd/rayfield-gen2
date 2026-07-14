--!strict

local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local filesystem = requireUtility("filesystem")
    local filesystemManager = requireUtility("filesystemManager")

    describe("utility.filesystemManager", function()
        local originalEnsureFolder
        local ensured

        beforeEach(function()
            ensured = {}
            originalEnsureFolder = filesystem.ensureFolder
            filesystem.ensureFolder = function(path)
                table.insert(ensured, path)
            end
        end)

        afterEach(function()
            filesystem.ensureFolder = originalEnsureFolder
        end)

        it("creates root and assets folders", function()
            local manager = filesystemManager.new("Root")

            expect(manager:getRootFolder()).to.equal("Root")
            expect(ensured[1]).to.equal("Root")
            expect(ensured[2]).to.equal("Root/Assets")
        end)

        it("joins paths under the configured root", function()
            local manager = filesystemManager.new("Root")

            expect(manager:getPath("Configurations")).to.equal("Root/Configurations")
        end)

        it("returns the base assets folder when no subfolder is provided", function()
            local manager = filesystemManager.new("Root")

            expect(manager:getAssetsFolder()).to.equal("Root/Assets")
        end)

        it("ensures and returns asset subfolders", function()
            local manager = filesystemManager.new("Root")

            expect(manager:getAssetsFolder("fonts")).to.equal("Root/Assets/fonts")
            expect(ensured[#ensured]).to.equal("Root/Assets/fonts")
        end)
    end)
end
