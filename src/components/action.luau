--!nonstrict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local Action = {}
Action.__index = Action
Action.__type = "Action"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local log = require(utility.log)
local hapticEngine = require(utility.HapticEngine)

function Action.new(window, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        name = properties.name or properties.Name or "Action",
        icon = assert(properties.icon or properties.Icon, "Missing argument (Icon expected)"),
        callback = assert(properties.callback or properties.Callback, "Missing argument (Function expected)"),
        linkedTab = properties.linkedTab or properties.LinkedTab,
    }, Action)

    self.action = self.window:Create("Frame", {
        Name = self.name,
        BorderSizePixel = 0,

        LayoutOrder = -(properties.order or 0),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,

        Parent = self.window.actionContainer,
    })

    self.iconLabel = self.window:Create("ImageLabel", {
        -- Configurables
        Image = self.icon,

        Size = UDim2.fromOffset(20, 20),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundTransparency = 1,

        -- Animation
        ImageTransparency = 1, -- In = 0.6

        Parent = self.action,
    }, { ImageColor3 = "ActionColor" })

    self.interact = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        TextTransparency = 1,

        Parent = self.action,
    })

    -- drop the icon back to its resting brightness, unless this action opens a tab that's
    -- currently selected (the settings cog stays lit while its page is open), or it reports
    -- itself lit some other way (the search action while the field is open)
    local function settleIcon()
        if self.linkedTab and self.window.selectedTab == self.linkedTab then
            return
        end
        if self.isLit and self:isLit() then
            return
        end
        variables.tweenService
            :Create(
                self.iconLabel,
                TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { ImageTransparency = 0.6 }
            )
            :Play()
    end

    self.window:Connect(self.interact.MouseButton1Click, function()
        hapticEngine.click()
        task.spawn(function()
            local success, result = pcall(self.callback)
            if not success then
                log.warn(
                    `Rayfield encountered an error, with the callback for a {self.__type} component named '{self.name}':`
                )
                log.print(result)
            end
            -- undo the hover brighten now (the callback has run, so selectedTab is up to date),
            -- otherwise the icon stays lit until the mouse happens to move off it
            settleIcon()
        end)
    end)

    self.window:Connect(self.interact.MouseEnter, function()
        if not self.window:_interactive() then
            return -- window still revealing/hiding: dont light up mid-animation
        end
        variables.tweenService
            :Create(
                self.iconLabel,
                TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { ImageTransparency = 0.2 }
            )
            :Play()
    end)

    self.window:Connect(self.interact.MouseLeave, settleIcon)

    return self
end

return Action
