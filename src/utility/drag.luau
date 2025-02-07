local drag = {}

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)

-- formula for tapticOffset = object.Size.Y.Offset / 2 + 15

function drag.add(object, dragObject, enableTaptic)
	local dragging = false
	local relative = nil

	local offset = Vector2.zero
	local screenGui = object:FindFirstAncestorWhichIsA("ScreenGui")
	if screenGui and screenGui.IgnoreGuiInset then
		offset += variables.guiService:GetGuiInset()
	end

    local function createDrag()
        -- create drag object.. maybe add this to components instead.
    end

	local function connectFunctions()
		if dragBar and enableTaptic then
			dragBar.MouseEnter:Connect(function()
				if not dragging and not variables.rayfieldHidden then
					variables.tweenService:Create(dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.5, Size = UDim2.new(0, 120, 0, 4)}):Play()
				end
			end)

			dragBar.MouseLeave:Connect(function()
				if not dragging and not variables.rayfieldHidden then
					variables.tweenService:Create(dragBarCosmetic, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.7, Size = UDim2.new(0, 100, 0, 4)}):Play()
				end
			end)
		end
	end

	connectFunctions()

	dragObject.InputBegan:Connect(function(input, processed)
		if processed then return end

		local inputType = input.UserInputType.Name
		if inputType == "MouseButton1" or inputType == "Touch" then
			dragging = true

			relative = object.AbsolutePosition + object.AbsoluteSize * object.AnchorPoint - variables.userInputService:GetMouseLocation()
			if enableTaptic and not variables.rayfieldHidden then
				variables.tweenService:Create(dragBarCosmetic, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 110, 0, 4), BackgroundTransparency = 0}):Play()
			end
		end
	end)

	local inputEnded = variables.userInputService.InputEnded:Connect(function(input)
		if not dragging then return end

		local inputType = input.UserInputType.Name
		if inputType == "MouseButton1" or inputType == "Touch" then
			dragging = false

			connectFunctions()

			if enableTaptic and not variables.rayfieldHidden then
				variables.tweenService:Create(dragBarCosmetic, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 100, 0, 4), BackgroundTransparency = 0.7}):Play()
			end
		end
	end)

	local renderStepped = variables.runService.RenderStepped:Connect(function()
		if dragging and not variables.rayfieldHidden then
			local position = variables.userInputService:GetMouseLocation() + relative + offset
			if enableTaptic then
				variables.tweenService:Create(object, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(position.X, position.Y)}):Play()
				variables.tweenService:Create(dragObject.Parent, TweenInfo.new(0.05, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(position.X, position.Y + (object.Size.Y.Offset / 2 + 15))}):Play()
			else
				if dragBar then
					dragBar.Position = UDim2.fromOffset(position.X, position.Y + (object.Size.Y.Offset / 2 + 15))
				end
				object.Position = UDim2.fromOffset(position.X, position.Y)
			end
		end
	end)

	object.Destroying:Connect(function()
		if inputEnded then inputEnded:Disconnect() end
		if renderStepped then renderStepped:Disconnect() end
	end)
end

return drag