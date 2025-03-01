local rayfield = {}
local variables = require(script.utility.variables)

local function createBanner()
    local ui = Instance.new("ScreenGui")
    ui.Name = "Rayfield"
    ui.ClipToDeviceSafeArea = false
    ui.DisplayOrder = 1e+05
    ui.IgnoreGuiInset = true
    ui.ResetOnSpawn = false
    ui.Enabled = true
    ui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
    ui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
    ui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ui.Parent = variables.guiContainer

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
    banner.Parent = ui

    return ui
end

function rayfield:CreateWindow(properties)
    local banner = createBanner()

    local window = require(script.components.window).new(properties)

    task.spawn(function()
        task.wait(1.5)

        banner:Destroy()

        task.wait(0.5)
        window:Show()
    end)

    return window
end




return rayfield

-- hello