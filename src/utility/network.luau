local services = require(script.Parent.services)

local network = {}
network.__index = network

-- accepts the environment table from getfenv()
function network.getRequestFn(env)
    env = env or getfenv()
    return env.request
        or env.http_request
        or (env.http and env.http.request)
        or (env.syn and env.syn.request)
        or (env.fluxus and env.fluxus.request)
end


return network