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

        Parent = self.window.screenGui
    })

    self.dragCosmetic = self.window:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.7,
        Size = UDim2.fromOffset(100, 4),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.3),
		ZIndex = 1000,

        Parent = self.drag,
    })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(0, 20),

        Parent = self.dragCosmetic
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

	-- add to window:connect
	local function connectFunctions()
		if self.drag then
			self.drag.MouseEnter:Connect(function()
				if not dragging and not variables.rayfieldHidden then
					variables.tweenService:Create(self.dragCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.5, Size = UDim2.new(0, 120, 0, 4)}):Play()
				end
			end)

			self.drag.MouseLeave:Connect(function()
				if not dragging and not variables.rayfieldHidden then
					variables.tweenService:Create(self.dragCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.7, Size = UDim2.new(0, 100, 0, 4)}):Play()
				end
			end)
		end
	end

	connectFunctions()

	self.dragInteract.InputBegan:Connect(function(input, processed)
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

	local inputEnded = variables.userInputService.InputEnded:Connect(function(input)
		if not dragging then return end

		local inputType = input.UserInputType.Name
		if inputType == "MouseButton1" or inputType == "Touch" then
			dragging = false

			connectFunctions()

			if not variables.rayfieldHidden then
				variables.tweenService:Create(self.dragCosmetic, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 100, 0, 4), BackgroundTransparency = 0.7}):Play()
			end
		end
	end)

	local renderStepped = variables.runService.RenderStepped:Connect(function()
		if dragging and not variables.rayfieldHidden then
			local position = variables.userInputService:GetMouseLocation() + relative + offset
			variables.tweenService:Create(self.window.main, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(position.X, position.Y)}):Play()
			variables.tweenService:Create(self.drag, TweenInfo.new(0.05, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(position.X, position.Y + (window.main.Size.Y.Offset / 2 + 15))}):Play()
		end
	end)

	--self.window.main.Destroying:Connect(function()
	--	if inputEnded then inputEnded:Disconnect() end
	--	if renderStepped then renderStepped:Disconnect() end
	--end)
end

return Drag