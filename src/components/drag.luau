local Drag = {}
Drag.__index = Drag
Drag.__type = "Drag"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)

function Drag.new(window, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
    }, Drag)

	 -- Drag Point
	 self.drag = self.window:Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(150, 20),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 265),
		ZIndex = 1000,

		-- Animation
		Visible = false, -- In = true

        Parent = self.window.screenGui
    })

    self.dragCosmetic = self.window:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.3),
		ZIndex = 1000,

		-- Animation
		BackgroundTransparency = 1, -- In = 0.7
        Size = UDim2.fromOffset(0, 4), -- In = 100, 4

        Parent = self.drag,
    })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(0, 20),

        Parent = self.dragCosmetic
    })

    -- White glow behind the drag bar
    self.window:Create("UIShadow", {
        Color = Color3.fromRGB(255, 255, 255),
        BlurRadius = UDim.new(0, 10),
        Transparency = 0.5,
        ZIndex = -1,

        Parent = self.dragCosmetic,
    })

    self.dragInteract = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        TextTransparency = 1,
		ZIndex = 1000,

        Parent = self.drag,
    })

	local dragging = false
	local relative = nil

	local offset = Vector2.zero
	local screenGui = self.window.screenGui

	if screenGui and screenGui.IgnoreGuiInset then
		offset = variables.guiService:GetGuiInset()
	end

	self.window:Connect(self.drag.MouseEnter, function()
		if not dragging and not variables.rayfieldHidden then
			variables.tweenService:Create(self.dragCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.5, Size = UDim2.new(0, 120, 0, 4)}):Play()
		end
	end)

	self.window:Connect(self.drag.MouseLeave, function()
		if not dragging and not variables.rayfieldHidden then
			variables.tweenService:Create(self.dragCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.7, Size = UDim2.new(0, 100, 0, 4)}):Play()
		end
	end)

	self.window:Connect(self.dragInteract.InputBegan, function(input, processed)
		if processed then return end

		local inputType = input.UserInputType.Name
		if inputType == "MouseButton1" or inputType == "Touch" then
			dragging = true

			if screenGui and screenGui.IgnoreGuiInset then
				offset = variables.guiService:GetGuiInset()
			end

			relative = self.window.main.AbsolutePosition + self.window.main.AbsoluteSize * self.window.main.AnchorPoint - variables.userInputService:GetMouseLocation()
			if not variables.rayfieldHidden then
				variables.tweenService:Create(self.dragCosmetic, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 110, 0, 4), BackgroundTransparency = 0}):Play()
			end
		end
	end)

	self.window:Connect(variables.userInputService.InputEnded, function(input)
		if not dragging then return end

		local inputType = input.UserInputType.Name
		if inputType == "MouseButton1" or inputType == "Touch" then
			dragging = false

			if not variables.rayfieldHidden then
				variables.tweenService:Create(self.dragCosmetic, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 100, 0, 4), BackgroundTransparency = 0.7}):Play()
			end
		end
	end)

	local function getPosition()
		local mouseLocation = variables.userInputService and variables.userInputService:GetMouseLocation() or Vector2.new(0, 0)
		local validRelative = relative or Vector2.new(0, 0)
		local validOffset = offset or Vector2.new(0, 0)
	
		return mouseLocation + validRelative + validOffset
	end
	

	self.window:Connect(variables.runService.RenderStepped, function()
		if dragging and not variables.rayfieldHidden then
			local position = getPosition()
			variables.tweenService:Create(self.window.main, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(position.X, position.Y)}):Play()
			variables.tweenService:Create(self.drag, TweenInfo.new(0.05, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(position.X, position.Y + (window.main.Size.Y.Offset / 2 + 15))}):Play()
		end
	end)

	self.window:Connect(self.window.signal, function(command)
        if command == 'hide' then
           
        elseif command == 'show' then

        end
    end)

	return self
end

return Drag