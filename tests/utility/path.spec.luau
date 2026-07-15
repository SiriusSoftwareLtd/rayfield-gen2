local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local path = requireUtility("path")

    describe("utility.path", function()
        it("joins base and child paths", function()
            expect(path.join("a", "b")).to.equal("a/b")
        end)

        it("returns the base path for empty children", function()
            expect(path.join("a", "")).to.equal("a")
            expect(path.join("a", nil)).to.equal("a")
        end)

        it("sanitizes file names", function()
            expect(path.sanitizeFile("a/b\\c")).to.equal("abc")
            expect(path.sanitizeFile("../x"):find("%.%.")).never.to.be.ok()
        end)

        it("strips Windows-illegal characters from file names", function()
            expect(path.sanitizeFile('My<Hub>: "S3"|?*')).to.equal("MyHub S3")
            expect(path.sanitizeFile("tab\tand\nnewline")).to.equal("tabandnewline")
        end)

        it("sanitizes folder names", function()
            expect(path.sanitizeFolder("a/../b"):find("%.%.")).never.to.be.ok()
            expect(path.sanitizeFolder("a\\b")).to.equal("a/b")
        end)

        it("returns the basename", function()
            expect(path.basename("a/b/c.rfld")).to.equal("c.rfld")
            expect(path.basename("solo")).to.equal("solo")
        end)

        it("strips explicit and inferred extensions", function()
            expect(path.stripExtension("config.rfld", ".rfld")).to.equal("config")
            expect(path.stripExtension("config.json", ".rfld")).to.equal("config.json")
            expect(path.stripExtension("folder/file.txt")).to.equal("folder/file")
            expect(path.stripExtension("README")).to.equal("README")
        end)
    end)
end
