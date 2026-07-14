-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Shared Move* methods for tab elements. Call moveable(Class) once on the prototype.

local function moveable(class)
    function class:MoveTo(index)
        self.tab:_moveElement(self, index)
    end

    function class:MoveToTop()
        self.tab:_moveElement(self, 1)
    end

    function class:MoveToBottom()
        self.tab:_moveElement(self, #self.tab.elements)
    end

    function class:MoveUp()
        local idx = table.find(self.tab.elements, self)
        if idx then
            self.tab:_moveElement(self, idx - 1)
        end
    end

    function class:MoveDown()
        local idx = table.find(self.tab.elements, self)
        if idx then
            self.tab:_moveElement(self, idx + 1)
        end
    end

    return class
end

return moveable
