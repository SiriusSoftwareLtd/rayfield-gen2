local Dropdown = {}
Dropdown.__index = Dropdown
Dropdown.__type = "Dropdown"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local functions = require(utility.functions)
local locale = require(utility.locale)

local CHEVRON_ICON = 88479147175134
local CHECK_ICON = 125626312718314
local DOT_ICON = 91452555903853 -- shown on unselected options
local SEARCH_ICON = 100604009889706

-- Per-corner radii: an option's edge is rounded when nothing sits next to it, sharp otherwise
local ROUND_R = UDim.new(0, 12)
local FLAT_R = UDim.new(0, 7)

local SEARCH_COLLAPSED_H = 30
local SEARCH_EXPANDED_H = 38
local searchTween = TweenInfo.new(0.35, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

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

function Dropdown.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local options = properties.options or properties.Options or {}
    local multiSelect = properties.multiSelect or properties.MultiSelect or properties.MultipleOptions or false

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or "Dropdown",
        icon = properties.icon or properties.Icon,
        description = properties.description or properties.Description,
        forgetState = properties.forgetState or properties.ForgetState, -- dont save config for this element if true.

        flag = properties.flag
            or properties.Flag
            or (
                not (properties.forgetState or properties.ForgetState)
                    and functions.deriveFlagFromName(properties.name or properties.Name or "Dropdown")
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

        _isOpen = false,
        _optionFrames = {},
    }, Dropdown)

    -- Prune the initial value to options that actually exist (matches Set/Refresh)
    local prunedValue = {}
    for _, v in self.value do
        if table.find(self.options, v) then
            table.insert(prunedValue, v)
        end
    end
    self.value = prunedValue

    -- Register as a saveable control if flagged
    self.window:_registerControl(self)

    -- Outer wrapper: transparent, just holds the two cards and animates its height
    -- open <-> closed. Clips so the options card is hidden while collapsed.
    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 41),
        BorderSizePixel = 0,
        Name = self.name,
        ClipsDescendants = true,
        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    })

    -- Header card: the always-visible pill (icon + title + selected value + chevron)
    self.top = self.window:Create("Frame", {
        Size = UDim2.new(1, 0, 0, 41),
        Position = UDim2.fromScale(0, 0),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        ZIndex = 1,

        Parent = self.main,
    }, { BackgroundTransparency = "ElementTransparency" })

    self.stroke = self.window:StyleElementPanel(self.top)
    self.hoverOverlay = self.window:CreateHoverOverlay(self.top)

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
            -- Configurables
            Image = "rbxassetid://" .. tostring(self.icon),

            -- Theming
            ImageColor3 = Color3.fromRGB(255, 255, 255),

            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,

            -- Animation
            ImageTransparency = 1, -- In = 0

            ZIndex = 5,
            Parent = self.container,
        }, { ImageColor3 = "ContentColor" })
    end

    self.title = self.window:Create("TextLabel", {
        -- Configurables
        Text = locale.t(self.name),

        Size = UDim2.fromOffset(150, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        AutomaticSize = Enum.AutomaticSize.X,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 1,

        -- Animation
        TextTransparency = 1, -- In = 0

        ZIndex = 5,
        Parent = self.container,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self.selectedLabel = self.window:Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -41, 0.5, 0),
        Size = UDim2.fromOffset(168, 15),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextWrapped = true,

        -- Animation
        TextTransparency = 1, -- In = 0.5

        ZIndex = 5,
        Parent = self.top,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self.chevron = self.window:Create("ImageLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -18, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Image = "rbxassetid://" .. tostring(CHEVRON_ICON),
        Rotation = 180,

        -- Animation
        ImageTransparency = 1, -- In = 0.5

        ZIndex = 5,
        Parent = self.top,
    }, { ImageColor3 = "ContentColor" })

    -- Covers only the header, so option clicks in the open panel below don't hit it.
    self.interact = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 41),
        Position = UDim2.fromScale(0, 0),
        BorderSizePixel = 0,
        Text = "",
        TextTransparency = 1,
        ZIndex = 10,
        AutoButtonColor = false,

        Parent = self.main,
    })

    -- Options card: a second (full-width) pill below the header, revealed as the wrapper
    -- grows. Anchored to the wrapper's bottom (top edge sits 6px under the header) so the
    -- clip hides it while collapsed.
    self.panel = self.window:Create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, 0, 1, 0),
        Size = UDim2.new(1, 0, 1, -47),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        ZIndex = 1,

        BackgroundTransparency = 1, -- Open = ElementTransparency

        Parent = self.main,
    })

    self.panelStroke = self.window:StyleElementPanel(self.panel)

    -- The card stacks the search bar over the list. The search bar is always present in
    -- the layout (it just grows/shrinks), so the gap under it is stable; the list is a
    -- flex-fill item, so it takes whatever height is left and slides down as search grows.
    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.panel,
    })

    self.window:Create("UIPadding", {
        PaddingTop = UDim.new(0, 7),
        PaddingBottom = UDim.new(0, 6),

        Parent = self.panel,
    })

    self:_buildSearch()

    self.list = self.window:Create("ScrollingFrame", {
        Active = true,
        Size = UDim2.new(1, 0, 0, 0), -- height comes from the UIFlexItem below
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        ScrollBarImageColor3 = Color3.fromRGB(240, 240, 240),
        ScrollBarThickness = 3,
        ScrollBarImageTransparency = 1, -- scrollbar kept fully transparent
        ScrollingDirection = Enum.ScrollingDirection.Y,
        LayoutOrder = 2,
        ZIndex = 1,

        Parent = self.panel,
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
        PaddingBottom = UDim.new(0, 2),

        Parent = self.list,
    })

    local function isOptionSelected(name)
        return table.find(self.value, name) ~= nil
    end

    local function renderOptionState(data, animate)
        local selected = isOptionSelected(data.name)
        local bgT = if self._isOpen then (selected and 0.9 or 0.95) else 1
        local titleT = if self._isOpen then (selected and 0 or 0.3) else 1
        -- Selected shows a bright check; unselected shows a faint dot
        local iconT = if self._isOpen then (selected and 0 or 0.7) else 1
        local strokeT = if self._isOpen then (selected and 0.85 or 0.93) else 1

        data.checkIcon.Image = "rbxassetid://" .. tostring(if selected then CHECK_ICON else DOT_ICON)

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

    local function flashError(result)
        -- Flash the header card red (the wrapper is transparent, so tint the pill itself).
        variables.tweenService
            :Create(
                self.top,
                TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { BackgroundColor3 = self.window.theme.ErrorColor }
            )
            :Play()
        self.title.Text = locale.resolve("Error, log recorded in console.")

        warn(`Rayfield encountered an error, with the callback for a {self.__type} component named '{self.name}':`)
        print(result)

        task.wait(1)

        self.title.Text = locale.resolve(self.name)
        variables.tweenService
            :Create(
                self.top,
                TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
                { BackgroundColor3 = Color3.fromRGB(255, 255, 255) }
            )
            :Play()
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

        -- Radius is driven by selection in renderOptionState (5 sharp / 12 rounded)
        local corner = self.window:Create("UICorner", {
            CornerRadius = UDim.new(0, 5),
            Parent = frame,
        })

        -- Subtle stroke, only shown on the selected option
        local optionStroke = self.window:Create("UIStroke", {
            Color = Color3.fromRGB(255, 255, 255),
            Transparency = 1, -- selected = 0.85
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

        local checkIcon = self.window:Create("ImageLabel", {
            Image = "rbxassetid://" .. tostring(CHECK_ICON),
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
            checkIcon = checkIcon,
            container = container,
            stroke = optionStroke,
            corner = corner,
        }

        self.window:Connect(frame.MouseEnter, function()
            if not self._isOpen or not self.window:_interactive() then
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

        self.window:Connect(frame.MouseLeave, function()
            if not self._isOpen then
                return
            end
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

        self.window:Connect(interact.MouseButton1Click, function()
            local sel = isOptionSelected(optionName)

            if not self.multiSelect then
                if sel then
                    self:_close()
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

            task.spawn(function()
                local success, result = pcall(function()
                    self.callback(if self.multiSelect then self.value else self.value[1])
                end)

                if not success then
                    flashError(result)
                end
            end)

            if self.flag and not self.forgetState and self.window.configuration.autoSave then
                task.spawn(self.window.Save, self.window)
            end

            if not self.multiSelect then
                task.wait(0.1)
                self:_close()
            end
        end)

        return data
    end

    self._buildOption = buildOption

    for _, opt in self.options do
        local data = buildOption(opt)
        table.insert(self._optionFrames, data)
    end

    updateSelectedLabel()
    self:_updateCorners()

    -- Function
    self.window:Connect(self.interact.MouseButton1Click, function()
        if self._isOpen then
            self:_close()
        else
            self:_open()
        end
    end)

    -- Hover feedback via the overlay + title only. The card uses a gradient stroke (white
    -- base tinted by the gradient), so tweening stroke.Color here would fight the gradient.
    self.window:Connect(self.main.MouseEnter, function()
        if self._isOpen or not self.window:_interactive() then
            return
        end
        variables.tweenService
            :Create(
                self.title,
                TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { TextColor3 = self.window.theme.ElementTextHoverColor }
            )
            :Play()
        variables.tweenService
            :Create(
                self.hoverOverlay,
                TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { BackgroundTransparency = 0.97 }
            )
            :Play()
    end)

    self.window:Connect(self.main.MouseLeave, function()
        variables.tweenService
            :Create(
                self.title,
                TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { TextColor3 = self.window.theme.ContentColor }
            )
            :Play()
        variables.tweenService
            :Create(
                self.hoverOverlay,
                TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { BackgroundTransparency = 1 }
            )
            :Play()
    end)

    if self.description then
        self.descriptor = require(script.Parent.descriptor).new(self.tab, { description = self.description })
    end

    return self
end

-- Search bar: collapsed it's just the icon (centred, no bar); tapping expands it into a
-- full field. It's always in the card's layout - only its height/fills animate - so the
-- list below just flexes down as it grows.
function Dropdown:_buildSearch()
    self._searchOpen = false

    self.searchbar = self.window:Create("Frame", {
        Name = "Search",
        Size = UDim2.new(1, -12, 0, SEARCH_COLLAPSED_H),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1, -- expanded = 0.92
        LayoutOrder = 1,
        ClipsDescendants = false,
        ZIndex = 1,

        Parent = self.panel,
    })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(0, 12),
        Parent = self.searchbar,
    })

    self.searchStroke = self.window:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 1, -- expanded = 0.86
        Parent = self.searchbar,
    })

    self.searchShadow = self.window:CreateGlow(self.searchbar, Color3.fromRGB(255, 255, 255), 20, 1) -- expanded = 0.92

    -- Full-bar tap target: expands the bar while it's collapsed. Kept above the option
    -- hit-targets (ZIndex 50) so taps here never bleed through to an option under them.
    self.searchToggle = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        TextTransparency = 1,
        ZIndex = 51,
        Parent = self.searchbar,
    })

    self.searchInput = self.window:Create("TextBox", {
        Text = "",
        PlaceholderText = locale.t("Search..."),
        PlaceholderColor3 = Color3.fromRGB(150, 150, 150),
        Size = UDim2.new(1, -58, 0, 16),
        Position = UDim2.new(0, 44, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        TextEditable = false, -- enabled on expand
        Interactable = false, -- collapsed: let taps fall through to the toggle
        ZIndex = 52,

        TextTransparency = 1, -- expanded = 0.3

        Parent = self.searchbar,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    self.searchIcon = self.window:Create("ImageButton", {
        Image = "rbxassetid://" .. tostring(SEARCH_ICON),
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.new(0, 24, 0.5, 0), -- left-aligned (centre at x=24, edge at 14)
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        AutoButtonColor = false,
        ZIndex = 53,

        ImageTransparency = 1, -- In = 0.5

        Parent = self.searchbar,
    }, { ImageColor3 = "ContentColor" })

    self.window:Connect(self.searchToggle.MouseButton1Click, function()
        if not self._searchOpen then
            self:_expandSearch()
        end
    end)
    self.window:Connect(self.searchIcon.MouseButton1Click, function()
        if self._searchOpen then
            self:_collapseSearch()
        else
            self:_expandSearch()
        end
    end)
    self.window:Connect(self.searchInput:GetPropertyChangedSignal("Text"), function()
        self:_applyFilter(self.searchInput.Text)
    end)
    self.window:Connect(self.searchInput.FocusLost, function()
        if self.searchInput.Text == "" then
            self:_collapseSearch()
        end
    end)
end

function Dropdown:_expandSearch()
    if self._searchOpen then
        return
    end
    self._searchOpen = true
    self.searchInput.TextEditable = true
    self.searchInput.Interactable = true

    variables.tweenService
        :Create(
            self.searchbar,
            searchTween,
            { Size = UDim2.new(1, -12, 0, SEARCH_EXPANDED_H), BackgroundTransparency = 0.92 }
        )
        :Play()
    variables.tweenService:Create(self.searchStroke, searchTween, { Transparency = 0.86 }):Play()
    variables.tweenService:Create(self.searchShadow, searchTween, { Transparency = 0.92 }):Play()
    variables.tweenService:Create(self.searchInput, searchTween, { TextTransparency = 0.3 }):Play()

    self.searchInput:CaptureFocus()
end

function Dropdown:_collapseSearch()
    if not self._searchOpen then
        return
    end
    self._searchOpen = false
    self.searchInput.TextEditable = false
    self.searchInput.Interactable = false
    self.searchInput:ReleaseFocus()
    self.searchInput.Text = "" -- fires the filter, showing everything again

    variables.tweenService
        :Create(
            self.searchbar,
            searchTween,
            { Size = UDim2.new(1, -12, 0, SEARCH_COLLAPSED_H), BackgroundTransparency = 1 }
        )
        :Play()
    variables.tweenService:Create(self.searchStroke, searchTween, { Transparency = 1 }):Play()
    variables.tweenService:Create(self.searchShadow, searchTween, { Transparency = 1 }):Play()
    variables.tweenService:Create(self.searchInput, searchTween, { TextTransparency = 1 }):Play()
end

function Dropdown:_applyFilter(query)
    query = string.lower(query or "")
    for _, data in self._optionFrames do
        data.frame.Visible = query == "" or string.find(string.lower(data.name), query, 1, true) ~= nil
    end
    self:_updateCorners()
end

-- Per-corner rounding: an option's top corners round off only when nothing sits above it,
-- and its bottom corners only when nothing sits below - so a run of options reads as one
-- grouped block with rounded outer edges and sharp seams (a lone option is fully rounded).
-- Runs over the currently VISIBLE options, so it re-groups correctly while searching.
function Dropdown:_updateCorners()
    local visible = {}
    for _, data in self._optionFrames do
        if data.frame.Visible then
            table.insert(visible, data)
        end
    end

    for i, data in visible do
        local topR = if i == 1 then ROUND_R else FLAT_R
        local botR = if i == #visible then ROUND_R else FLAT_R
        data.corner.TopLeftRadius = topR
        data.corner.TopRightRadius = topR
        data.corner.BottomLeftRadius = botR
        data.corner.BottomRightRadius = botR
    end
end

function Dropdown:_open()
    if self._isOpen then
        return
    end
    self._isOpen = true

    if self._outsideClickConn then
        self.window:Disconnect(self._outsideClickConn)
    end
    self._outsideClickConn = self.window:Connect(variables.userInputService.InputBegan, function(input)
        if
            input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end

        local pos = input.Position
        local mainPos = self.main.AbsolutePosition
        local mainSize = self.main.AbsoluteSize
        if
            pos.X < mainPos.X
            or pos.X > mainPos.X + mainSize.X
            or pos.Y < mainPos.Y
            or pos.Y > mainPos.Y + mainSize.Y
        then
            self:_close()
        end
    end)

    variables.tweenService
        :Create(
            self.main,
            TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
            { Size = UDim2.new(1, -20, 0, 180) }
        )
        :Play()
    variables.tweenService
        :Create(
            self.chevron,
            TweenInfo.new(0.7, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
            { Rotation = 0 }
        )
        :Play()
    variables.tweenService
        :Create(
            self.panel,
            TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { BackgroundTransparency = self.window.theme.ElementTransparency or 0 }
        )
        :Play()
    variables.tweenService
        :Create(
            self.panelStroke,
            TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { Transparency = self.window.theme.ElementStrokeTransparency }
        )
        :Play()
    variables.tweenService
        :Create(
            self.searchIcon,
            TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { ImageTransparency = 0.5 }
        )
        :Play()

    for _, data in self._optionFrames do
        self._renderOptionState(data, true)
    end
end

function Dropdown:_close()
    if not self._isOpen then
        return
    end
    self._isOpen = false

    if self._outsideClickConn then
        self.window:Disconnect(self._outsideClickConn)
        self._outsideClickConn = nil
    end

    self:_collapseSearch()

    variables.tweenService
        :Create(
            self.chevron,
            TweenInfo.new(0.7, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
            { Rotation = 180 }
        )
        :Play()
    variables.tweenService
        :Create(
            self.panel,
            TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 }
        )
        :Play()
    variables.tweenService
        :Create(
            self.panelStroke,
            TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { Transparency = 1 }
        )
        :Play()
    variables.tweenService
        :Create(
            self.searchIcon,
            TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { ImageTransparency = 1 }
        )
        :Play()

    for _, data in self._optionFrames do
        self._renderOptionState(data, true)
    end

    variables.tweenService
        :Create(
            self.main,
            TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
            { Size = UDim2.new(1, -20, 0, 41) }
        )
        :Play()
end

function Dropdown:Refresh(newOptions)
    self.options = dedupStrings(newOptions or {})

    for _, data in self._optionFrames do
        data.frame:Destroy()
    end
    table.clear(self._optionFrames)

    local pruned = {}
    for _, v in self.value do
        if table.find(self.options, v) then
            table.insert(pruned, v)
        end
    end
    self.value = pruned

    for _, opt in self.options do
        local data = self._buildOption(opt)
        table.insert(self._optionFrames, data)
        -- fresh frames default to the closed look, so paint the open state if the
        -- panel is already open (otherwise they'd sit blank until hovered)
        if self._isOpen then
            self._renderOptionState(data, false)
        end
    end

    self._updateSelectedLabel()
    -- reconcile with any active search (also refreshes corners); empty query shows all
    self:_applyFilter(if self._searchOpen then self.searchInput.Text else "")
end

function Dropdown:Add(option)
    if typeof(option) ~= "string" or option == "" then
        return
    end
    if table.find(self.options, option) then
        return
    end

    table.insert(self.options, option)
    local data = self._buildOption(option)
    table.insert(self._optionFrames, data)

    self:_updateCorners()

    if self._isOpen then
        self._renderOptionState(data, true)
    end
end

function Dropdown:Remove(option)
    local idx = table.find(self.options, option)
    if not idx then
        return
    end

    table.remove(self.options, idx)

    for i, data in self._optionFrames do
        if data.name == option then
            data.frame:Destroy()
            table.remove(self._optionFrames, i)
            break
        end
    end

    local valueIdx = table.find(self.value, option)
    if valueIdx then
        table.remove(self.value, valueIdx)
        self._updateSelectedLabel()
    end

    self:_updateCorners()
end

function Dropdown:Set(value, skipCallback)
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
        task.spawn(self.callback, if self.multiSelect then self.value else self.value[1])
    end
end

function Dropdown:_setShown(shown, animate)
    -- Custom reveal: main is a transparent wrapper, so reveal the header card (self.top)
    -- rather than main. The options card fades in on open, not here.
    local w = self.window
    w:_reveal(self.stroke, { Transparency = if shown then w.theme.ElementStrokeTransparency else 1 }, animate)
    w:_reveal(self.title, { TextTransparency = if shown then 0 else 1 }, animate)
    w:_reveal(self.top, { BackgroundTransparency = if shown then (w.theme.ElementTransparency or 0) else 1 }, animate)
    if self.iconLabel then
        w:_reveal(self.iconLabel, { ImageTransparency = if shown then 0 else 1 }, animate)
    end
    if self.descriptor then
        w:_reveal(self.descriptor.titleLabel, { TextTransparency = if shown then 0.7 else 1 }, animate)
    end
    w:_reveal(self.selectedLabel, { TextTransparency = if shown then 0.5 else 1 }, animate)
    w:_reveal(self.chevron, { ImageTransparency = if shown then 0.5 else 1 }, animate)
end

function Dropdown:MoveTo(index)
    self.tab:_moveElement(self, index)
end

function Dropdown:MoveToTop()
    self.tab:_moveElement(self, 1)
end

function Dropdown:MoveToBottom()
    self.tab:_moveElement(self, #self.tab.elements)
end

function Dropdown:MoveUp()
    local idx = table.find(self.tab.elements, self)
    if idx then
        self.tab:_moveElement(self, idx - 1)
    end
end

function Dropdown:MoveDown()
    local idx = table.find(self.tab.elements, self)
    if idx then
        self.tab:_moveElement(self, idx + 1)
    end
end

return Dropdown
