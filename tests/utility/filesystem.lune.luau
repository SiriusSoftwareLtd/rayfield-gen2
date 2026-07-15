--!strict

local helpers = ((_G :: any).__RAYFIELD_TEST_HELPERS or require(script.Parent.Parent.TestHelpers)) :: any
local requireUtility = helpers.requireUtility

return function()
    local filesystem = requireUtility("filesystem")

    describe("utility.filesystem", function()
        local rootName

        beforeEach(function()
            rootName = "Spec" .. tostring(os.clock()):gsub("%.", "")
        end)

        afterEach(function()
            if filesystem.isfolder(rootName) then
                filesystem.delfolder(rootName)
            end
        end)

        it("writes, reads, appends, and deletes files", function()
            local filePath = rootName .. "/nested/file.txt"

            filesystem.writefile(filePath, "alpha")
            expect(filesystem.isfile(filePath)).to.equal(true)
            expect(filesystem.readfile(filePath)).to.equal("alpha")

            filesystem.appendfile(filePath, "-beta")
            expect(filesystem.readfile(filePath)).to.equal("alpha-beta")

            filesystem.delfile(filePath)
            expect(filesystem.isfile(filePath)).never.to.be.ok()
        end)

        it("creates, lists, checks, and deletes folders", function()
            local folderPath = rootName .. "/children"
            filesystem.makefolder(folderPath)
            filesystem.writefile(folderPath .. "/a.txt", "a")
            filesystem.writefile(folderPath .. "/b.txt", "b")

            local files = filesystem.listfiles(folderPath)
            table.sort(files)

            expect(filesystem.isfolder(folderPath)).to.equal(true)
            expect(#files).to.equal(2)
            expect(files[1]).to.equal(folderPath .. "/a.txt")
            expect(files[2]).to.equal(folderPath .. "/b.txt")

            filesystem.delfolder(folderPath)
            expect(filesystem.isfolder(folderPath)).to.equal(false)
        end)

        it("ensures folders and directory chains", function()
            local folderPath = rootName .. "/assets"
            local dirPath = rootName .. "/one/two/three"

            filesystem.ensureFolder(folderPath)
            filesystem.ensureFolder(folderPath)
            filesystem.ensureDir(dirPath)

            expect(filesystem.isfolder(folderPath)).to.equal(true)
            expect(filesystem.isfolder(dirPath)).to.equal(true)
        end)

        it("reports missing files and folders", function()
            local readOk = pcall(filesystem.readfile, rootName .. "/missing.txt")
            local listOk = pcall(filesystem.listfiles, rootName .. "/missing")
            local deleteFileOk = pcall(filesystem.delfile, rootName .. "/missing.txt")
            local deleteFolderOk = pcall(filesystem.delfolder, rootName .. "/missing")

            expect(readOk).to.equal(false)
            expect(listOk).to.equal(false)
            expect(deleteFileOk).to.equal(false)
            expect(deleteFolderOk).to.equal(false)
            expect(filesystem.isfile("")).to.equal(false)
            expect(filesystem.isfolder("")).to.equal(false)
        end)
    end)
end
