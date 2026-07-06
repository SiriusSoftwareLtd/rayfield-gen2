local Button = {}
Button.__index = Button
Button.__type = "Button"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)

-- Compact (row) sizing.
local compactHeight = 41

function Button.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or "Button",
        icon = properties.icon or properties.Icon,
        description = properties.description or properties.Description,
        compact = tab.compact or false, -- true when the host is a Row

        callback = properties.callback or properties.Callback or function() end
    }, Button)

    if self.compact then
        self:_buildCompact()
    else
        self:_buildFull()
    end

    -- Descriptions don't belong on a compact row element.
    if self.description and not self.compact then
        self.descriptor = require(script.Parent.descriptor).new(self.tab, { description = self.description })
    end

    return self
end

-- callback + red error-flash, shared by both layouts
function Button:_runCallback()
    task.spawn(function()
        local success, result = pcall(function()
            self.callback()
        end)

        if not success then
            -- LOG ERROR IN WORKSPACE FILE. e.g logs.rfld
            variables.tweenService:Create(self.main, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = self.window.theme.ErrorColor}):Play()
            variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = self.window.theme.ErrorStrokeColor}):Play()
            self.title.Text = 'Error, log recorded in console.'

            warn(`Rayfield encountered an error, with the callback for a {self.__type} component named '{self.name}':`)
            print(result)

            task.wait(1)

            self.title.Text = self.name
            variables.tweenService:Create(self.main, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            variables.tweenService:Create(self.stroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = self.window.theme.ElementStroke}):Play()
        end
    end)
end

-- hover: brighten stroke + title (+ overlay if there is one)
function Button:_wireHover()
    self.window:Connect(self.main.MouseEnter, function()
        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeHoverTransparency, Color = self.window.theme.ElementStrokeHover}):Play()
        variables.tweenService:Create(self.title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextColor3 = self.window.theme.ElementTextHoverColor}):Play()
        if self.hoverOverlay then
            variables.tweenService:Create(self.hoverOverlay, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = 0.97}):Play()
        end
    end)

    self.window:Connect(self.main.MouseLeave, function()
        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeTransparency, Color = self.window.theme.ElementStroke}):Play()
        variables.tweenService:Create(self.title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextColor3 = self.window.theme.ContentColor}):Play()
        if self.hoverOverlay then
            variables.tweenService:Create(self.hoverOverlay, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
        end
    end)
end

-- full-width: title/icon left, width-bounce on press
function Button:_buildFull()
    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 43),
        BorderSizePixel = 0,
        Name = self.name,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),

        -- Animation
        BackgroundTransparency = 1, -- In = 0

        Parent = self.tab.tabPage,
    }, {BackgroundTransparency = 'ElementTransparency'})

    self.stroke = self.window:StyleElementBody(self.main)
    self.hoverOverlay = self.window:CreateHoverOverlay(self.main)

    self.container = self.window:Create("Frame", {
        BorderSizePixel = 0,

        Parent = self.main,
        Size = UDim2.new(0, 170, 0, 16),
        Position = UDim2.new(0, 20, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1
    })

    self.containerLayout = self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,

        Parent = self.container
    })

    if self.icon then
        self.iconLabel = self.window:Create("ImageLabel", {
            -- Configurables
            Image = 'rbxassetid://'..tostring(self.icon),

            -- Theming
            ImageColor3 = Color3.fromRGB(255, 255, 255),

            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,

            -- Animations
            ImageTransparency = 1, -- In = 0

            Parent = self.container
        }, {ImageColor3 = 'ContentColor'})
    end

    self.title = self.window:Create("TextLabel", {
        -- Configurables
        Text = self.name, -- tab name

        Size = UDim2.fromOffset(250, 16),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        AutomaticSize = Enum.AutomaticSize.X,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = 1,

        -- Animation
        TextTransparency = 1, -- In = 0

        Parent = self.container
    }, {TextColor3 = 'ContentColor', FontFace = 'Font'})

    self.interact = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        TextTransparency = 1,

        Parent = self.main,
    })

    self:_wireHover()

    -- press: ghost the stroke + squeeze the width around the callback
    self.window:Connect(self.interact.MouseButton1Click, function()
        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = 1}):Play()
        variables.tweenService:Create(self.main, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(1, -26, 0, 43)}):Play()

        self:_runCallback()

        task.wait(0.11)

        variables.tweenService:Create(self.main, TweenInfo.new(0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(1, -20, 0, 43)}):Play()
        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeTransparency}):Play()
    end)
end

-- compact (row): content-sized, centred icon+title, no width-bounce
function Button:_buildCompact()
    local window = self.window

    self.main = window:Create("Frame", {
        Name = self.name,
        Size = UDim2.fromOffset(0, compactHeight),
        AutomaticSize = Enum.AutomaticSize.X,
        ClipsDescendants = true, -- overflow guard
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,

        BackgroundTransparency = 1, -- In = ElementTransparency

        Parent = self.tab.tabPage,
    }, {BackgroundTransparency = 'ElementTransparency'})

    self.stroke = window:StyleElementBody(self.main)

    -- share the row width (grow + shrink)
    window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Fill,
        Parent = self.main,
    })

    -- main flows + fills the interact
    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,

        Parent = self.main,
    })

    -- clickable wrapper, doubles as the hover-brighten surface
    self.interact = window:Create("TextButton", {
        Text = "",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1, -- hover fades to 0.97
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, compactHeight),
        BorderSizePixel = 0,
        TextTransparency = 1,

        Parent = self.main,
    })
    self.hoverOverlay = self.interact

    window:Create("UICorner", {
        Parent = self.interact,
    }, {CornerRadius = 'ElementCornerRadius'})

    window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 16),
        PaddingRight = UDim.new(0, 16),

        Parent = self.interact,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UDim.new(0, 6),

        Parent = self.interact,
    })

    if self.icon then
        self.iconLabel = window:Create("ImageLabel", {
            Image = 'rbxassetid://'..tostring(self.icon),
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            Size = UDim2.fromOffset(16, 16),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            LayoutOrder = 0,

            ImageTransparency = 1, -- In = 0

            Parent = self.interact,
        }, {ImageColor3 = 'ContentColor'})
    end

    self.title = window:Create("TextLabel", {
        Text = self.name,
        Size = UDim2.fromOffset(0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,

        TextTransparency = 1, -- In = 0

        Parent = self.interact,
    }, {TextColor3 = 'ContentColor', FontFace = 'Font'})

    -- grows to its text, shrinks + ellipsizes when the row's tight
    window:Create("UIFlexItem", {
        FlexMode = Enum.UIFlexMode.Shrink,
        Parent = self.title,
    })

    self:_wireHover()

    -- press: ghost the stroke around the callback
    self.window:Connect(self.interact.MouseButton1Click, function()
        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = 1}):Play()

        self:_runCallback()

        task.wait(0.11)

        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeTransparency}):Play()
    end)
end


function Button:_setShown(animate)
    self.window:_revealCommon(self, animate)
end

function Button:MoveTo(index)
    self.tab:_moveElement(self, index)
end

function Button:MoveToTop()
    self.tab:_moveElement(self, 1)
end

function Button:MoveToBottom()
    self.tab:_moveElement(self, #self.tab.elements)
end

function Button:MoveUp()
    local idx = table.find(self.tab.elements, self)
    if idx then self.tab:_moveElement(self, idx - 1) end
end

function Button:MoveDown()
    local idx = table.find(self.tab.elements, self)
    if idx then self.tab:_moveElement(self, idx + 1) end
end


return Button
