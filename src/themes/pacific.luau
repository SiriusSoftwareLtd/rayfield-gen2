local constants = require(script.Parent.Parent.utility.constants)

return {
    CornerRoundness = UDim.new(0, 20),
    WindowColor = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(44, 89, 212)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(38, 148, 117)),
    }),
    ShadowColor = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(44, 89, 212)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(38, 148, 117)),
    }),

    LiveAnimation = true, -- Subtly changes window gradient and shadow offset to make Rayfield feel more natural.

    ElementTransparency = 0.8,
    ElementStroke = Color3.fromRGB(255, 255, 255),
    -- White gradient = no-op tint over the translucent pacific elements
    ElementGradient = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
    ElementStrokeGradient = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
    ElementStrokeTransparency = 0.65,
    DarkToggleOverlay = false,
    ElementStrokeHoverTransparency = 0,
    ElementStrokeHover = Color3.fromRGB(255, 255, 255),
    ElementCornerRadius = UDim.new(0, 12),
    DividerColor = Color3.fromRGB(255, 255, 255),
    TabColor = Color3.fromRGB(255, 255, 255),
    -- Placeholder greys (readable on the gradient window) - refine in the theme pass.
    TabBackground = ColorSequence.new(Color3.fromRGB(50, 50, 50), Color3.fromRGB(35, 35, 35)),
    TabStroke = ColorSequence.new(Color3.fromRGB(95, 95, 95), Color3.fromRGB(50, 50, 50)),
    -- Placeholder - refine in the theme pass.
    SliderBackground = Color3.fromRGB(47, 47, 47),
    SliderProgress = ColorSequence.new(Color3.fromRGB(0, 170, 127), Color3.fromRGB(0, 134, 98)),
    SliderStroke = Color3.fromRGB(255, 255, 255),
    ActionColor = Color3.fromRGB(255, 255, 255),
    TitlingColor = Color3.fromRGB(255, 255, 255),
    TitleFont = Font.new(constants.fontAsset, Enum.FontWeight.SemiBold),
    Font = Font.new(constants.fontAsset, Enum.FontWeight.Medium),
    ContentColor = Color3.fromRGB(255, 255, 255),
    ElementTextHoverColor = Color3.fromRGB(255, 255, 255),

    DropdownHighlight = Color3.fromRGB(8, 132, 248),

    ErrorColor = Color3.fromRGB(110, 0, 0),
    ErrorStrokeColor = Color3.fromRGB(140, 0, 0),
}
