local Group = {}
Group.__index = Group
Group.__type = "Group"

-- A layout container. Lays its children along one axis and nests, so a row of columns
-- gives you a grid. A row wraps when it runs out of width instead of shrinking forever.
-- Mimics the Tab fields components read (window, tabPage, elements, compact, direction,
-- _moveElement) so the exact same element code builds inside it, and flags still register
-- on window.controls through the nesting.
--
-- row    -> children build compact and share the width, wrapping to new rows as needed
-- column -> children build full width, stacked top to bottom
-- The public API calls these "row"/"column"; "horizontal"/"vertical" work too.

local moveable = require(script.Parent.Parent.utility.moveable)
local log = require(script.Parent.Parent.utility.log)
local assignOrder = require(script.Parent.Parent.utility.ordering)

local elementPadding = 8

-- these render fine side by side in a row: the compact builds (button/toggle/stat) and
-- the slider (it reflows to its narrow layout). dropdown/section stay full-only.
local compactCapable = {
    button = true,
    toggle = true,
    stat = true,
    slider = true,
}

function Group.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local dir = string.lower(properties.direction or properties.Direction or "row")
    local vertical = dir == "column" or dir == "vertical"
    local horizontal = not vertical
    local direction = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"), -- host: a Tab or a parent Group
        window = tab.window,
        direction = direction,
        compact = horizontal, -- row children pack side by side
        elements = {},
    }, Group)

    -- if our host is a row we're a column, so we hand our width to its flex
    local nestedInRow = tab.direction == Enum.FillDirection.Horizontal

    self.main = self.window:Create("Frame", {
        Name = "Group",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        -- row matches a normal element's inset (1,-20). column is full width so its
        -- full-build children (1,-20) line up with the rest of the tab.
        Size = if horizontal then UDim2.new(1, -20, 0, 0) else UDim2.new(1, 0, 0, 0),

        Parent = self.tab.tabPage,
    })

    if nestedInRow then
        -- let the parent row divide its width between columns
        self.main.Size = UDim2.new(0, 0, 0, 0)
        self.window:Create("UIFlexItem", {
            FlexMode = Enum.UIFlexMode.Fill,
            Parent = self.main,
        })
    end

    -- children parent here
    self.tabPage = self.main

    self.layout = self.window:Create("UIListLayout", {
        FillDirection = direction,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, elementPadding),
        VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
        HorizontalAlignment = if horizontal then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Center,

        Parent = self.main,
    })

    return self
end

function Group:_add(componentName, properties)
    if self.compact and not compactCapable[componentName] then
        log.warn(
            `Rayfield: a row only holds compact elements (button/toggle/stat/slider), ignoring '{componentName}'. Use a column for it.`
        )
        return nil
    end

    local element = require(script.Parent[componentName]).new(self, properties)
    table.insert(self.elements, element)
    assignOrder(element, #self.elements * 10)

    if self.compact then
        self:_wrapChild(element)
    end

    return element
end

-- A row wraps instead of shrinking forever. Each child is frozen to the width it actually
-- needs (element:_minWidth counts its icon, text, control + padding), so the row breaks on
-- real bounds, and HorizontalFlex grows each row's items to fill it.
function Group:_wrapChild(element)
    self.layout.Wraps = true
    self.layout.HorizontalFlex = Enum.UIFlexAlignment.Fill

    -- tells a width-owning element (the slider) that we drive its width now, so its own
    -- reflow stops fighting us. plain compact elements ignore the flag.
    element._widthManaged = true

    local minWidth = if element._minWidth then element:_minWidth() else 0
    if minWidth > 0 then
        element.main.AutomaticSize = Enum.AutomaticSize.None
        element.main.Size = UDim2.new(0, minWidth, element.main.Size.Y.Scale, element.main.Size.Y.Offset)
    end
end

function Group:CreateButton(properties)
    return self:_add("button", properties)
end
function Group:CreateToggle(properties)
    return self:_add("toggle", properties)
end
function Group:CreateSwitch(properties)
    return self:_add("toggle", properties)
end
function Group:CreateStat(properties)
    return self:_add("stat", properties)
end
function Group:CreateSlider(properties)
    return self:_add("slider", properties)
end
function Group:CreateDropdown(properties)
    return self:_add("dropdown", properties)
end
function Group:CreateSection(properties)
    return self:_add("section", properties)
end

-- a nested group: a column (for a grid) or another row inside this one
function Group:_addGroup(properties)
    properties = if typeof(properties) == "table" then table.clone(properties) else {}

    -- adapt a row that's about to hold columns instead of compact leaves:
    if self.direction == Enum.FillDirection.Horizontal then
        -- columns carry their own 10px side margin (the 1,-20), so where two meet the gutter
        -- is 10+10=20, twice the 10px outer margin. pull them together by one margin's worth
        -- so the gutter matches the outer margins. leaf compact elements keep the 8px gap.
        self.layout.Padding = UDim.new(0, -10)
        -- top-align, not centre: a column growing (e.g. a dropdown opening) must push down,
        -- not re-centre and shove the other column around.
        self.layout.VerticalAlignment = Enum.VerticalAlignment.Top
        -- full width (unless we're ourselves a nested column sharing a parent's flex) so
        -- column content lines up with the tab's normal elements instead of sitting 10px in.
        if self.tab.direction ~= Enum.FillDirection.Horizontal then
            self.main.Size = UDim2.new(1, 0, 0, 0)
        end
    end

    local group = Group.new(self, properties)
    table.insert(self.elements, group)
    group.main.LayoutOrder = #self.elements * 10
    return group
end

function Group:CreateGroup(properties)
    return self:_addGroup(properties)
end
-- direction-named aliases (kept so older code keeps working)
function Group:CreateHStack(properties)
    properties = if typeof(properties) == "table" then table.clone(properties) else {}
    properties.direction = "row"
    return self:_addGroup(properties)
end
function Group:CreateVStack(properties)
    properties = if typeof(properties) == "table" then table.clone(properties) else {}
    properties.direction = "column"
    return self:_addGroup(properties)
end

-- reorder a child within this group
function Group:_moveElement(element, targetIndex)
    local idx = table.find(self.elements, element)
    if not idx then
        return
    end
    table.remove(self.elements, idx)
    targetIndex = math.clamp(targetIndex, 1, #self.elements + 1)
    table.insert(self.elements, targetIndex, element)
    for i, el in self.elements do
        assignOrder(el, i * 10)
    end
end

-- children live in group.elements, not tab.elements, so forward the reveal down.
-- nested groups forward it again, so a whole grid reveals in one call.
function Group:_setShown(shown, animate)
    for _, el in self.elements do
        el:_setShown(shown, animate)
    end
end

-- reorder the group within its host
moveable(Group)

return Group
