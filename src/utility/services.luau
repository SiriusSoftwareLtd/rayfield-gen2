--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local services = {}

function services.getService(name)
    local service = game:GetService(name)
    return if cloneref then cloneref(service) else service
end

return services
