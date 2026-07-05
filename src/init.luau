local rayfield = {}
local variables = require(script.utility.variables)
local image = require(script.utility.image)

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
    banner.Image = image.resolve(111263549366178)
    banner.Position = UDim2.fromScale(0.5, 0.5)
    banner.Size = UDim2.fromOffset(262, 60)
    banner.Parent = ui

    return ui
end

-- maybe add localization options with set languages ? 
-- add menu to choose language before continuing if there's no built-in service to check region

function rayfield:CreateWindow(properties)
    local banner = createBanner()

    if variables.secureMode and not image.preload() then
        -- TODO: once notifications land, surface a non-blocking notify here
        -- letting the user know secureMode degraded — at least one library
        -- asset failed to cache locally so it'll render empty. UI keeps going.
    end

    local window = require(script.components.window).new(properties)

    task.spawn(function()
        task.wait(0.5)

        banner:Destroy()

        task.wait(0.5)
        window:Show()
    end)

    return window
end




return rayfield

-- hello