local Row = {}
Row.__index = Row
Row.__type = "Row"

-- Packs up to 3 compact elements (buttons/switches/stats) side by side.
-- Also a mini host to its children: they're made with row:CreateX and parented into
-- the row. Mimics the Tab fields components use (window, tabPage, elements,
-- _moveElement, compact) so the same code builds them. Flags register on
-- window.controls, so config works through the nesting.

local moveable = require(script.Parent.Parent.utility.moveable)

local maxElements = 3
local elementPadding = 8

Row.compact = true -- children read self.tab.compact

function Row.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"), -- parent tab
        window = tab.window,
        elements = {}, -- the row's children (max maxElements)
    }, Row)

    -- transparent shell; each child brings its own body
    self.main = self.window:Create("Frame", {
        Name = "Row",
        Size = UDim2.new(1, -20, 0, 41),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,

        Parent = self.tab.tabPage,
    })

    -- children parent here (self.tab.tabPage)
    self.tabPage = self.main

    self.layout = self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, elementPadding),

        Parent = self.main,
    })

    return self
end

-- soft cap: a 4th element warns instead of erroring
function Row:_add(componentName, properties)
    if #self.elements >= maxElements then
        warn(`Rayfield: a Row holds at most {maxElements} elements, ignoring an extra '{componentName}'.`)
        return nil
    end

    local element = require(script.Parent[componentName]).new(self, properties)
    table.insert(self.elements, element)
    element.main.LayoutOrder = #self.elements
    return element
end

function Row:CreateButton(properties)
    return self:_add("button", properties)
end
function Row:CreateToggle(properties)
    return self:_add("toggle", properties)
end
function Row:CreateSwitch(properties)
    return self:_add("toggle", properties)
end
function Row:CreateStat(properties)
    return self:_add("stat", properties)
end

-- reorder a child within the row
function Row:_moveElement(element, targetIndex)
    local idx = table.find(self.elements, element)
    if not idx then
        return
    end
    table.remove(self.elements, idx)
    targetIndex = math.clamp(targetIndex, 1, #self.elements + 1)
    table.insert(self.elements, targetIndex, element)
    for i, el in self.elements do
        el.main.LayoutOrder = i
    end
end

-- children are in row.elements, not tab.elements, so forward the reveal down
function Row:_setShown(animate)
    for _, el in self.elements do
        el:_setShown(animate)
    end
end

-- reorder the row within its tab
moveable(Row)

return Row
