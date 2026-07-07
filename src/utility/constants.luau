-- Shared visual constants. Theme-varying colours/fonts live in themes/; these dont.

local constants = {}

-- brand font asset (themes reference this too)
constants.fontAsset = "rbxassetid://12187365364"

-- Accent used by the toggle switch + slider glow when active.
constants.accent = {
    on = Color3.fromRGB(23, 153, 110),
    onStroke = Color3.fromRGB(32, 201, 144),
}

-- Stat card accents per direction (fill drives the card + glow, stroke is the brighter edge).
constants.statAccents = {
    positive = {
        fill = ColorSequence.new(Color3.fromRGB(0, 170, 127), Color3.fromRGB(0, 134, 98)),
        stroke = ColorSequence.new(Color3.fromRGB(0, 213, 156), Color3.fromRGB(0, 189, 135)),
    },
    negative = {
        fill = ColorSequence.new(Color3.fromRGB(172, 47, 47), Color3.fromRGB(135, 37, 37)),
        stroke = ColorSequence.new(Color3.fromRGB(255, 75, 75), Color3.fromRGB(244, 67, 67)),
    },
    -- Neutral matches RF2's default green stat exactly
    neutral = {
        fill = ColorSequence.new(Color3.fromRGB(0, 170, 127), Color3.fromRGB(0, 134, 98)),
        stroke = ColorSequence.new(Color3.fromRGB(0, 213, 156), Color3.fromRGB(0, 189, 135)),
    },
}

-- Named stacking layers for window furniture (assumes Global ZIndexBehavior)
constants.zIndex = {
    bottomFade = 100,
    drag = 1000,
    restoreBase = 100000,
    restoreContent = 100001,
    restoreInteract = 100002,
}

-- DisplayOrder for the top-level ScreenGuis (the window vs the loading banner).
constants.displayOrder = {
    window = 99999,
    banner = 100000,
}

return constants
