-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Deep violet dark theme with a purple accent. Partial: overrides the violet tones + accent,
-- inherits corners, fonts and toggle/field behaviour from default.
return {
    WindowColor = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 16, 32)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(30, 22, 46)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(38, 28, 56)),
    }),
    ShadowColor = Color3.fromRGB(12, 6, 22),

    ElementStroke = Color3.fromRGB(54, 42, 74),
    ElementGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(32, 24, 48)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(36, 28, 54)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(36, 28, 54)),
    }),
    ElementStrokeGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(72, 58, 104)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(88, 72, 124)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(72, 58, 104)),
    }),
    ElementStrokeHover = Color3.fromRGB(84, 68, 118),

    TabBackground = ColorSequence.new(Color3.fromRGB(54, 42, 80), Color3.fromRGB(34, 26, 52)),
    TabStroke = ColorSequence.new(Color3.fromRGB(88, 70, 128), Color3.fromRGB(54, 42, 80)),

    SliderBackground = Color3.fromRGB(46, 36, 68),
    SliderBackgroundHover = Color3.fromRGB(60, 48, 90),
    SliderProgress = ColorSequence.new(Color3.fromRGB(170, 112, 248), Color3.fromRGB(138, 80, 224)),

    -- Violet accent for the active toggle, slider glow and popup primary button.
    AccentColor = Color3.fromRGB(168, 110, 246),
    AccentStroke = Color3.fromRGB(200, 154, 255),

    ToggleKnobOff = Color3.fromRGB(224, 214, 236), -- cool off-knob on the dark track

    StatBackground = Color3.fromRGB(24, 18, 38),

    DropdownHighlight = Color3.fromRGB(168, 110, 246),

    NeutralButton = Color3.fromRGB(46, 36, 68),
    NeutralButtonHover = Color3.fromRGB(60, 48, 90),
    NeutralButtonStroke = Color3.fromRGB(140, 116, 190),
}
