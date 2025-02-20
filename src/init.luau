--!nocheck


local rayfield = Instance.new("ScreenGui")
rayfield.Name = "Rayfield"
rayfield.ClipToDeviceSafeArea = false
rayfield.DisplayOrder = 1e+05
rayfield.IgnoreGuiInset = true
rayfield.ResetOnSpawn = false
rayfield.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
rayfield.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
rayfield.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local banner = Instance.new("ImageLabel")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
banner.BackgroundTransparency = 1
banner.BorderColor3 = Color3.fromRGB(0, 0, 0)
banner.BorderSizePixel = 0
banner.Image = "rbxassetid://111263549366178"
banner.Position = UDim2.fromScale(0.5, 0.5)
banner.Size = UDim2.fromOffset(262, 60)
banner.Parent = rayfield

return require(script.components.window)

-- hello