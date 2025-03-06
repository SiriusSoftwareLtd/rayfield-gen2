local Stat = {}
Stat.__index = Stat
Stat.__type = "Stat"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)

function Stat.new(tab, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        tab = assert(tab, "Missing argument #1 (Tab expected)"),
        window = tab.window,
        name = properties.name or properties.Name or "Stat",
        icon = properties.icon or properties.Icon,

        callback = properties.callback or properties.Callback or function() end,

        value = if (properties.value or properties.Value) ~= nil then (properties.value or properties.Value) else false,
    }, Stat)

    self.main = self.window:Create("Frame", {
        Size = UDim2.new(1, -20, 0, 43),
        BorderSizePixel = 0,
        Name = self.name,

        LayoutOrder = 0,

        BackgroundTransparency = 1,

        Parent = self.tab.tabPage,
    }, {BackgroundColor3 = 'ElementColor', BackgroundTransparency = 'ElementTransparency'})



    -- Function
    self.window:Connect(self.interact.MouseButton1Click, function() 

        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = 1}):Play()
        variables.tweenService:Create(self.main, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(1, -26, 0, 43)}):Play()
  
        self.value = not self.value

        if self.value then
            variables.tweenService:Create(self.indicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = UDim2.new(1, -20, 0.5, 0)}):Play()
            variables.tweenService:Create(self.indicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(23, 153, 110)}):Play()
            variables.tweenService:Create(self.indicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
            variables.tweenService:Create(self.indicatorStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Color = Color3.fromRGB(32, 201, 144)}):Play()
            variables.tweenService:Create(self.indicatorStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = 0}):Play()
        else
            variables.tweenService:Create(self.indicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = UDim2.new(1, -40, 0.5, 0)}):Play()
            variables.tweenService:Create(self.indicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            variables.tweenService:Create(self.indicator, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0.8}):Play()
            variables.tweenService:Create(self.indicatorStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Color = Color3.fromRGB(255, 255, 255)}):Play()
            variables.tweenService:Create(self.indicatorStroke, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = 0.7}):Play()
        end

        task.spawn(function() 
            local success, result = pcall(function()
                self.callback(self.value)
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
                variables.tweenService:Create(self.main, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {BackgroundColor3 = self.window.theme.ElementColor}):Play()
                variables.tweenService:Create(self.stroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = self.window.theme.ElementStroke}):Play()
            end
        end)

        task.wait(0.11)

        variables.tweenService:Create(self.main, TweenInfo.new(0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = UDim2.new(1, -20, 0, 43)}):Play()
        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeTransparency}):Play()
    end)

    self.window:Connect(self.main.MouseEnter, function()
        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeHoverTransparencyColor, Color = self.window.theme.ElementStrokeHover}):Play()
        variables.tweenService:Create(self.title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextColor3 = self.window.theme.ElementTextHoverColor}):Play()
        variables.tweenService:Create(self.main, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = self.window.theme.ElementHoverTransparency, BackgroundColor3 = self.window.theme.ElementHoverColor}):Play()
    end)

    self.window:Connect(self.main.MouseLeave, function()
        variables.tweenService:Create(self.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeTransparency, Color = self.window.theme.ElementStroke}):Play()
        variables.tweenService:Create(self.title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextColor3 = self.window.theme.ContentColor}):Play()
        variables.tweenService:Create(self.main, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = self.window.theme.ElementTransparency, BackgroundColor3 = self.window.theme.ElementColor}):Play()
    end)

    self.window:Connect(self.window.signal, function(command)
        if command == 'hide' then
            if not self.neglectSelector then
                self.topbarItem.Visible = false
            end
        elseif command == 'show' then
            task.wait(0.7)
            variables.tweenService:Create(self.stroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Transparency = self.window.theme.ElementStrokeTransparency}):Play()
            variables.tweenService:Create(self.title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
            variables.tweenService:Create(self.main, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
            if self.icon then variables.tweenService:Create(self.icon, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = 0}):Play() end
        end
    end)

    return self
end

return Toggle
