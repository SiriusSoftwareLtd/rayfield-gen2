-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Window furniture: the collapsed "Show" face main wears while hidden (window.collapsed*
-- fields), plus the first-open new-user check. The welcome greeting itself is just a toast now.

local utility = script.Parent.Parent.utility
local variables = require(utility.variables)
local filesystem = require(utility.filesystem)
local constants = require(utility.constants)
local locale = require(utility.locale)
local hapticEngine = require(utility.HapticEngine)

local chrome = {}

-- The face main wears once collapsed: an icon + "name"/"Tap to show", drawn straight onto
-- the window frame itself. main already carries the pill's background (its own WindowColor
-- gradient reads the same as the old standalone pill), so shrinking main IS becoming the
-- pill - nothing to hand off to, nothing to swap.
function chrome.buildCollapsedFace(window)
    window.collapsedIcon = window:Create("ImageLabel", {
        Name = "CollapsedIcon",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 16, 0.5, 0),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        -- raw value: Create routes Image through image.resolve (concat would double the prefix)
        Image = tonumber(window.showIcon) or window.showIcon,
        ZIndex = constants.zIndex.restoreContent,

        ImageTransparency = 1, -- shown = 0, set by chrome.setCollapsedShown

        Parent = window.main,
    }, { ImageColor3 = "TitlingColor" })

    window:Create("UICorner", {
        Parent = window.collapsedIcon,
    }, { CornerRadius = "PillCornerRadius" })

    local textContainer = window:Create("Frame", {
        Name = "CollapsedText",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 50, 0.5, 0),
        Size = UDim2.new(1, -60, 0, 32),
        BackgroundTransparency = 1,
        ZIndex = constants.zIndex.restoreContent,

        Parent = window.main,
    })

    window:Create("UIListLayout", {
        Padding = UDim.new(0, 1),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = textContainer,
    })

    window.collapsedTitle = window:Create("TextLabel", {
        Name = "Title",
        Text = window.showName,
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        FontFace = variables.brandFont(Enum.FontWeight.Medium),
        RichText = true,
        TextSize = 16,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        ZIndex = constants.zIndex.restoreContent,

        TextTransparency = 1, -- shown = 0, set by chrome.setCollapsedShown

        Parent = textContainer,
    }, { TextColor3 = "TitlingColor" })

    window.collapsedSubtitle = window:Create("TextLabel", {
        Name = "Subtitle",
        Text = locale.t("Tap to show"),
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        FontFace = variables.brandFont(Enum.FontWeight.Medium),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
        ZIndex = constants.zIndex.restoreContent,

        TextTransparency = 1, -- shown = 0.5, set by chrome.setCollapsedShown

        Parent = textContainer,
    }, { TextColor3 = "TitlingColor" })

    -- covers the whole window but only takes clicks while collapsed - Window:Hide/Show flip
    -- Visible as the morph starts/settles so it can never eat a click mid-animation or while
    -- the window is fully open. Active alone doesn't stop a GuiButton from still receiving
    -- clicks here, so Visible is what actually keeps it out of hit-testing.
    window.collapsedInteract = window:Create("TextButton", {
        Name = "CollapsedInteract",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        TextTransparency = 1,
        Visible = false,
        ZIndex = constants.zIndex.restoreInteract,

        Parent = window.main,
    })

    window:Connect(window.collapsedInteract.MouseButton1Click, function()
        hapticEngine.click()
        window:ToggleHide()
    end)
end

function chrome.isNewUser()
    -- No filesystem available - just show the banner every launch.
    if typeof(filesystem.isfile) ~= "function" or typeof(filesystem.writefile) ~= "function" then
        return true
    end

    local path = variables.fileSystemManager:getPath("lastuser.txt")
    local currentId = tostring(variables.localPlayer.UserId)
    local isNew = true

    pcall(function()
        if filesystem.isfile(path) then
            isNew = filesystem.readfile(path) ~= currentId
        end
    end)

    pcall(function()
        filesystem.writefile(path, currentId)
    end)

    return isNew
end

-- Fade the collapsed face (icon + labels) in or out as main morphs into/out of the pill.
-- When tweenInfo is nil the values snap instantly.
function chrome.setCollapsedShown(window, shown, tweenInfo)
    local targets = {
        [window.collapsedIcon] = { ImageTransparency = if shown then 0 else 1 },
        [window.collapsedTitle] = { TextTransparency = if shown then 0 else 1 },
        [window.collapsedSubtitle] = { TextTransparency = if shown then 0.5 else 1 },
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

return chrome
