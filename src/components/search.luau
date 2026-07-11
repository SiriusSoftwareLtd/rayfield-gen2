-- Search: a pill that takes over the tab strip and searches every page at once. The Search
-- action toggles it; while open the tab selector hides and every content tab's elements are
-- gathered into one results page, filtered live by name. Closing puts everything back exactly
-- where it was. Values ported from the RF2 design (Window.Search).

local utility = script.Parent.Parent.utility
local variables = require(utility.variables)
local constants = require(utility.constants)
local locale = require(utility.locale)
local action = require(script.Parent.action)

local search = {}

-- crossfade between the tab strip and the search pill, and the search parts fading in/out
local swapInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- resting/lit brightness for the Search action icon, matching the other topbar actions
local iconRest = 0.6
local iconLit = 0.2

-- The searchable text for one unit: a leaf's own name, or every descendant leaf name joined
-- so a group matches when any child inside it does.
local function unitText(unit)
    if unit.__type == "Group" then
        local parts = {}
        local function walk(group)
            for _, child in group.elements do
                if child.__type == "Group" then
                    walk(child)
                elseif child.name then
                    table.insert(parts, child.name)
                end
            end
        end
        walk(unit)
        return table.concat(parts, "\n")
    end
    return unit.name or ""
end

-- Every top-level element across the real content pages (the settings page and other
-- neglected tabs aren't pages you search). Sections are headers, so skip them.
local function collectUnits(window)
    local units = {}
    for _, tab in window.tabs do
        if tab.neglectSelector then
            continue
        end
        for _, element in tab.elements do
            if element.__type ~= "Section" then
                table.insert(units, element)
            end
        end
    end
    return units
end

-- Fade the pill's fill, stroke, shadow, icon and field in or out together.
local function setPillShown(window, shown, info)
    variables.tweenService
        :Create(window.searchPill, info, {
            BackgroundTransparency = if shown then 0.9 else 1,
        })
        :Play()
    variables.tweenService:Create(window.searchStroke, info, { Transparency = if shown then 0.85 else 1 }):Play()
    variables.tweenService:Create(window.searchShadow, info, { Transparency = if shown then 0.92 else 1 }):Play()
    variables.tweenService:Create(window.searchIcon, info, { ImageTransparency = if shown then 0.65 else 1 }):Play()
    variables.tweenService:Create(window.searchInput, info, { TextTransparency = if shown then 0.2 else 1 }):Play()
end

-- Show/hide the content tab pills as the strip swaps with the search field.
local function setTabsShown(window, shown, info)
    for _, tab in window.tabs do
        if not tab.neglectSelector and tab.topbarItem then
            tab:_applyVisual(
                if shown then (if window.selectedTab == tab then "selected" else "unselected") else "hidden",
                info
            )
        end
    end
end

-- Toggle each unit's visibility against the query. Empty query shows everything, so the
-- open field doubles as a browse-all-pages view.
local function applyFilter(window, query)
    query = string.lower(query or "")
    local anyVisible = false
    for _, entry in window._searchUnits do
        local match = query == "" or string.find(entry.text, query, 1, true) ~= nil
        entry.unit.main.Visible = match
        if entry.unit.descriptor then
            entry.unit.descriptor.main.Visible = match
        end
        anyVisible = anyVisible or match
    end
    window.searchEmpty.Visible = not anyVisible and query ~= ""
end

-- Pull every unit into the results page, remembering where each came from, and lay them out
-- grouped by page in creation order.
local function gatherUnits(window)
    window._searchUnits = {}
    local order = 0
    for _, unit in collectUnits(window) do
        order += 1
        local main = unit.main
        table.insert(window._searchUnits, {
            unit = unit,
            text = string.lower(unitText(unit)),
            homeParent = main.Parent,
            homeOrder = main.LayoutOrder,
            descOrder = unit.descriptor and unit.descriptor.main.LayoutOrder,
        })

        main.LayoutOrder = order * 10
        main.Parent = window.searchPage
        main.Visible = true
        if unit.descriptor then
            unit.descriptor.main.LayoutOrder = order * 10 + 1
            unit.descriptor.main.Parent = window.searchPage
            unit.descriptor.main.Visible = true
        end
    end
end

-- Put every unit back in the tab it came from, at its original order. Guards a unit whose
-- element was removed mid-search (its frame is gone).
local function restoreUnits(window)
    for _, entry in window._searchUnits do
        local unit = entry.unit
        if unit.main and unit.main.Parent then
            unit.main.LayoutOrder = entry.homeOrder
            unit.main.Parent = entry.homeParent
            unit.main.Visible = true
        end
        if unit.descriptor and unit.descriptor.main and unit.descriptor.main.Parent then
            unit.descriptor.main.LayoutOrder = entry.descOrder
            unit.descriptor.main.Parent = entry.homeParent
            unit.descriptor.main.Visible = true
        end
    end
    window._searchUnits = {}
end

function search.open(window)
    if window._searching or not window:_interactive() then
        return
    end
    window._searching = true

    gatherUnits(window)
    applyFilter(window, "")
    window.elementsLayout:JumpTo(window.searchPage)

    -- strip swaps for the field
    setTabsShown(window, false, swapInfo)
    task.delay(swapInfo.Time, function()
        if window._searching then
            window.tabList.Visible = false
        end
    end)

    window.searchPill.Visible = true
    setPillShown(window, true, swapInfo)
    window.searchInput:CaptureFocus()

    variables.tweenService:Create(window.searchAction.iconLabel, swapInfo, { ImageTransparency = iconLit }):Play()
end

-- config.showTabs: fade the tab strip back in (false when the caller hides the window).
-- config.jumpTo: the page to slide back to, or false to leave navigation to the caller.
function search.close(window, config)
    if not window._searching then
        return
    end
    config = config or {}
    window._searching = false

    window.searchInput.Text = ""
    window.searchInput:ReleaseFocus()
    window.searchEmpty.Visible = false

    restoreUnits(window)
    local target = if config.jumpTo == nil then window.selectedTab and window.selectedTab.tabPage else config.jumpTo
    if target then
        window.elementsLayout:JumpTo(target)
    end

    setPillShown(window, false, swapInfo)
    task.delay(swapInfo.Time, function()
        if not window._searching then
            window.searchPill.Visible = false
        end
    end)

    if config.showTabs then
        window.tabList.Visible = true
        setTabsShown(window, true, swapInfo)
    end

    variables.tweenService:Create(window.searchAction.iconLabel, swapInfo, { ImageTransparency = iconRest }):Play()
end

function search.toggle(window)
    if window._searching then
        search.close(window, { showTabs = true })
    else
        search.open(window)
    end
end

function search.build(window)
    window._searching = false

    -- Results page: a page like a tab's, holding whatever the search gathers.
    window.searchPage = window:Create("ScrollingFrame", {
        Name = "Search",
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0.5, 0, 0, 68),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        LayoutOrder = 2000, -- sits after every tab page

        Parent = window.elements,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, 7),
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = window.searchPage,
    })

    window:Create("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 33),

        Parent = window.searchPage,
    })

    -- Empty state, floated over the content area rather than in the results list so it centres
    -- cleanly. Only shown when a query matches nothing.
    window.searchEmpty = window:Create("TextLabel", {
        Name = "NoResults",
        Text = locale.t("No results"),
        FontFace = Font.new(constants.fontAsset, Enum.FontWeight.Medium),
        TextSize = 15,
        TextTransparency = 0.6,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.55, 0),
        Size = UDim2.fromOffset(200, 20),
        Visible = false,
        ZIndex = 3,

        Parent = window.main,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    -- Search pill: takes the tab strip's row. Ported from Window.Search.
    window.searchPill = window:Create("Frame", {
        Name = "SearchBar",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 66),
        Size = UDim2.new(1, -35, 0, 35),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 10,

        BackgroundTransparency = 1, -- shown = 0.9
        Visible = false,

        Parent = window.main,
    })

    window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = window.searchPill,
    })

    window.searchStroke = window:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Thickness = 1,

        Transparency = 1, -- shown = 0.85

        Parent = window.searchPill,
    })

    window.searchShadow = window:Create("UIShadow", {
        BlurRadius = UDim.new(0, 20),
        Color = Color3.fromRGB(255, 255, 255),
        ZIndex = -1,

        Transparency = 1, -- shown = 0.92

        Parent = window.searchPill,
    })

    window.searchIcon = window:Create("ImageLabel", {
        Image = "rbxassetid://" .. tostring(constants.icons.search),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 15, 0.5, 1),
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        ZIndex = 10,

        ImageTransparency = 1, -- shown = 0.65

        Parent = window.searchPill,
    }, { ImageColor3 = "ContentColor" })

    window.searchInput = window:Create("TextBox", {
        Text = "",
        PlaceholderText = locale.t("Search all pages"),
        PlaceholderColor3 = Color3.fromRGB(178, 178, 178),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 40, 0.5, 0),
        Size = UDim2.new(1, -110, 0, 18),
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ClipsDescendants = true,
        ZIndex = 10,

        TextTransparency = 1, -- shown = 0.2

        Parent = window.searchPill,
    }, { TextColor3 = "ContentColor", FontFace = "Font" })

    window:Connect(window.searchInput:GetPropertyChangedSignal("Text"), function()
        if window._searching then
            applyFilter(window, window.searchInput.Text)
        end
    end)

    -- Search action: last in the row (leftmost), toggles the field.
    window.searchAction = action.new(window, {
        name = "Search",
        icon = constants.icons.search,
        order = 4,

        callback = function()
            search.toggle(window)
        end,
    })
    -- keep the icon lit while the field is open, the way the settings cog stays lit on its page
    window.searchAction.isLit = function()
        return window._searching
    end
end

return search
