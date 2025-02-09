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

    LiveAnimation = false, -- Subtly changes window gradient and shadow offset to make Rayfield feel more natural.

    ElementColor = Color3.fromRGB(255, 255, 255),
    ElementTransparency = 0.8,
    ElementStroke = Color3.fromRGB(255, 255, 255),
    ElementStrokeTransparency = 0.65,
    ElementHoverTransparency = 0.3,
    ElementStrokeHoverTransparency = 0,
    ElementHoverColor = Color3.fromRGB(255, 255, 255),
    ElementStrokeHoverColor = Color3.fromRGB(255, 255, 255),
    ElementCornerRadius = UDim.new(0, 12),
    ElementTextHoverColor = Color3.fromRGB(0, 0, 0),
    DividerColor = Color3.fromRGB(255, 255, 255),
    TabColor = Color3.fromRGB(255, 255, 255),
    ActionColor = Color3.fromRGB(255, 255, 255),
    TitlingColor = Color3.fromRGB(255, 255, 255),
    TitleFont = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold),
    Font = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium),
    ContentColor = Color3.fromRGB(255, 255, 255),

    ErrorColor = Color3.fromRGB(110, 0, 0),
    ErrorStrokeColor = Color3.fromRGB(140, 0, 0)
}