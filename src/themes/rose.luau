-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Dark theme with a rose accent. Partial: overrides the warm-plum tones + pink accent, inherits
-- corners, fonts and toggle/field behaviour from default.
return {
    WindowColor = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 18, 22)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(36, 26, 31)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(44, 32, 38)),
    }),
    ShadowColor = Color3.fromRGB(18, 10, 14),

    ElementStroke = Color3.fromRGB(58, 44, 50),
    ElementGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 25, 29)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(40, 30, 34)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 30, 34)),
    }),
    ElementStrokeGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(76, 58, 66)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(92, 70, 80)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(76, 58, 66)),
    }),
    ElementStrokeHover = Color3.fromRGB(88, 66, 74),

    TabBackground = ColorSequence.new(Color3.fromRGB(62, 46, 53), Color3.fromRGB(38, 29, 33)),
    TabStroke = ColorSequence.new(Color3.fromRGB(102, 78, 88), Color3.fromRGB(62, 46, 53)),

    SliderBackground = Color3.fromRGB(50, 38, 44),
    SliderBackgroundHover = Color3.fromRGB(64, 50, 56),
    SliderProgress = ColorSequence.new(Color3.fromRGB(244, 88, 140), Color3.fromRGB(220, 60, 116)),

    -- Rose accent for the active toggle, slider glow and popup primary button.
    AccentColor = Color3.fromRGB(240, 82, 138),
    AccentStroke = Color3.fromRGB(255, 134, 178),

    ToggleKnobOff = Color3.fromRGB(236, 220, 226), -- warm off-knob on the dark track

    StatBackground = Color3.fromRGB(28, 20, 24),

    DropdownHighlight = Color3.fromRGB(240, 82, 138),

    NeutralButton = Color3.fromRGB(50, 38, 44),
    NeutralButtonHover = Color3.fromRGB(64, 50, 56),
    NeutralButtonStroke = Color3.fromRGB(170, 122, 140),
}
