local services = {}

function services.getService(name)
    local service = game:GetService(name)
    return if cloneref then cloneref(service) else service
end

return services