local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local encoding = requireUtility("encoding")
    local httpService = game:GetService("HttpService")

    describe("utility.encoding", function()
        local originalJsonEncode
        local originalJsonDecode

        beforeEach(function()
            originalJsonEncode = httpService.JSONEncode
            originalJsonDecode = httpService.JSONDecode
        end)

        afterEach(function()
            httpService.JSONEncode = originalJsonEncode
            httpService.JSONDecode = originalJsonDecode
        end)

        it("decodes padded, unpadded, whitespace, and binary base64", function()
            expect(encoding.base64.decode("b25l")).to.equal("one")
            expect(encoding.base64.decode("dHdv")).to.equal("two")
            expect(encoding.base64.decode("Z29vZA==")).to.equal("good")
            expect(encoding.base64.decode(" Z29v\nZA== ")).to.equal("good")
            expect(encoding.base64.decode("AAECAw==")).to.equal("\0\1\2\3")
        end)

        it("rejects malformed base64", function()
            for _, value in { "", "abc", "!!!!", "AA=A", "AA==AAAA" } do
                expect(encoding.base64.decode(value)).never.to.be.ok()
            end
            expect(encoding.base64.decode(123)).never.to.be.ok()
        end)

        it("encodes and decodes JSON through protected helpers", function()
            local value = { assetIds = { "1", "2" } }
            httpService.JSONEncode = function(_, received)
                expect(received).to.equal(value)
                return "encoded"
            end
            httpService.JSONDecode = function(_, received)
                expect(received).to.equal("encoded")
                return value
            end

            expect(encoding.json.encode(value)).to.equal("encoded")
            expect(encoding.json.decode("encoded")).to.equal(value)
        end)

        it("returns nil when JSON operations fail or return invalid output", function()
            httpService.JSONEncode = function()
                error("encode failed")
            end
            httpService.JSONDecode = function()
                error("decode failed")
            end

            expect(encoding.json.encode({})).never.to.be.ok()
            expect(encoding.json.decode("bad")).never.to.be.ok()

            httpService.JSONEncode = function()
                return {}
            end
            expect(encoding.json.encode({})).never.to.be.ok()
        end)
    end)
end
