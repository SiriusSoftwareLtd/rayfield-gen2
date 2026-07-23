--!nonstrict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local List = {}
List.__index = List
List.__type = "List"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local functions = require(utility.functions)
local image = require(utility.image)
local constants = require(utility.constants)
local locale = require(utility.locale)
local hapticEngine = require(utility.HapticEngine)

local checkIcon = constants.icons.check
local dotIcon = constants.icons.dot

-- Per-corner radii: an option's edge is rounded when nothing sits next to it, sharp otherwise
local roundRadius = UDim.new(0, 12)
local flatRadius = UDim.new(0, 7)

local function dedupStrings(arr)
    local seen = {}
    local out = {}
    for _, v in arr do
        if typeof(v) == "string" and not seen[v] then
            seen[v] = true
            table.insert(out, v)
        end
    end
    return out
end

local function normalizeValue(value, multi)
    if value == nil then
        return {}
    end
    if typeof(value) == "string" then
        return { value }
    end
    if typeof(value) == "table" then
        local out = dedupStrings(value)
        if not multi and #out > 1 then
            return { out[1] }
        end
        return out
    end
    return {}
end

function List.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local options = properties.options or properties.Options or {}
    local multiSelect = properties.multiSelect or properties.MultiSelect or properties.MultipleOptions or false

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or "List",
        icon = properties.icon or properties.Icon,
        description = properties.description or properties.Description,
        forgetState = properties.forgetState or properties.ForgetState or tab.forgetState,

        flag = properties.flag
            or properties.Flag
            or (
                not (properties.forgetState or properties.ForgetState or tab.forgetState)
                    and functions.deriveFlagFromName(properties.name or properties.Name or "List")
                or nil
            ),

        callback = properties.callback or properties.Callback or function() end,

        options = dedupStrings(options),
        multiSelect = multiSelect,
        placeholderText = locale.resolve(properties.placeholder or properties.Placeholder or "None"),
        value = normalizeValue(
            properties.value or properties.Value or properties.currentOption or properties.CurrentOption,
            multiSelect
        ),

        _optionFrames = {},
    }, List)

    -- Prune the initial value to options that actually exist
    local prunedValue = {}
    for _, v in self.value do
        if table.find(self.options, v) then
            table.insert(prunedValue, v)
        end
    end
    self.value = prunedValue

    -- Register as a saveable control if flagged
    self.window:_registerControl(self)

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 41),
        BorderSizePixel = 0,
        Name = self.name,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    }, { BackgroundTransparency = "ElementTransparency" })

    self.stroke = self.window:StyleElementPanel(self.main)
    self.flashTarget = self.main

    -- Header row: icon + title + selected value
    self.top = self.window:Create("Frame", {
        Size = UDim2.new(1, 0, 0, 41),
        Position = UDim2.fromScale(0, 0),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ZIndex = 1,

        Parent = self.main,
    })

    self.container = self.window:Create("Frame", {
        BorderSizePixel = 0,

        Parent = self.top,
        Size = UDim2.new(0, 170, 0, 16),
        Position = UDim2.new(0, 20, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 5,
    })

    self.containerLayout = self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,

        Parent = self.container,
    })

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            Image = self.icon,
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,

            ImageTransparency = 1,

            ZIndex = 5,
            Parent = self.container,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = self.window:Create("TextLabel", {
        Text = locale.t(self.name),

        Size = UDim2.fromOffset(150, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        AutomaticSize = Enum.AutomaticSize.X,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 1,

        TextTransparency = 1,

        ZIndex = 5,
        Parent = self.container,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self.selectedLabel = self.window:Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -18, 0.5, 0),
        Size = UDim2.fromOffset(168, 15),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextWrapped = true,

        TextTransparency = 1,

        ZIndex = 5,
        Parent = self.top,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self.window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.main,
    })

    self.list = self.window:Create("ScrollingFrame", {
        Active = true,
        Size = UDim2.new(1, 0, 0, 0),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        ScrollBarImageColor3 = Color3.fromRGB(240, 240, 240),
        ScrollBarThickness = 3,
        ScrollBarImageTransparency = 1,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        LayoutOrder = 2,
        ZIndex = 1,

        Parent = self.main,
    })

    self.window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Fill,

        Parent = self.list,
    })

    self.listLayout = self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,

        Parent = self.list,
    })

    self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, 1),
        PaddingBottom = UDim.new(0, 6),

        Parent = self.list,
    })

    local function isOptionSelected(name)
        return table.find(self.value, name) ~= nil
    end

    local function renderOptionState(data, animate)
        local selected = isOptionSelected(data.name)
        local bgT = if selected then 0.9 else 0.95
        local titleT = if selected then 0 else 0.3
        local iconT = if selected then 0 else 0.7
        local strokeT = if selected then 0.85 else 0.93

        image.assign(data.checkIcon, "Image", if selected then checkIcon else dotIcon)

        if animate then
            local info = TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
            variables.tweenService:Create(data.frame, info, { BackgroundTransparency = bgT }):Play()
            variables.tweenService:Create(data.title, info, { TextTransparency = titleT }):Play()
            variables.tweenService:Create(data.checkIcon, info, { ImageTransparency = iconT }):Play()
            variables.tweenService:Create(data.stroke, info, { Transparency = strokeT }):Play()
        else
            data.frame.BackgroundTransparency = bgT
            data.title.TextTransparency = titleT
            data.checkIcon.ImageTransparency = iconT
            data.stroke.Transparency = strokeT
        end
    end

    local function updateSelectedLabel()
        if self.multiSelect then
            local n = #self.value
            if n == 0 then
                self.selectedLabel.Text = self.placeholderText
            elseif n == 1 then
                self.selectedLabel.Text = self.value[1]
            else
                self.selectedLabel.Text = locale.resolve("Various")
            end
        else
            self.selectedLabel.Text = self.value[1] or self.placeholderText
        end
    end

    self._renderOptionState = renderOptionState
    self._updateSelectedLabel = updateSelectedLabel

    local function buildOption(optionName)
        local frame = self.window:Create("Frame", {
            Size = UDim2.new(1, -12, 0, 38),
            BorderSizePixel = 0,

            BackgroundTransparency = 1,

            Parent = self.list,
        }, { BackgroundColor3 = "DropdownHighlight" })

        -- Radius is driven by adjacency in _updateCorners (7 flat / 12 rounded)
        local corner = self.window:Create("UICorner", {
            CornerRadius = flatRadius,
            Parent = frame,
        })

        -- Subtle stroke, only shown on the selected option
        local optionStroke = self.window:Create("UIStroke", {
            Color = Color3.fromRGB(255, 255, 255),
            Transparency = 1,
            Parent = frame,
        })

        local interact = self.window:Create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            TextTransparency = 1,
            ZIndex = 50,
            Parent = frame,
        })

        local container = self.window:Create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 14, 0.5, 0),
            Size = UDim2.fromOffset(170, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ZIndex = 5,
            Parent = frame,
        })

        self.window:Create("UIListLayout", {
            Padding = UDim.new(0, 5),
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = container,
        })

        local checkIconImg = self.window:Create("ImageLabel", {
            Image = "rbxassetid://" .. tostring(checkIcon),
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ImageTransparency = 1,
            ZIndex = 5,
            Parent = container,
        }, { ImageColor3 = "ContentColor" })

        local title = self.window:Create("TextLabel", {
            Text = optionName,
            Size = UDim2.fromOffset(170, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            LayoutOrder = 1,
            TextTransparency = 1,
            ZIndex = 5,
            Parent = container,
        }, { TextColor3 = "ContentColor", FontFace = "Font" })

        local data = {
            name = optionName,
            frame = frame,
            interact = interact,
            title = title,
            checkIcon = checkIconImg,
            container = container,
            stroke = optionStroke,
            corner = corner,
            connections = {},
        }

        table.insert(
            data.connections,
            self.window:ConnectFor(self, frame.MouseEnter, function()
                if not self.window:_interactive() then
                    return
                end
                if isOptionSelected(optionName) then
                    return
                end
                variables.tweenService
                    :Create(
                        frame,
                        TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                        { BackgroundTransparency = 0.9 }
                    )
                    :Play()
                variables.tweenService
                    :Create(
                        title,
                        TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                        { TextTransparency = 0.15 }
                    )
                    :Play()
            end)
        )

        table.insert(
            data.connections,
            self.window:ConnectFor(self, frame.MouseLeave, function()
                if isOptionSelected(optionName) then
                    return
                end
                variables.tweenService
                    :Create(
                        frame,
                        TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                        { BackgroundTransparency = 0.95 }
                    )
                    :Play()
                variables.tweenService
                    :Create(
                        title,
                        TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                        { TextTransparency = 0.3 }
                    )
                    :Play()
            end)
        )

        table.insert(
            data.connections,
            self.window:ConnectFor(self, interact.MouseButton1Click, function()
                hapticEngine.click()
                local sel = isOptionSelected(optionName)

                if not self.multiSelect then
                    if sel then
                        return
                    end
                    table.clear(self.value)
                    table.insert(self.value, optionName)
                else
                    if sel then
                        local idx = table.find(self.value, optionName)
                        if idx then
                            table.remove(self.value, idx)
                        end
                    else
                        table.insert(self.value, optionName)
                    end
                end

                for _, d in self._optionFrames do
                    renderOptionState(d, true)
                end

                updateSelectedLabel()

                self.window:_runGuarded(self, self.callback, self:_callbackValue())
                self.window:_persist(self)
            end)
        )

        return data
    end

    self._buildOption = buildOption

    for _, opt in self.options do
        local data = buildOption(opt)
        table.insert(self._optionFrames, data)
    end

    updateSelectedLabel()
    self:_updateCorners()

    -- Render all options in their selection state
    for _, data in self._optionFrames do
        renderOptionState(data, false)
    end

    -- Size the main frame to fit all content
    self:_resizeToOptions()

    if self.description then
        self.descriptor = require(script.Parent.descriptor).new(self.tab, { description = self.description })
    end

    return self
end

function List:_callbackValue()
    if self.multiSelect then
        return table.clone(self.value)
    end
    return self.value[1]
end

-- Height of the main frame: header + panel padding + option rows
function List:_contentHeight()
    local n = 0
    for _, data in self._optionFrames do
        if data.frame.Visible then
            n += 1
        end
    end
    local rows = n * 38 + math.max(0, n - 1) * 5
    return 48 + rows
end

function List:_resizeToOptions()
    self.main.Size = UDim2.new(1, -20, 0, self:_contentHeight())
end

-- Per-corner rounding: an option's top corners round off only when nothing sits above it,
-- and its bottom corners only when nothing sits below it.
function List:_updateCorners()
    local visible = {}
    for _, data in self._optionFrames do
        if data.frame.Visible then
            table.insert(visible, data)
        end
    end

    for i, data in visible do
        local topR = if i == 1 then roundRadius else flatRadius
        local botR = if i == #visible then roundRadius else flatRadius
        data.corner.TopLeftRadius = topR
        data.corner.TopRightRadius = topR
        data.corner.BottomLeftRadius = botR
        data.corner.BottomRightRadius = botR
    end
end

function List:_destroyOption(data)
    if data.connections then
        for _, connection in data.connections do
            local idx = table.find(self.connections, connection)
            if idx then
                table.remove(self.connections, idx)
            end
            self.window:Disconnect(connection)
        end
        data.connections = nil
    end
    self.window:DestroySubtree(data.frame)
end

function List:Refresh(newOptions)
    self.options = dedupStrings(newOptions or {})

    for _, data in self._optionFrames do
        self:_destroyOption(data)
    end
    table.clear(self._optionFrames)

    local pruned = {}
    for _, v in self.value do
        if table.find(self.options, v) then
            table.insert(pruned, v)
        end
    end
    local selectionChanged = #pruned ~= #self.value
    self.value = pruned

    if not self.multiSelect and #self.value == 0 and #self.options > 0 then
        self.value = { self.options[1] }
        selectionChanged = true
    end

    for _, opt in self.options do
        local data = self._buildOption(opt)
        table.insert(self._optionFrames, data)
        self._renderOptionState(data, false)
    end

    self._updateSelectedLabel()
    self:_updateCorners()
    self:_resizeToOptions()

    if selectionChanged then
        self.window:_runGuarded(self, self.callback, self:_callbackValue())
        self.window:_persist(self)
    end
end

function List:Add(option)
    if typeof(option) ~= "string" or option == "" then
        return
    end
    if table.find(self.options, option) then
        return
    end

    table.insert(self.options, option)
    local data = self._buildOption(option)
    table.insert(self._optionFrames, data)
    self._renderOptionState(data, true)
    self:_updateCorners()
    self:_resizeToOptions()
end

function List:Remove(option)
    local idx = table.find(self.options, option)
    if not idx then
        return
    end

    table.remove(self.options, idx)

    for i, data in self._optionFrames do
        if data.name == option then
            self:_destroyOption(data)
            table.remove(self._optionFrames, i)
            break
        end
    end

    local valueIdx = table.find(self.value, option)
    if valueIdx then
        table.remove(self.value, valueIdx)
        self._updateSelectedLabel()
        self.window:_runGuarded(self, self.callback, self:_callbackValue())
        self.window:_persist(self)
    end

    self:_updateCorners()
    self:_resizeToOptions()
end

function List:Set(value, skipCallback)
    local newValue = normalizeValue(value, self.multiSelect)

    local pruned = {}
    for _, v in newValue do
        if table.find(self.options, v) then
            table.insert(pruned, v)
        end
    end
    self.value = pruned

    for _, data in self._optionFrames do
        self._renderOptionState(data, true)
    end
    self._updateSelectedLabel()

    if not skipCallback then
        self.window:_runGuarded(self, self.callback, self:_callbackValue())
        self.window:_persist(self)
    end
end

function List:_setShown(shown, animate)
    local w = self.window
    w:_reveal(self.stroke, { Transparency = if shown then w.theme.ElementStrokeTransparency else 1 }, animate)
    w:_reveal(self.main, { BackgroundTransparency = if shown then (w.theme.ElementTransparency or 0) else 1 }, animate)
    w:_reveal(self.title, { TextTransparency = if shown then 0 else 1 }, animate)
    if self.iconLabel then
        w:_reveal(self.iconLabel, { ImageTransparency = if shown then 0 else 1 }, animate)
    end
    if self.descriptor then
        w:_reveal(self.descriptor.titleLabel, { TextTransparency = if shown then 0.7 else 1 }, animate)
    end
    w:_reveal(self.selectedLabel, { TextTransparency = if shown then 0.5 else 1 }, animate)

    for _, data in self._optionFrames do
        local selected = table.find(self.value, data.name) ~= nil
        w:_reveal(data.frame, { BackgroundTransparency = if shown then (selected and 0.9 or 0.95) else 1 }, animate)
        w:_reveal(data.title, { TextTransparency = if shown then (selected and 0 or 0.3) else 1 }, animate)
        w:_reveal(data.checkIcon, { ImageTransparency = if shown then (selected and 0 or 0.7) else 1 }, animate)
        w:_reveal(data.stroke, { Transparency = if shown then (selected and 0.85 or 0.93) else 1 }, animate)
    end
end

function List:MoveTo(index)
    self.tab:_moveElement(self, index)
end

function List:MoveToTop()
    self.tab:_moveElement(self, 1)
end

function List:MoveToBottom()
    self.tab:_moveElement(self, #self.tab.elements)
end

function List:MoveUp()
    local idx = table.find(self.tab.elements, self)
    if idx then
        self.tab:_moveElement(self, idx - 1)
    end
end

function List:MoveDown()
    local idx = table.find(self.tab.elements, self)
    if idx then
        self.tab:_moveElement(self, idx + 1)
    end
end

return List
