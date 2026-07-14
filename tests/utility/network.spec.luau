--!strict

local requireUtility = (_G :: any).__RAYFIELD_TEST_HELPERS.requireUtility

return function()
    local network = requireUtility("network")

    describe("utility.network", function()
        it("prefers direct request functions", function()
            local request = function() end

            expect(network.getRequestFn({ request = request })).to.equal(request)
            expect(network.getRequestFn({ http_request = request })).to.equal(request)
        end)

        it("falls back to nested executor request functions", function()
            local request = function() end

            expect(network.getRequestFn({ http = { request = request } })).to.equal(request)
            expect(network.getRequestFn({ syn = { request = request } })).to.equal(request)
            expect(network.getRequestFn({ fluxus = { request = request } })).to.equal(request)
        end)

        it("returns nil when no supported request function exists", function()
            expect(network.getRequestFn({})).never.to.be.ok()
        end)
    end)
end
