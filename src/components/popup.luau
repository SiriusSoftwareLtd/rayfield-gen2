-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Popup: a modal that dims the screen and floats a card in the centre. Modular by design -
-- give it a title and buttons for a choice dialog, or a list of boxes for a changelog. Built
-- from the window's own gradient/corner/stroke/shadow so it reads as part of the same UI.

local Popup = {}
Popup.__index = Popup
Popup.__type = "Popup"

-- Utility
local utility = script.Parent.Parent.utility
local variables = require(utility.variables)
local functions = require(utility.functions)
local constants = require(utility.constants)
local locale = require(utility.locale)
local log = require(utility.log)
local hapticEngine = require(utility.HapticEngine)

-- Timings (Exponential Out, matching the notification/toast feel).
local enterInfo = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out) -- card rise-in
local fadeLong = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out) -- fill + stroke
local fadeShort = TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out) -- content + shadow
local backdropInfo = TweenInfo.new(0.35, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

-- Card metrics.
local cardWidth = 400
local sidePadding = 22
local topPadding = 24
local bottomPadding = 22
local regionGap = 16 -- between header, content and footer
local innerWidth = cardWidth - sidePadding * 2

local titleSize = 18
local subtitleSize = 14
local contentSize = 15
local headerIconSize = 16
local headerIconGap = 12 -- icon to title-column
local maxContentHeight = 300 -- content region scrolls past this
-- the content scrolls, so it clips its children; this inset keeps box strokes off the edge
local contentInset = 4
local contentWidth = innerWidth - contentInset * 2

-- Box (changelog card) metrics.
local boxSidePad = 16
local boxVerticalPad = 13
local boxIconSize = 20
local boxIconGap = 10
local boxTitleSize = 15
local boxDescSize = 14
local boxGap = 8
local boxWidthInset = 10 -- boxes sit a touch narrower so they clear the scrollbar

-- Footer buttons.
local buttonHeight = 40
local buttonGap = 8
local buttonCorner = UDim.new(1, 0) -- pill
local buttonTextSize = 16

local backdropShown = 0.5 -- how dark the dim gets

function Popup.new(window, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
        title = properties.title or properties.Title or "Popup",
        subtitle = properties.subtitle or properties.Subtitle,
        content = properties.content or properties.Content,
        icon = properties.icon or properties.Icon,
        boxes = properties.boxes or properties.Boxes,
        options = properties.options or properties.Options,
        -- click the dim or press Escape to close (no callback fires). On by default.
        dismissable = if properties.dismissable ~= nil
            then properties.dismissable
            elseif properties.Dismissable ~= nil then properties.Dismissable
            else true,
        _reveal = {}, -- { instance, prop, to } fadeables, tweened in on show and out on close
        _connections = {},
        _closed = false,
    }, Popup)

    -- default to a single dismiss button so a bare popup still closes
    if not self.options or #self.options == 0 then
        self.options = { { text = "Okay" } }
    end

    self:_build()
    task.spawn(function()
        self:_show()
    end)

    return self
end

-- Register a transparency-driven instance so _show can fade it in (to `to`) and _dismiss can
-- fade it back out (to 1). Every fadeable funnels here so the two directions stay in sync.
function Popup:_fade(instance, prop, to)
    table.insert(self._reveal, { instance = instance, prop = prop, to = to })
    return instance
end

function Popup:_build()
    local window = self.window
    local hasIcon = self.icon ~= nil and self.icon ~= 0 and self.icon ~= ""

    -- Own ScreenGui so the modal sits above the window, toasts and notifications alike.
    self.screenGui = window:Create("ScreenGui", {
        Name = variables.httpService:GenerateGUID(false),
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        Enabled = true,
        DisplayOrder = constants.displayOrder.popup,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,

        Parent = variables.guiContainer,
    })

    -- Dim backdrop, also the click-to-dismiss surface and the input sink for everything below.
    -- A plain Active frame, not a button - it only needs to swallow input, so a frame is the
    -- right primitive.
    self.backdrop = window:Create("Frame", {
        Name = "Backdrop",
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Active = true,

        BackgroundTransparency = 1, -- shown = backdropShown

        Parent = self.screenGui,
    })
    self:_fade(self.backdrop, "BackgroundTransparency", backdropShown)

    -- Card: the window's own look (white base + gradient + rounded corner + stroke + glow).
    self.card = window:Create("Frame", {
        Name = "Card",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 14), -- drifts up to centre on show
        Size = UDim2.fromOffset(cardWidth, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Active = true, -- clicks on the card never reach the backdrop
        BorderSizePixel = 0,

        BackgroundTransparency = 1, -- shown = 0

        Parent = self.screenGui,
    })
    self:_fade(self.card, "BackgroundTransparency", 0)

    window:Create("UIGradient", {
        Rotation = 270,
        Offset = Vector2.new(0, -0.1),

        Parent = self.card,
    }, { Color = { "WindowColor", functions.toColorSequence } })

    window:Create("UICorner", {
        Parent = self.card,
    }, { CornerRadius = "CornerRoundness" })

    self.cardStroke = window:Create("UIStroke", {
        Transparency = 1, -- shown = 0.95

        Parent = self.card,
    }, { Color = "SurfaceStroke" })
    self:_fade(self.cardStroke, "Transparency", 0.95)

    self.cardShadow = window:CreateGlow(self.card, "ShadowColor", 26, 1) -- shown = 0.55
    self:_fade(self.cardShadow, "Transparency", 0.55)

    window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, sidePadding),
        PaddingRight = UDim.new(0, sidePadding),
        PaddingTop = UDim.new(0, topPadding),
        PaddingBottom = UDim.new(0, bottomPadding),

        Parent = self.card,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, regionGap),

        Parent = self.card,
    })

    -- Pre-measure like the notifications do, then lock the card to a fixed height. Otherwise the
    -- card grows a few pixels a moment after it shows, as the brand font's glyphs finish loading
    -- and AutomaticSize re-measures the text - reads as the font "settling" after the reveal.
    local headerHeight = self:_measureHeader(hasIcon)
    self:_buildHeader(hasIcon, headerHeight)
    local contentHeight = self:_buildContent()
    self:_buildFooter()

    local regions = 2 + (contentHeight > 0 and 1 or 0) -- header, footer, and content if present
    local cardHeight = topPadding
        + headerHeight
        + contentHeight
        + buttonHeight
        + bottomPadding
        + regionGap * (regions - 1)
    self.card.Size = UDim2.fromOffset(cardWidth, cardHeight)
    self.card.AutomaticSize = Enum.AutomaticSize.None

    -- dismiss surfaces
    if self.dismissable then
        table.insert(
            self._connections,
            window:Connect(self.backdrop.InputBegan, function(input)
                if
                    input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch
                then
                    self:Close()
                end
            end)
        )
        table.insert(
            self._connections,
            window:Connect(variables.userInputService.InputBegan, function(input, processed)
                if not processed and input.KeyCode == Enum.KeyCode.Escape then
                    self:Close()
                end
            end)
        )
    end
end

function Popup:_buildHeader(hasIcon, headerHeight)
    local window = self.window

    local header = window:Create("Frame", {
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, headerHeight),
        LayoutOrder = 1,

        Parent = self.card,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, headerIconGap),

        Parent = header,
    })

    if hasIcon then
        self:_fade(
            window:Create("ImageLabel", {
                Image = self.icon,
                Size = UDim2.fromOffset(headerIconSize, headerIconSize),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = 1,

                ImageTransparency = 1, -- shown = 0

                Parent = header,
            }, { ImageColor3 = "TitlingColor" }),
            "ImageTransparency",
            0
        )
    end

    local textColumn = window:Create("Frame", {
        Name = "Text",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, hasIcon and -(headerIconSize + headerIconGap) or 0, 0, self._columnH),
        LayoutOrder = 2,

        Parent = header,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),

        Parent = textColumn,
    })

    self:_fade(
        window:Create("TextLabel", {
            Text = locale.t(self.title),
            Size = UDim2.new(1, 0, 0, self._titleH),
            BackgroundTransparency = 1,
            TextSize = titleSize,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            LayoutOrder = 1,

            TextTransparency = 1, -- shown = 0

            Parent = textColumn,
        }, { TextColor3 = "TitlingColor", FontFace = "Font" }),
        "TextTransparency",
        0
    )

    if self.subtitle and self.subtitle ~= "" then
        self:_fade(
            window:Create("TextLabel", {
                Text = locale.t(self.subtitle),
                Size = UDim2.new(1, 0, 0, self._subH),
                BackgroundTransparency = 1,
                TextSize = subtitleSize,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                LayoutOrder = 2,

                TextTransparency = 1, -- shown = 0.55

                Parent = textColumn,
            }, { TextColor3 = "TitlingColor", FontFace = "Font" }),
            "TextTransparency",
            0.55
        )
    end
end

-- The middle region: a paragraph, a list of boxes, or nothing. Whichever it is, it lives in a
-- scrolling frame capped at maxContentHeight so a long changelog scrolls instead of running off.
function Popup:_buildContent()
    if (not self.content or self.content == "") and (not self.boxes or #self.boxes == 0) then
        return 0 -- title + buttons only (a plain confirm dialog)
    end

    local window = self.window
    local measured = if self.boxes and #self.boxes > 0 then self:_measureBoxes() else self:_measureText()
    local viewHeight = math.min(measured, maxContentHeight) + contentInset * 2

    local content = window:Create("ScrollingFrame", {
        Name = "Content",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, viewHeight),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        LayoutOrder = 2,

        ScrollBarImageTransparency = 1, -- shown = 0.8, fades in with the rest

        Parent = self.card,
    })
    self:_fade(content, "ScrollBarImageTransparency", 0.8)

    -- the scroll clips, so pad the region to keep box strokes off the edge
    window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, contentInset),
        PaddingRight = UDim.new(0, contentInset),
        PaddingTop = UDim.new(0, contentInset),
        PaddingBottom = UDim.new(0, contentInset),

        Parent = content,
    })

    if self.boxes and #self.boxes > 0 then
        window:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, boxGap),

            Parent = content,
        })
        for index, box in self.boxes do
            self:_buildBox(content, box, index)
        end
    else
        self:_fade(
            window:Create("TextLabel", {
                Text = locale.t(self.content),
                Size = UDim2.new(1, 0, 0, measured),
                BackgroundTransparency = 1,
                TextSize = contentSize,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,

                TextTransparency = 1, -- shown = 0.5

                Parent = content,
            }, { TextColor3 = "ContentColor", FontFace = "Font" }),
            "TextTransparency",
            0.5
        )
    end

    return viewHeight
end

-- One changelog box: a card in the element-panel style (gradient stroke sheen), icon optional,
-- a semibold title and a softer description.
function Popup:_buildBox(parent, box, order)
    local window = self.window
    box = if typeof(box) == "table" then box else { title = tostring(box) }
    local hasIcon = box.icon ~= nil and box.icon ~= 0 and box.icon ~= ""
    local frameH, titleH, descH, columnH = self:_measureBox(box)

    local frame = window:Create("Frame", {
        Name = "Box",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Size = UDim2.new(1, -boxWidthInset, 0, frameH),
        LayoutOrder = order,

        BackgroundTransparency = 1, -- shown = 0

        Parent = parent,
    })
    self:_fade(frame, "BackgroundTransparency", 0)

    local stroke = window:StyleElementPanel(frame)
    self:_fade(stroke, "Transparency", window.theme.ElementStrokeTransparency)

    window:Create("UIPadding", {
        PaddingLeft = UDim.new(0, boxSidePad),
        PaddingRight = UDim.new(0, boxSidePad),
        PaddingTop = UDim.new(0, boxVerticalPad),
        PaddingBottom = UDim.new(0, boxVerticalPad),

        Parent = frame,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, boxIconGap),

        Parent = frame,
    })

    if hasIcon then
        self:_fade(
            window:Create("ImageLabel", {
                Image = box.icon,
                Size = UDim2.fromOffset(boxIconSize, boxIconSize),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = 1,

                ImageTransparency = 1, -- shown = 0

                Parent = frame,
            }, { ImageColor3 = "ContentColor" }),
            "ImageTransparency",
            0
        )
    end

    local textColumn = window:Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, hasIcon and -(boxIconSize + boxIconGap) or 0, 0, columnH),
        LayoutOrder = 2,

        Parent = frame,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),

        Parent = textColumn,
    })

    self:_fade(
        window:Create("TextLabel", {
            Text = locale.t(box.title or box.Title or ""),
            Size = UDim2.new(1, 0, 0, titleH),
            BackgroundTransparency = 1,
            TextSize = boxTitleSize,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            LayoutOrder = 1,

            TextTransparency = 1, -- shown = 0

            Parent = textColumn,
        }, { TextColor3 = "ContentColor", FontFace = "TitleFont" }),
        "TextTransparency",
        0
    )

    local description = box.description or box.Description
    if description and description ~= "" then
        self:_fade(
            window:Create("TextLabel", {
                Text = locale.t(description),
                Size = UDim2.new(1, 0, 0, descH),
                BackgroundTransparency = 1,
                TextSize = boxDescSize,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
                LayoutOrder = 2,

                TextTransparency = 1, -- shown = 0.65

                Parent = textColumn,
            }, { TextColor3 = "ContentColor", FontFace = "Font" }),
            "TextTransparency",
            0.65
        )
    end
end

function Popup:_buildFooter()
    local window = self.window

    local footer = window:Create("Frame", {
        Name = "Footer",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, buttonHeight),
        LayoutOrder = 3,

        Parent = self.card,
    })

    window:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        HorizontalFlex = Enum.UIFlexAlignment.Fill, -- buttons share the row evenly
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, buttonGap),

        Parent = footer,
    })

    for index, option in self.options do
        self:_buildButton(footer, option, index)
    end
end

-- One footer button. Neutral matches the element body; "primary" and "danger" tint it green/red
-- the way the library flags a good or destructive action.
function Popup:_buildButton(parent, option, order)
    local window = self.window
    option = if typeof(option) == "table" then option else { text = tostring(option) }
    local style = option.style or option.Style or "neutral"
    local label = option.text or option.Text or option.name or option.Name or "Okay"
    local callback = option.callback or option.Callback

    -- flat fills so hover just tweens the colour (no overlay). neutral takes a faint white edge
    -- so it recedes; the accents carry their own colour and a bolder edge.
    local restColor, hoverColor, edgeColor, strokeShown
    if style == "primary" then
        restColor, hoverColor, edgeColor, strokeShown =
            window.theme.AccentColor, window.theme.AccentStroke, window.theme.AccentStroke, 0.1
    elseif style == "danger" then
        restColor, hoverColor, edgeColor, strokeShown =
            window.theme.ErrorColor, window.theme.ErrorStrokeColor, window.theme.ErrorStrokeColor, 0
    else
        restColor, hoverColor, edgeColor, strokeShown =
            window.theme.NeutralButton, window.theme.NeutralButtonHover, window.theme.NeutralButtonStroke, 0.85
    end

    local button = window:Create("Frame", {
        Name = "Button",
        BackgroundColor3 = restColor,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 0, buttonHeight),
        LayoutOrder = order,

        BackgroundTransparency = 1, -- shown = 0

        Parent = parent,
    })
    self:_fade(button, "BackgroundTransparency", 0)

    window:Create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = button })
    window:Create("UICorner", { CornerRadius = buttonCorner, Parent = button })

    local stroke = window:Create("UIStroke", {
        Color = edgeColor,
        Transparency = 1, -- shown = strokeShown

        Parent = button,
    })
    self:_fade(stroke, "Transparency", strokeShown)

    self:_fade(
        window:Create("TextLabel", {
            Text = locale.t(label),
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            TextSize = buttonTextSize,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,

            -- adaptive: black or white by the fill's luminance, so every style stays readable
            TextColor3 = functions.contrastText(restColor),
            TextTransparency = 1, -- shown = 0

            Parent = button,
        }, { FontFace = "Font" }),
        "TextTransparency",
        0
    )

    local interact = window:Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        ZIndex = 2,

        Parent = button,
    })

    local hoverInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    table.insert(
        self._connections,
        window:Connect(interact.MouseEnter, function()
            if self._closed then
                return
            end
            variables.tweenService:Create(button, hoverInfo, { BackgroundColor3 = hoverColor }):Play()
        end)
    )
    table.insert(
        self._connections,
        window:Connect(interact.MouseLeave, function()
            variables.tweenService:Create(button, hoverInfo, { BackgroundColor3 = restColor }):Play()
        end)
    )

    table.insert(
        self._connections,
        window:Connect(interact.MouseButton1Click, function()
            if self._closed then
                return
            end
            hapticEngine.click()
            -- press feel: ghost the stroke, then run the callback and close
            variables.tweenService:Create(stroke, hoverInfo, { Transparency = 1 }):Play()
            if callback then
                task.spawn(function()
                    local ok, err = pcall(callback)
                    if not ok then
                        log.warn("Rayfield: popup button '" .. label .. "' callback errored:")
                        log.print(err)
                    end
                end)
            end
            self:Close()
        end)
    )
end

-- Measure the header parts once and stash them, so both the card height and the header's own
-- fixed layout use the same numbers. Everything is sized off these, so nothing re-measures on
-- screen once the font's glyphs land. Returns the header row height.
function Popup:_measureHeader(hasIcon)
    local textWidth = innerWidth - (if hasIcon then headerIconSize + headerIconGap else 0)
    self._titleH = functions.textHeight(self.window.theme.Font, titleSize, locale.resolve(self.title), textWidth)
    self._subH = if self.subtitle and self.subtitle ~= ""
        then functions.textHeight(self.window.theme.Font, subtitleSize, locale.resolve(self.subtitle), textWidth)
        else 0
    self._columnH = self._titleH + (if self._subH > 0 then 3 + self._subH else 0)
    return math.max(self._columnH, if hasIcon then headerIconSize else 0)
end

-- Height a paragraph needs at the content region's width.
function Popup:_measureText()
    return functions.textHeight(self.window.theme.Font, contentSize, self.content, contentWidth)
end

-- Every measurement one box needs: its frame height (content + padding), its title and
-- description text heights, and the text column height. Both the card sizing and the box build
-- read from here, so a box is built at a fixed size rather than auto-sizing (which re-measures).
function Popup:_measureBox(box)
    box = if typeof(box) == "table" then box else { title = tostring(box) }
    local hasIcon = box.icon ~= nil and box.icon ~= 0 and box.icon ~= ""
    local textWidth = contentWidth - boxWidthInset - boxSidePad * 2 - (if hasIcon then boxIconSize + boxIconGap else 0)

    local titleH =
        functions.textHeight(self.window.theme.TitleFont, boxTitleSize, box.title or box.Title or "", textWidth)
    local descH = 0
    local description = box.description or box.Description
    if description and description ~= "" then
        descH = functions.textHeight(self.window.theme.Font, boxDescSize, description, textWidth)
    end

    local columnH = titleH + (if descH > 0 then 3 + descH else 0)
    local frameH = math.max(columnH, if hasIcon then boxIconSize else 0) + boxVerticalPad * 2
    return frameH, titleH, descH, columnH
end

-- Total height every box stacks to, so the content region knows when to start scrolling.
function Popup:_measureBoxes()
    local total = 0
    for index, box in self.boxes do
        total += (self:_measureBox(box))
        if index < #self.boxes then
            total += boxGap
        end
    end
    return total
end

-- Enter: darken the backdrop, drift the card up into place and fade everything in. No UIScale -
-- scaling the card scales its text, which reads as the font size settling after the reveal.
function Popup:_show()
    if not self.screenGui.Parent then
        return
    end

    hapticEngine.notify()

    variables.tweenService:Create(self.card, enterInfo, { Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()

    for _, entry in self._reveal do
        local info = if entry.instance == self.backdrop then backdropInfo else fadeLong
        variables.tweenService:Create(entry.instance, info, { [entry.prop] = entry.to }):Play()
    end
end

-- Exit: fade everything back out while the card drifts down a touch, then tear it all down.
function Popup:Close()
    if self._closed then
        return
    end
    self._closed = true

    for _, connection in self._connections do
        self.window:Disconnect(connection)
    end
    self._connections = {}

    if not self.screenGui.Parent then
        return
    end

    variables.tweenService:Create(self.card, fadeShort, { Position = UDim2.new(0.5, 0, 0.5, 10) }):Play()

    for _, entry in self._reveal do
        variables.tweenService:Create(entry.instance, fadeShort, { [entry.prop] = 1 }):Play()
    end

    task.delay(fadeShort.Time, function()
        self.window:DestroySubtree(self.screenGui)
    end)
end

return Popup
