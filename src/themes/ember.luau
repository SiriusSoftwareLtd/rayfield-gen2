-- Warm charcoal dark theme with an amber accent. Partial: overrides the warm tones + accent,
-- inherits corners, fonts and toggle/field behaviour from default.
return {
    WindowColor = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 18, 16)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(32, 27, 23)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 33, 28)),
    }),
    ShadowColor = Color3.fromRGB(16, 12, 8),

    ElementStroke = Color3.fromRGB(54, 46, 40),
    ElementGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(32, 27, 23)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(38, 32, 27)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(38, 32, 27)),
    }),
    ElementStrokeGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(72, 62, 52)),
        ColorSequenceKeypoint.new(0.9999, Color3.fromRGB(88, 76, 64)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(72, 62, 52)),
    }),
    ElementStrokeHover = Color3.fromRGB(84, 72, 60),

    TabBackground = ColorSequence.new(Color3.fromRGB(56, 47, 40), Color3.fromRGB(36, 30, 26)),
    TabStroke = ColorSequence.new(Color3.fromRGB(92, 78, 66), Color3.fromRGB(56, 47, 40)),

    SliderBackground = Color3.fromRGB(48, 40, 34),
    SliderBackgroundHover = Color3.fromRGB(62, 52, 44),
    SliderProgress = ColorSequence.new(Color3.fromRGB(244, 152, 44), Color3.fromRGB(220, 110, 24)),

    -- Amber accent for the active toggle, slider glow and popup primary button.
    AccentColor = Color3.fromRGB(240, 142, 40),
    AccentStroke = Color3.fromRGB(255, 182, 92),

    ToggleKnobOff = Color3.fromRGB(232, 224, 214), -- warm off-knob on the dark track

    StatBackground = Color3.fromRGB(26, 21, 18),

    DropdownHighlight = Color3.fromRGB(240, 142, 40),

    NeutralButton = Color3.fromRGB(48, 40, 34),
    NeutralButtonHover = Color3.fromRGB(64, 54, 46),
    NeutralButtonStroke = Color3.fromRGB(150, 128, 104),
}
