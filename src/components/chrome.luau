-- Window furniture: the restore button (shown while hidden) and the "signed in as" card.
-- Each builds into the window, setting the window.restore* / window.license* fields.

local utility = script.Parent.Parent.utility
local variables = require(utility.variables)
local filesystem = require(utility.filesystem)
local constants = require(utility.constants)

local chrome = {}

function chrome.buildRestoreButton(window)
    window.restoreButton = window:Create("Frame", {
        Name = "Show",
        Size = UDim2.fromOffset(185, 50),
        Position = UDim2.new(0.5, 0, 0, 20),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = constants.zIndex.restoreBase,

        BackgroundTransparency = 0,

        Parent = window.screenGui,
    })

    window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),

        Parent = window.restoreButton,
    })

    window.restoreStroke = window:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 0.9,

        Parent = window.restoreButton,
    })

    window:Create("UIGradient", {
        Rotation = 270,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 13, 13)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(27, 27, 27)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 35, 35)),
        }),

        Parent = window.restoreButton,
    })

    window.restoreIcon = window:Create("ImageLabel", {
        Name = "icon",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 16, 0.5, 0),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        Image = "rbxassetid://" .. tostring(window.showIcon),
        ZIndex = constants.zIndex.restoreContent,

        ImageTransparency = 0,

        Parent = window.restoreButton,
    })

    window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),

        Parent = window.restoreIcon,
    })

    local textContainer = window:Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 50, 0.5, 0),
        Size = UDim2.new(1, -60, 0, 32),
        BackgroundTransparency = 1,
        ZIndex = constants.zIndex.restoreContent,

        Parent = window.restoreButton,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, 1),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = textContainer,
    })

    window.restoreLabel = window:Create("TextLabel", {
        Name = "Title",
        Text = window.showName,
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        FontFace = Font.new(constants.fontAsset, Enum.FontWeight.Medium),
        RichText = true,
        TextColor3 = Color3.fromRGB(240, 240, 240),
        TextSize = 16,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        ZIndex = constants.zIndex.restoreContent,

        TextTransparency = 0,

        Parent = textContainer,
    })

    window.restoreSubtitle = window:Create("TextLabel", {
        Name = "License",
        Text = "Tap to show",
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        FontFace = Font.new(constants.fontAsset, Enum.FontWeight.Medium),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
        ZIndex = constants.zIndex.restoreContent,

        TextTransparency = 0.5,

        Parent = textContainer,
    })

    local restoreInteract = window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        TextTransparency = 1,
        ZIndex = constants.zIndex.restoreInteract,

        Parent = window.restoreButton,
    })

    window:Connect(restoreInteract.MouseButton1Click, function()
        window:ToggleHide()
    end)
end

function chrome.buildLicense(window)
    -- "Signed in as" welcome card, shown once for a new/changed account (sits above the topbar)
    window.license = window:Create("Frame", {
        Name = "License",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 0, 65),
        Size = UDim2.fromOffset(200, 50),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 0,
        Visible = false,

        Parent = window.main,
    })

    window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),

        Parent = window.license,
    })

    window.licenseStroke = window:Create("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 1, -- In = 0.9

        Parent = window.license,
    })

    window:Create("UIGradient", {
        Rotation = 270,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 13, 13)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(27, 27, 27)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 35, 35)),
        }),

        Parent = window.license,
    })

    window.licenseAvatar = window:Create("ImageLabel", {
        Name = "Avatar",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 10, 0.5, 0),
        Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 0,
        Image = `rbxthumb://type=AvatarHeadShot&id={variables.localPlayer.UserId}&w=48&h=48`,

        -- Animation
        BackgroundTransparency = 1, -- In = 0.95
        ImageTransparency = 1, -- In = 0

        Parent = window.license,
    })

    window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),

        Parent = window.licenseAvatar,
    })

    local container = window:Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 50, 0.5, 0),
        Size = UDim2.new(1, -60, 0, 32),
        BackgroundTransparency = 1,
        ZIndex = 0,

        Parent = window.license,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, 1),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = container,
    })

    window.licenseSubtitle = window:Create("TextLabel", {
        Name = "License",
        Text = "Signed in as",
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        FontFace = Font.new(constants.fontAsset, Enum.FontWeight.Medium),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 0,

        -- Animation
        TextTransparency = 1, -- In = 0.5

        Parent = container,
    })

    window.licenseTitle = window:Create("TextLabel", {
        Name = "Title",
        Text = variables.localPlayer.DisplayName,
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        FontFace = Font.new(constants.fontAsset, Enum.FontWeight.Medium),
        RichText = true,
        TextColor3 = Color3.fromRGB(240, 240, 240),
        TextSize = 16,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        ZIndex = 0,

        -- Animation
        TextTransparency = 1, -- In = 0

        Parent = container,
    })
end

function chrome.isNewUser()
    -- No filesystem available - just show the banner every launch.
    if typeof(filesystem.isfile) ~= "function" or typeof(filesystem.writefile) ~= "function" then
        return true
    end

    local path = "Rayfield/lastuser.txt"
    local currentId = tostring(variables.localPlayer.UserId)
    local isNew = true

    pcall(function()
        if filesystem.isfile(path) then
            isNew = filesystem.readfile(path) ~= currentId
        end
    end)

    pcall(function()
        if typeof(filesystem.isfolder) == "function" and not filesystem.isfolder("Rayfield") then
            filesystem.makefolder("Rayfield")
        end
        filesystem.writefile(path, currentId)
    end)

    return isNew
end

-- fade as well as slide, so minimising mid-animation just fades it out cleanly
local function setLicenseShown(window, shown, tweenInfo)
    local targets = {
        [window.license] = { BackgroundTransparency = if shown then 0 else 1 },
        [window.licenseStroke] = { Transparency = if shown then 0.9 else 1 },
        [window.licenseAvatar] = {
            BackgroundTransparency = if shown then 0.95 else 1,
            ImageTransparency = if shown then 0 else 1,
        },
        [window.licenseSubtitle] = { TextTransparency = if shown then 0.5 else 1 },
        [window.licenseTitle] = { TextTransparency = if shown then 0 else 1 },
    }

    for instance, props in targets do
        if tweenInfo then
            variables.tweenService:Create(instance, tweenInfo, props):Play()
        else
            for property, value in props do
                instance[property] = value
            end
        end
    end
end

function chrome.playLicenseBanner(window)
    task.spawn(function()
        local slideInfo = TweenInfo.new(0.7, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

        window.license.Position = UDim2.new(0, 0, 0, 65)
        setLicenseShown(window, false)
        window.license.Visible = true

        -- Slide down + fade in, hold ~3s, then slide back up + fade out and hide.
        variables.tweenService:Create(window.license, slideInfo, { Position = UDim2.new(0, 0, 0, -8) }):Play()
        setLicenseShown(window, true, slideInfo)

        task.wait(3)

        variables.tweenService:Create(window.license, slideInfo, { Position = UDim2.new(0, 0, 0, 65) }):Play()
        setLicenseShown(window, false, slideInfo)

        task.wait(0.7)
        window.license.Visible = false
    end)
end

return chrome
