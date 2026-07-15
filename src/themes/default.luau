--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local variables = require(script.Parent.Parent.utility.variables)

return {
    CornerRoundness = UDim.new(0, 20),
    WindowColor = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 10, 10)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(25, 25, 25)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 35, 35)),
    }),
    ShadowColor = Color3.fromRGB(20, 20, 20),

    ElementStroke = Color3.fromRGB(35, 35, 35),
    -- Per-element fill gradient (applied over a white base)
    ElementGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 30)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(35, 35, 35)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 35, 35)),
    }),
    -- Subtle sheen tint for gradient strokes (dropdown cards). Kept lighter than the fill so
    -- the edge still reads low in the window, where the bg gradient is itself ~35.
    ElementStrokeGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(48, 48, 48)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(58, 58, 58)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(48, 48, 48)),
    }),
    TabColor = Color3.fromRGB(255, 255, 255),
    TabBackground = ColorSequence.new(Color3.fromRGB(50, 50, 50), Color3.fromRGB(35, 35, 35)),
    TabStroke = ColorSequence.new(Color3.fromRGB(95, 95, 95), Color3.fromRGB(50, 50, 50)),
    SliderBackground = Color3.fromRGB(47, 47, 47),
    SliderBackgroundHover = Color3.fromRGB(60, 60, 60),
    SliderProgress = ColorSequence.new(Color3.fromRGB(0, 170, 127), Color3.fromRGB(0, 134, 98)),
    SliderStroke = Color3.fromRGB(255, 255, 255),
    ActionColor = Color3.fromRGB(255, 255, 255),
    TitleFont = variables.brandFont(Enum.FontWeight.SemiBold),
    Font = variables.brandFont(Enum.FontWeight.Medium),
    ContentColor = Color3.fromRGB(255, 255, 255),

    LiveAnimation = false, -- Subtly changes window gradient and shadow offset to make Rayfield feel more natural.

    DarkToggleOverlay = true,
    ElementTransparency = 0,
    ElementStrokeTransparency = 0,
    ElementStrokeHoverTransparency = 0,
    ElementStrokeHover = Color3.fromRGB(50, 50, 50),
    ElementCornerRadius = UDim.new(0, 12),
    ElementTextHoverColor = Color3.fromRGB(255, 255, 255),
    TitlingColor = Color3.fromRGB(255, 255, 255),

    DropdownHighlight = Color3.fromRGB(255, 255, 255),

    -- Accent for the active toggle, slider glow and popup primary button.
    AccentColor = Color3.fromRGB(23, 153, 110),
    AccentStroke = Color3.fromRGB(32, 201, 144),
    AccentGlow = 0.4, -- shown transparency of the toggle's accent glow

    StatBackground = Color3.fromRGB(25, 25, 25),
    SliderHandle = Color3.fromRGB(255, 255, 255),
    PillCornerRadius = UDim.new(1, 0), -- tab pills + the collapsed icon

    -- Toggle switch: track colour + transparency, and the off-knob's colour + transparency.
    ToggleTrack = Color3.fromRGB(0, 0, 0),
    ToggleTrackTransparency = 0.9,
    ToggleKnobOff = Color3.fromRGB(255, 255, 255),
    ToggleKnobOffTransparency = 0.8,

    -- Inset fields (input, keybind box): fill, its transparency, and the soft glow behind them.
    FieldBackground = Color3.fromRGB(255, 255, 255),
    FieldTransparency = 0.9,
    FieldGlow = Color3.fromRGB(255, 255, 255),

    PlaceholderColor = Color3.fromRGB(178, 178, 178), -- input/search hint text
    SurfaceStroke = Color3.fromRGB(255, 255, 255), -- faint rim on window/field/toast/popup surfaces

    -- Popup neutral (secondary) button: rest, hover and edge.
    NeutralButton = Color3.fromRGB(38, 38, 38),
    NeutralButtonHover = Color3.fromRGB(54, 54, 54),
    NeutralButtonStroke = Color3.fromRGB(255, 255, 255),

    ErrorColor = Color3.fromRGB(185, 50, 50),
    ErrorStrokeColor = Color3.fromRGB(240, 75, 75),
}
