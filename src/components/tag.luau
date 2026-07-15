-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local Tag = {}
Tag.__index = Tag
Tag.__type = "Tag"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local functions = require(utility.functions)
local image = require(utility.image)

local defaultColor = Color3.fromRGB(255, 175, 15)
local setTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

function Tag.new(window, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        text = properties.text or properties.Text or properties.title or properties.Title,
        icon = properties.icon or properties.Icon,
        color = properties.color or properties.Color or defaultColor,
    }, Tag)

    assert(self.icon or (self.text and self.text ~= ""), "A Tag requires an icon, text, or both.")

    self.main = self.window:Create("Frame", {
        Name = "Tag",
        Size = UDim2.fromOffset(10, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = self.color,
        BorderSizePixel = 0,
        LayoutOrder = properties.order or properties.Order or 0,

        -- Animation
        BackgroundTransparency = 1, -- In = 0

        Parent = self.window.tagContainer,
    })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(1, 0),

        Parent = self.main,
    })

    self.window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),

        Parent = self.main,
    })

    self.window:Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,

        Parent = self.main,
    })

    local contrast = functions.contrastColor(self.color)

    self.iconLabel = self.window:Create("ImageLabel", {
        Name = "Icon",
        Image = self.icon or "",
        ImageColor3 = contrast,
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        Visible = self.icon ~= nil,
        ZIndex = 5,

        -- Animation
        ImageTransparency = 1, -- In = 0

        Parent = self.main,
    })

    self.title = self.window:Create("TextLabel", {
        Name = "Title",
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.fromOffset(10, 15),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = self.text or "",
        TextColor3 = contrast,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        RichText = true,
        Visible = self.text ~= nil and self.text ~= "",
        LayoutOrder = 1,
        ZIndex = 5,

        -- Animation
        TextTransparency = 1, -- In = 0

        Parent = self.main,
    }, { FontFace = "Font" })

    self.window.tagContainer.Visible = true

    -- if the window's already up, fade in now; otherwise its show handles it
    if not self.window.hidden then
        self:_setShown(true, setTweenInfo)
    end

    return self
end

-- animate is a boolean like every other element's _setShown, or a TweenInfo when a caller
-- (the window's show/hide) wants its own timing. true uses the tag's default fade.
function Tag:_setShown(shown, animate)
    local target = if shown then 0 else 1
    local info = if typeof(animate) == "TweenInfo" then animate elseif animate then setTweenInfo else nil
    if info then
        variables.tweenService:Create(self.main, info, { BackgroundTransparency = target }):Play()
        variables.tweenService:Create(self.iconLabel, info, { ImageTransparency = target }):Play()
        variables.tweenService:Create(self.title, info, { TextTransparency = target }):Play()
    else
        self.main.BackgroundTransparency = target
        self.iconLabel.ImageTransparency = target
        self.title.TextTransparency = target
    end
end

function Tag:SetColor(color)
    self.color = color
    local contrast = functions.contrastColor(color)
    variables.tweenService:Create(self.main, setTweenInfo, { BackgroundColor3 = color }):Play()
    variables.tweenService:Create(self.iconLabel, setTweenInfo, { ImageColor3 = contrast }):Play()
    variables.tweenService:Create(self.title, setTweenInfo, { TextColor3 = contrast }):Play()
end

function Tag:SetText(text)
    self.text = text
    self.title.Text = text or ""
    self.title.Visible = text ~= nil and text ~= ""
end

function Tag:SetIcon(icon)
    self.icon = icon
    image.assign(self.iconLabel, "Image", icon)
    self.iconLabel.Visible = icon ~= nil
end

function Tag:Set(properties)
    if properties.color or properties.Color then
        self:SetColor(properties.color or properties.Color)
    end
    if properties.text or properties.Text or properties.title or properties.Title then
        self:SetText(properties.text or properties.Text or properties.title or properties.Title)
    end
    if properties.icon ~= nil or properties.Icon ~= nil then
        self:SetIcon(properties.icon or properties.Icon)
    end
end

function Tag:Remove()
    self.main:Destroy()
    local idx = table.find(self.window.tags, self)
    if idx then
        table.remove(self.window.tags, idx)
    end
    if #self.window.tags == 0 then
        self.window.tagContainer.Visible = false
    end
end

return Tag
