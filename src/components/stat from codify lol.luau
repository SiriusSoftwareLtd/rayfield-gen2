create "Frame" {
  Name = "Stat",
  BackgroundColor3 = Color3.fromRGB(25, 25, 25),
  BorderColor3 = Color3.fromRGB(0, 0, 0),
  BorderSizePixel = 0,
  Position = UDim2.fromScale(0.022, 0.153),
  Size = UDim2.new(1, -20, 0, 90),
  ZIndex = 5,

  create "TextLabel" {
    Name = "Value",
    AnchorPoint = Vector2.new(0, 1),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 1,
    BorderColor3 = Color3.fromRGB(0, 0, 0),
    BorderSizePixel = 0,
    FontFace = Font.new(
      "rbxassetid://12187365364",
      Enum.FontWeight.Medium,
      Enum.FontStyle.Normal
    ),
    Position = UDim2.new(0, 20, 1, -15),
    Size = UDim2.fromOffset(200, 20),
    Text = "Value",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 20,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 10,
  },

  create "UICorner" {
    Name = "UICorner",
    CornerRadius = UDim.new(0, 15),
  },

  create "TextLabel" {
    Name = "Change",
    AnchorPoint = Vector2.new(1, 1),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 1,
    BorderColor3 = Color3.fromRGB(0, 0, 0),
    BorderSizePixel = 0,
    FontFace = Font.new(
      "rbxassetid://12187365364",
      Enum.FontWeight.SemiBold,
      Enum.FontStyle.Normal
    ),
    Position = UDim2.new(1, -20, 1, -15),
    RichText = true,
    Size = UDim2.fromOffset(200, 15),
    Text = "+/-Change%",
    TextColor3 = Color3.fromRGB(29, 220, 115),
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 10,
  },

  create "Frame" {
    Name = "GradientContainer",
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 0.7,
    BorderColor3 = Color3.fromRGB(0, 0, 0),
    BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 5,

    create "UIGradient" {
      Name = "UIGradient",
      Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 170, 127)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 170, 127)),
      }),
      Offset = Vector2.new(0, 0.5),
      Rotation = 80,
      Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.85),
        NumberSequenceKeypoint.new(1, 0),
      }),
    },

    create "UICorner" {
      Name = "UICorner",
      CornerRadius = UDim.new(0, 15),
    },
  },

  create "UIStroke" {
    Name = "UIStroke",
    Color = Color3.fromRGB(255, 255, 255),

    create "UIGradient" {
      Name = "UIGradient",
      Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 170, 127)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 170, 127)),
      }),
      Offset = Vector2.new(0, 0.5),
      Rotation = 80,
      Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.85),
        NumberSequenceKeypoint.new(1, 0),
      }),
    },
  },

  create "Frame" {
    Name = "Container",
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 1,
    BorderColor3 = Color3.fromRGB(27, 42, 53),
    BorderSizePixel = 0,
    LayoutOrder = -1,
    Position = UDim2.fromOffset(20, 15),
    Size = UDim2.new(1, -40, 0, 32),
    ZIndex = 5,

    create "UIListLayout" {
      Name = "UIListLayout",
      FillDirection = Enum.FillDirection.Horizontal,
      Padding = UDim.new(0, 6),
      SortOrder = Enum.SortOrder.LayoutOrder,
      VerticalAlignment = Enum.VerticalAlignment.Center,
    },

    create "ImageLabel" {
      Name = "Image",
      BackgroundColor3 = Color3.fromRGB(255, 255, 255),
      BackgroundTransparency = 1,
      BorderColor3 = Color3.fromRGB(0, 0, 0),
      BorderSizePixel = 0,
      Image = "rbxassetid://91809890071567",
      Position = UDim2.fromOffset(20, 20),
      Size = UDim2.fromOffset(32, 32),
      ZIndex = 10,
    },

    create "TextLabel" {
      Name = "Title",
      BackgroundColor3 = Color3.fromRGB(255, 255, 255),
      BackgroundTransparency = 1,
      BorderColor3 = Color3.fromRGB(0, 0, 0),
      BorderSizePixel = 0,
      FontFace = Font.new(
        "rbxassetid://12187365364",
        Enum.FontWeight.SemiBold,
        Enum.FontStyle.Normal
      ),
      Position = UDim2.fromOffset(60, 20),
      Size = UDim2.fromOffset(300, 19),
      Text = "Stat",
      TextColor3 = Color3.fromRGB(255, 255, 255),
      TextSize = 19,
      TextXAlignment = Enum.TextXAlignment.Left,
      ZIndex = 10,
    },
  },

  create "Frame" {
    Name = "Glow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 1,
    BorderColor3 = Color3.fromRGB(27, 42, 53),
    BorderSizePixel = 0,
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, 35, 1, 35),
    ZIndex = 4,

    create "ImageLabel" {
      Name = "Image",
      AnchorPoint = Vector2.new(0.5, 0.5),
      BackgroundColor3 = Color3.fromRGB(255, 255, 255),
      BackgroundTransparency = 1,
      BorderColor3 = Color3.fromRGB(27, 42, 53),
      BorderSizePixel = 0,
      Image = "rbxassetid://5587865193",
      ImageTransparency = 0.2,
      Position = UDim2.fromScale(0.498, 0.5),
      Size = UDim2.fromScale(1.15, 1),
      ZIndex = 4,

      create "UIGradient" {
        Name = "UIGradient",
        Color = ColorSequence.new({
          ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 170, 127)),
          ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 170, 127)),
        }),
        Offset = Vector2.new(0, 0.5),
        Rotation = 80,
        Transparency = NumberSequence.new({
          NumberSequenceKeypoint.new(0, 0.85),
          NumberSequenceKeypoint.new(1, 0),
        }),
      },
    },
  },
}