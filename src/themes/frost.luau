--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local variables = require(script.Parent.Parent.utility.variables)

-- Light theme: cool white surfaces, dark text and cyan accents.
return {
    WindowColor = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(246, 249, 251)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(236, 241, 245)),
    }),
    -- Soft cool shadow so the window lifts off a light background without a hard edge.
    ShadowColor = Color3.fromRGB(116, 124, 132),

    LiveAnimation = false,

    -- Opaque white elements read against the near-white window through a thin border, not a tint.
    ElementTransparency = 0,
    ElementStroke = Color3.fromRGB(218, 224, 228),
    ElementGradient = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
    ElementStrokeGradient = ColorSequence.new(Color3.fromRGB(224, 230, 234), Color3.fromRGB(232, 238, 242)),
    ElementStrokeTransparency = 0.1,
    ElementStrokeHoverTransparency = 0,
    ElementStrokeHover = Color3.fromRGB(0, 176, 208), -- cyan edge on hover
    DarkToggleOverlay = false, -- no dark veil; the track colour carries the switch instead

    -- Dark label so it reads unselected on white and stays legible on the cyan selected pill.
    TabColor = Color3.fromRGB(38, 42, 46),
    TabBackground = ColorSequence.new(Color3.fromRGB(0, 176, 208), Color3.fromRGB(0, 150, 184)),
    TabStroke = ColorSequence.new(Color3.fromRGB(80, 206, 230), Color3.fromRGB(0, 160, 196)),

    SliderBackground = Color3.fromRGB(224, 230, 234),
    SliderBackgroundHover = Color3.fromRGB(212, 220, 224),
    SliderProgress = ColorSequence.new(Color3.fromRGB(0, 182, 214), Color3.fromRGB(0, 146, 182)),
    SliderStroke = Color3.fromRGB(200, 206, 210),

    -- Cyan accent for the toggle, slider glow and popup primary button.
    AccentColor = Color3.fromRGB(0, 176, 208),
    AccentStroke = Color3.fromRGB(96, 210, 232),
    AccentGlow = 0.85, -- subtle accent bloom on the toggle/slider

    StatBackground = Color3.fromRGB(255, 255, 255),
    SliderHandle = Color3.fromRGB(60, 66, 72), -- dark grip instead of a white blob

    -- Opaque grey track so the switch reads on white without the dark overlay; white off-knob.
    ToggleTrack = Color3.fromRGB(198, 204, 210),
    ToggleTrackTransparency = 0,
    ToggleKnobOffTransparency = 0.05,

    -- Visible grey inset fields with a soft grey shadow instead of an invisible white one.
    FieldBackground = Color3.fromRGB(224, 230, 234),
    FieldTransparency = 0,
    FieldGlow = Color3.fromRGB(148, 154, 160),

    PlaceholderColor = Color3.fromRGB(138, 144, 150),
    SurfaceStroke = Color3.fromRGB(204, 210, 214),

    -- Light secondary button (dark text via adaptive contrast) instead of a dark blob on white.
    NeutralButton = Color3.fromRGB(224, 230, 234),
    NeutralButtonHover = Color3.fromRGB(212, 220, 224),
    NeutralButtonStroke = Color3.fromRGB(242, 246, 248), -- lighter than the fill

    ActionColor = Color3.fromRGB(68, 74, 80), -- top-bar icons
    TitlingColor = Color3.fromRGB(26, 30, 34),
    TitleFont = variables.brandFont(Enum.FontWeight.SemiBold),
    Font = variables.brandFont(Enum.FontWeight.Medium),
    ContentColor = Color3.fromRGB(42, 46, 52),
    ElementTextHoverColor = Color3.fromRGB(18, 22, 26),

    DropdownHighlight = Color3.fromRGB(0, 176, 208),

    ErrorColor = Color3.fromRGB(200, 60, 55),
    ErrorStrokeColor = Color3.fromRGB(240, 80, 70),
}
