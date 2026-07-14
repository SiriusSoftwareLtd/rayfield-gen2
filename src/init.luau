local rayfield = {}
local variables = require(script.utility.variables)
local image = require(script.utility.image)
local constants = require(script.utility.constants)
local types = require(script.types)

-- re-export public types so consumers can annotate against Rayfield.Window etc
export type WindowProps = types.WindowProps
export type Window = types.Window
export type Tab = types.Tab
export type Group = types.Group
export type Button = types.Button
export type Toggle = types.Toggle
export type Slider = types.Slider
export type Dropdown = types.Dropdown
export type Input = types.Input
export type Keybind = types.Keybind
export type Stat = types.Stat
export type Section = types.Section
export type Popup = types.Popup

local function createBanner()
    local ui = Instance.new("ScreenGui")
    ui.Name = variables.httpService:GenerateGUID(false)
    ui.ClipToDeviceSafeArea = false
    ui.DisplayOrder = constants.displayOrder.banner
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
    banner.Image = image.resolve(constants.icons.banner)
    banner.Position = UDim2.fromScale(0.5, 0.5)
    banner.Size = UDim2.fromOffset(262, 60)
    banner.Parent = ui

    return ui
end

function rayfield:CreateWindow(properties: types.WindowProps): types.Window
    local banner = createBanner()

    if variables.secureMode then
        -- cache icons locally so secureMode doesnt leak asset ids. non-blocking: whats already on
        -- disk applies now, the rest download in the background and pop in once ready
        image.preload()
    end

    local window = require(script.components.window).new(properties)

    if variables.secureMode then
        -- secure mode renders BuilderSans up front (variables.brandFont), then downloads the real
        -- brand faces off the main thread and swaps them in once ready, so startup never blocks
        task.spawn(function()
            local body = variables.fontManager:loadFont(constants.fontAsset, Enum.FontWeight.Medium)
            local title = variables.fontManager:loadFont(constants.fontAsset, Enum.FontWeight.SemiBold)
            local fallback = variables.fontManager.defaultOptions.fallbackFont
            if body and title and body ~= fallback and title ~= fallback then
                window:ChangeTheme({ Font = body, TitleFont = title })
            end
        end)
    end

    task.spawn(function()
        task.wait(0.5)

        banner:Destroy()

        task.wait(0.5)
        window:Show()
    end)

    return window :: any
end

return rayfield :: types.Rayfield
