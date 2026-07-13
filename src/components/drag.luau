local Drag = {}
Drag.__index = Drag
Drag.__type = "Drag"

-- Utility
local utility = script.Parent.Parent.utility

-- Variables
local variables = require(utility.variables)
local constants = require(utility.constants)

function Drag.new(window, properties)
    properties = if typeof(properties) == "table" then properties else {}

    local self = setmetatable({
        window = assert(window, "Missing argument #1 (Window expected)"),
    }, Drag)

    -- Drag Point
    self.drag = self.window:Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(150, 20),
        AnchorPoint = Vector2.new(0.5, 0.5),
        -- hangs under the window's bottom edge; derived from the real size so it's right on the
        -- first open too (Show/minimise recompute the same way against self.size)
        Position = UDim2.new(0.5, 0, 0.5, self.window.size.Y.Offset / 2 + 15),
        ZIndex = constants.zIndex.drag,

        -- Animation
        Visible = false, -- In = true

        Parent = self.window.screenGui,
    })

    self.dragCosmetic = self.window:Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.3),
        ZIndex = constants.zIndex.drag,

        -- Animation
        BackgroundTransparency = 1, -- In = 0.7
        Size = UDim2.fromOffset(0, 4), -- In = 100, 4

        Parent = self.drag,
    })

    self.window:Create("UICorner", {
        CornerRadius = UDim.new(0, 20),

        Parent = self.dragCosmetic,
    })

    -- White glow behind the drag bar
    self.window:CreateGlow(self.dragCosmetic, Color3.fromRGB(255, 255, 255), 10, 0.5)

    self.dragInteract = self.window:Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        TextTransparency = 1,
        ZIndex = constants.zIndex.drag,

        Parent = self.drag,
    })

    local dragging = false
    local relative = nil

    -- main.Position offsets live in a space shifted from AbsolutePosition by the gui inset,
    -- even though the ScreenGui ignores inset. so the drag target has to add the inset back
    -- or the window lands ~inset px too high (measured in play: without it, jumps up ~58px).
    local offset = Vector2.zero
    local screenGui = self.window.screenGui

    if screenGui and screenGui.IgnoreGuiInset then
        offset = variables.guiService:GetGuiInset()
    end

    local function getPosition()
        local mouseLocation = variables.userInputService and variables.userInputService:GetMouseLocation()
            or Vector2.new(0, 0)
        local validRelative = relative or Vector2.new(0, 0)
        local validOffset = offset or Vector2.new(0, 0)

        return mouseLocation + validRelative + validOffset
    end

    -- main sits at the cursor target, the drag bar hangs under its bottom edge
    local function getTargets()
        local position = getPosition()
        local x, y = position.X, position.Y

        -- keepOnScreen: clamp the centre so it cant be pulled off screen
        if self.window.settings and self.window.settings.keepOnScreen then
            local size = self.window.main.AbsoluteSize
            local screen = self.window.screenGui.AbsoluteSize
            local margin = 8
            local halfX, halfY = size.X / 2, size.Y / 2
            -- math.max in case the window is bigger than the screen
            x = math.clamp(x, halfX + margin, math.max(halfX + margin, screen.X - halfX - margin))
            y = math.clamp(y, halfY + margin, math.max(halfY + margin, screen.Y - halfY - margin))
        end

        local mainTarget = UDim2.fromOffset(x, y)
        local dragTarget = UDim2.fromOffset(x, y + (self.window.main.Size.Y.Offset / 2 + 15))
        return mainTarget, dragTarget
    end

    self.window:Connect(self.drag.MouseEnter, function()
        if not dragging and not variables.rayfieldHidden then
            variables.tweenService
                :Create(
                    self.dragCosmetic,
                    TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                    { BackgroundTransparency = 0.5, Size = UDim2.new(0, 120, 0, 4) }
                )
                :Play()
        end
    end)

    self.window:Connect(self.drag.MouseLeave, function()
        if not dragging and not variables.rayfieldHidden then
            variables.tweenService
                :Create(
                    self.dragCosmetic,
                    TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                    { BackgroundTransparency = 0.7, Size = UDim2.new(0, 100, 0, 4) }
                )
                :Play()
        end
    end)

    self.window:Connect(self.dragInteract.InputBegan, function(input, processed)
        if processed then
            return
        end

        local inputType = input.UserInputType.Name
        if inputType == "MouseButton1" or inputType == "Touch" then
            dragging = true

            -- refetch in case the inset changed (e.g. topbar toggled) since construction
            if screenGui and screenGui.IgnoreGuiInset then
                offset = variables.guiService:GetGuiInset()
            end

            relative = self.window.main.AbsolutePosition
                + self.window.main.AbsoluteSize * self.window.main.AnchorPoint
                - variables.userInputService:GetMouseLocation()
            if not variables.rayfieldHidden then
                variables.tweenService
                    :Create(
                        self.dragCosmetic,
                        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                        { Size = UDim2.new(0, 110, 0, 4), BackgroundTransparency = 0 }
                    )
                    :Play()
            end
        end
    end)

    self.window:Connect(variables.userInputService.InputEnded, function(input)
        if not dragging then
            return
        end

        local inputType = input.UserInputType.Name
        if inputType == "MouseButton1" or inputType == "Touch" then
            dragging = false

            if not variables.rayfieldHidden then
                variables.tweenService
                    :Create(
                        self.dragCosmetic,
                        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                        { Size = UDim2.new(0, 100, 0, 4), BackgroundTransparency = 0.7 }
                    )
                    :Play()

                -- main lags while dragging, so settle both into line on release
                local settle = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                local mainTarget, dragTarget = getTargets()
                variables.tweenService:Create(self.window.main, settle, { Position = mainTarget }):Play()
                variables.tweenService:Create(self.drag, settle, { Position = dragTarget }):Play()
            end
        end
    end)

    -- exponential smoothing per frame instead of a new tween each frame. constant is the
    -- fraction of the gap left after 1s, so smaller = snappier. main lags, the bar tracks tight
    local mainRemaining = 1e-7
    local barRemaining = 1e-60

    self.window:Connect(variables.runService.RenderStepped, function(dt)
        if dragging and not variables.rayfieldHidden then
            local mainTarget, dragTarget = getTargets()

            self.window.main.Position = self.window.main.Position:Lerp(mainTarget, 1 - mainRemaining ^ dt)
            self.drag.Position = self.drag.Position:Lerp(dragTarget, 1 - barRemaining ^ dt)
        end
    end)

    return self
end

return Drag
