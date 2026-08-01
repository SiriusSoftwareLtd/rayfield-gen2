--!nonstrict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
local variables = require(script.Parent.Parent.utility.variables)
local assignOrder = require(script.Parent.Parent.utility.ordering)

local elementPadding = 8

-- The layout decides where its lines break from the widths it is handed, and this hands out the
-- whole of one. Leaving a pixel back means the remainder is always too small for the next line's
-- first child, so the layout is held to the same break this packing chose rather than finding its
-- own a rounding error away from it.
local lineSlack = 2

-- How much wider than the break a line has to be before it takes a child back. Without it, a drag
-- parked on a break width wraps and unwraps every frame it is held there.
local lineHysteresis = 10

-- A wrap is two things happening at once: the child moves to another line, and every child on
-- both lines is owed a different share of the width. Run together they read as one jump. So the
-- move goes first, and the widths open out as it settles rather than before it.
local slideInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local expandInfo = TweenInfo.new(0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0.14)

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
        forgetState = tab.forgetState, -- inherit the host's config-persistence stance
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
    self.window:_restoreLate(element)

    if self.compact then
        self:_wrapChild(element)
    end
    self:_reflowRow() -- a leaf landing in a row of columns has to widen the gap back out

    -- same as Tab:_register: elements added after Window:Show must be revealed here
    -- or they stay fully transparent
    if not self.window.hidden then
        element:_setShown(true, true)
    end

    return element
end

-- Padding is one property for the whole row, so it has to suit whatever the row ends up
-- holding. Columns carry their own 10px side margin (the 1,-20), so where two meet the gutter
-- is 10+10=20, twice the 10px outer margin - pull them together by one margin's worth to match.
-- Leaves carry no margin, so the same pull would just overlap them: a row holding any leaf
-- keeps the leaf gap and lets the columns sit a touch wider apart.
function Group:_reflowRow()
    if self.direction ~= Enum.FillDirection.Horizontal then
        return
    end

    local onlyGroups = #self.elements > 0
    for _, element in self.elements do
        if element.__type ~= "Group" then
            onlyGroups = false
            break
        end
    end

    self.layout.Padding = if onlyGroups then UDim.new(0, -10) else UDim.new(0, elementPadding)
end

-- A row wraps instead of shrinking forever. Each child is frozen to the width it actually
-- needs (element:_minWidth counts its icon, text, control + padding), so the row breaks on
-- real bounds, and HorizontalFlex grows each row's items to fill it.
function Group:_wrapChild(element)
    self.layout.Wraps = true

    -- tells a width-owning element (the slider) that we drive its width now, so its own
    -- reflow stops fighting us. plain compact elements ignore the flag.
    element._widthManaged = true

    local minWidth = if element._minWidth then element:_minWidth() else 0
    if minWidth <= 0 then
        return
    end

    -- A UIListLayout owns the Position of everything it lays out, so a child cannot be animated
    -- where it stands: the next layout pass puts it straight back. The layout is given a slot to
    -- move instead, and the element rides inside it, which leaves the element's own Position free
    -- to catch up from wherever the wrap took it from.
    local slot = self.window:Create("Frame", {
        Name = "Slot",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.fromOffset(minWidth, 0),
        LayoutOrder = element.main.LayoutOrder,

        Parent = self.main,
    })

    element._slot = slot
    element._minSlotWidth = minWidth
    element.main.AutomaticSize = Enum.AutomaticSize.None
    element.main.Size = UDim2.new(1, 0, element.main.Size.Y.Scale, element.main.Size.Y.Offset)
    element.main.Position = UDim2.fromOffset(0, 0)
    element.main.Parent = slot

    self.window:ConnectFor(element, slot:GetPropertyChangedSignal("AbsolutePosition"), function()
        self:_slideIntoPlace(element)
    end)

    if not self._watchingWidth then
        self._watchingWidth = true
        self.window:Connect(self.main:GetPropertyChangedSignal("AbsoluteSize"), function()
            -- the group grows taller as its own lines re-pack, which would land back here and
            -- re-run a pass whose answer has not changed. Only a new width is news.
            local width = self.main.AbsoluteSize.X
            if width == self._sharedAt then
                return
            end
            self._sharedAt = width
            self:_shareWidth()
        end)
    end

    self:_shareWidth()
end

-- Pack the row into lines by the width each child actually needs, then hand whatever is left
-- over on each line out evenly between the children on it. This is what UIListLayout's own
-- HorizontalFlex does, and it does it in the frame the wrap happens: a child leaving a line
-- means the ones it leaves behind are simply wider on the next frame, with nothing in between.
-- Doing the share here means the widths are ours to move, so a line that gains room opens into
-- it and a line that loses a child closes up, in front of the person who resized the window.
function Group:_packRows(available: number)
    local padding = self.layout.Padding.Offset
    local rows, current, used = {}, {}, 0
    local line = 1

    for _, element in self.elements do
        local width = element._minSlotWidth or 0
        local gap = if #current > 0 then padding else 0

        -- a child that was pushed onto a line of its own has to be offered more than the width it
        -- broke at before it comes back up, or a drag held on that width flips it every frame
        local room = available
        if element._line and element._line > line then
            room -= lineHysteresis
        end

        if #current > 0 and used + gap + width > room then
            table.insert(rows, { items = current, used = used })
            line += 1
            current, used = { element }, width
        else
            table.insert(current, element)
            used += gap + width
        end
    end

    if #current > 0 then
        table.insert(rows, { items = current, used = used })
    end

    return rows
end

-- Give every child the width its line owes it. `animate` is for the lines changing shape - a
-- child wrapping away or coming back - and not for a drag, where the widths are already tracking
-- the window a frame at a time and a tween on top would only trail behind it.
function Group:_shareWidth()
    if self.direction ~= Enum.FillDirection.Horizontal or #self.elements == 0 then
        return
    end

    -- a row holding anything without a slot (a nested column) is still the engine's to share out
    for _, element in self.elements do
        if not element._slot then
            return
        end
    end

    local available = self.main.AbsoluteSize.X - lineSlack
    if available <= 0 then
        return
    end

    local rows = self:_packRows(available)
    local settled = self._packed
    self._packed = true

    -- Which line every child has landed on, resolved before anything is applied, because the two
    -- questions this pass has to answer are not the same question. Whether a child travels is its
    -- own: only the one that changed line has anywhere to travel from. Whether anything animates
    -- at all belongs to the pass: if the packing moved, every child is owed a different share of
    -- its line and they all have to open into it together, or the one that left is the only thing
    -- that moves and the room it made appears out of nowhere.
    local lines, changed = {}, false
    for index, row in rows do
        for _, element in row.items do
            lines[element] = index
            if settled and element._line ~= nil and element._line ~= index then
                changed = true
            end
        end
    end

    -- where the group sits on the screen is not the group's business: the window moves under it
    -- every frame of a resize, and measuring from there would read every one of those frames as
    -- a child having been moved. Everything below is measured against the group itself.
    local origin = self.main.AbsolutePosition

    for index, row in rows do
        local spare = math.max(available - row.used, 0)
        local share = math.floor(spare / #row.items)

        for _, element in row.items do
            -- cleared as well as set: a wrap that happens to leave a slot where it already was is
            -- never consumed, and would otherwise be spent on the next unrelated layout pass, long
            -- after the position it holds has stopped meaning anything
            if settled and element._line ~= nil and element._line ~= index then
                element._travelFrom = element._slot.AbsolutePosition - origin
            else
                element._travelFrom = nil
            end
            element._line = index

            self:_setSlotWidth(element, (element._minSlotWidth or 0) + share, changed)
        end
    end
end

-- End an expansion and hand back the height to finish it at. A height its own layout asked for
-- while the width was in flight was held rather than written, since writing one would have taken
-- the width with it, so it has to land here however the expansion ends - which is why this is not
-- left to the tween alone to do.
function Group:_finishExpanding(element, current: UDim)
    element._slotExpanding = false

    local held = element._pendingSlotHeight
    element._pendingSlotHeight = nil
    if held then
        return UDim.new(0, held)
    end
    return current
end

-- Give a child the width its line owes it. The slot takes it at once, always: the slot is what
-- the layout measures to decide where the lines break, so a slot easing into a new width would
-- have the layout re-deciding that against a width still on its way, wrapping and unwrapping
-- under its own animation. The element inside the slot is what eases, from the width it was
-- drawn at to the one the slot now holds, which the layout never looks at and cannot trip over.
function Group:_setSlotWidth(element, width, animate)
    local slot = element._slot
    if slot.Size.X.Offset == width then
        return
    end

    local before = element.main.AbsoluteSize.X
    slot.Size = UDim2.new(0, width, slot.Size.Y.Scale, 0)

    local height = element.main.Size.Y
    if not animate or self.window.hidden or self.window.animating or before <= 0 then
        local settled = self:_finishExpanding(element, height)
        element.main.Size = UDim2.new(1, 0, settled.Scale, settled.Offset)
        return
    end

    element._slotExpanding = true
    element.main.Size = UDim2.new(0, before, height.Scale, height.Offset)

    -- a second wrap arriving mid-expand replaces the animation rather than layering another one
    -- over the same property, where the two would fight for it a frame at a time
    if element._expandTween then
        element._expandTween:Cancel()
    end

    local expand = variables.tweenService:Create(element.main, expandInfo, {
        Size = UDim2.new(1, 0, height.Scale, height.Offset),
    })
    element._expandTween = expand
    expand.Completed:Connect(function(state)
        -- a cancellation is the tween replacing this one having already set the state up, so
        -- there is nothing here to end: clearing it now would undo that setup underneath it
        if state ~= Enum.PlaybackState.Completed then
            return
        end

        local finished = self:_finishExpanding(element, element.main.Size.Y)
        element.main.Size = UDim2.new(1, 0, finished.Scale, finished.Offset)
    end)
    expand:Play()
end

-- Let an element that has just been wrapped onto another line travel there, instead of being
-- somewhere else the next frame. The slot has already moved, so the element starts back where
-- the slot was and runs the gap down, while its width eases into the share the new line owes
-- it. What you see is a child leaving at the size it had and opening out once it has landed.
function Group:_slideIntoPlace(element)
    local came = element._travelFrom
    element._travelFrom = nil

    -- only a child the packing moved to another line has anywhere to travel from. Every other
    -- call here is the layout reporting that the window moved, which is not this element's news.
    if not came or not element._slot or self.window.hidden or self.window.animating then
        return
    end

    local travelled = came - (element._slot.AbsolutePosition - self.main.AbsolutePosition)
    element.main.Position = UDim2.fromOffset(travelled.X, travelled.Y)
    variables.tweenService:Create(element.main, slideInfo, { Position = UDim2.fromOffset(0, 0) }):Play()
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
    self:_reflowRow()
    return group
end

function Group:CreateGroup(properties)
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

-- same reason: forward a runtime theme refresh down to the children (nested groups recurse).
function Group:_refreshTheme()
    for _, el in self.elements do
        if el._refreshTheme then
            el:_refreshTheme()
        end
    end
end

-- reorder the group within its host
moveable(Group)

return Group
