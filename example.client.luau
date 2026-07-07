local rep = game:GetService("ReplicatedStorage")
local Rayfield = require(rep.Rayfield)

task.wait(2)

local window = Rayfield:CreateWindow({
    name = 'Example',
    subtitle = 'Rayfield Gen2',
    theme = 'default',

    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = 'ExampleConfigFile',
    },
})

window:CreateTag({
    text = 'us-en',
    icon = 75184136063371,
    color = Color3.fromRGB(255, 175, 15),
})

task.delay(4, function()
    window:Notify({
        title = 'Welcome back',
        content = 'Rayfield Gen2 loaded. Hover to pause, click to dismiss.',
        icon = 93364949241311,
    })

    task.wait(1.2)
    window:Notify({
        title = 'Auto-saved',
        content = 'Your configuration was saved.',
        icon = 125823673784681,
        duration = 5,
    })

    task.wait(1.2)
    window:Notify({
        title = 'No icon here',
        content = 'Notifications work fine without an icon too, and the text column stretches to fill the width.',
    })

    task.wait(1.2)
    window:Notify({
        title = 'Longer one',
        content = 'This is a longer notification to show wrapping and how the frame auto-sizes to fit multiple lines while the stack reflows underneath it.',
        icon = 85925158736685,
    })
end)

-- General
local generalTab = window:CreateTab({
    name = 'Home',
    icon = 93364949241311,
})

generalTab:CreateSection({ name = 'Gameplay' })

generalTab:CreateToggle({
    name = 'Auto Sprint',
    icon = 84750991656135,
    flag = 'AutoSprint',
    value = true,
    callback = function(value)
        print('Auto Sprint:', value)
    end
})

generalTab:CreateToggle({
    name = 'Reduced Motion',
    description = 'Disables screen shake and camera effects for a smoother experience.',
    flag = 'ReducedMotion',
    callback = function(value)
        print('Reduced Motion:', value)
    end
})

generalTab:CreateSlider({
    name = 'Field of View',
    range = {70, 120},
    increment = 1,
    value = 90,
    suffix = '°',
    callback = function(value)
        print('FOV:', value)
    end
})

generalTab:CreateSection({ name = 'Interface' })

generalTab:CreateToggle({
    name = 'Show FPS Counter',
    flag = 'ShowFPS',
    callback = function(value)
        print('Show FPS:', value)
    end
})

generalTab:CreateToggle({
    name = 'Compact HUD',
    flag = 'CompactHUD',
    callback = function(value)
        print('Compact HUD:', value)
    end
})

generalTab:CreateDropdown({
    name = 'Theme',
    flag = 'InterfaceTheme',
    options = {'Default', 'Pacific', 'Midnight'},
    value = 'Default',
    callback = function(value)
        print('Theme:', value)
    end
})

generalTab:CreateDropdown({
    name = 'Enabled Modules',
    description = 'Pick any combination of modules to load on startup.',
    flag = 'EnabledModules',
    multiSelect = true,
    options = {'Aimbot', 'ESP', 'Speed', 'Fly'},
    value = {'ESP'},
    placeholder = 'None selected',
    callback = function(value)
        print('Enabled Modules:', table.concat(value, ', '))
    end
})

generalTab:CreateButton({
    name = 'Reset Interface Layout',
    icon = 125823673784681,
    callback = function()
        print('Interface layout reset')
    end
})

generalTab:CreateButton({
    name = 'Test Notification',
    icon = 93364949241311,
    callback = function()
        window:Notify({
            title = 'Heads up',
            content = 'This is a notification. Hover to pause it, or click to dismiss early.',
            icon = 93364949241311,
        })
    end
})

generalTab:CreateSection({ name = 'Group' })

local row = generalTab:CreateGroup()

row:CreateButton({
    name = 'Save',
    icon = 125823673784681,
    callback = function() print('Row button: Save') end,
})

local rowToggle = row:CreateToggle({
    name = 'ESP',
    flag = 'RowESP',
    value = true,
    callback = function(v) print('Row toggle ESP:', v) end,
})

local rowStat = row:CreateStat({
    name = 'Kills',
    icon = 85925158736685,
    value = 128,
    display = 'value',
})


-- stats
local statsTab = window:CreateTab({
    name = 'Numbers',
    icon = 85925158736685,
})

statsTab:CreateSection({ name = 'Session Overview' })

local revenue = statsTab:CreateStat({
    name = 'Revenue',
    icon = 117942554423479,
    prefix = '$',
    value = 12400,
    changeMode = 'percentage',
    changeBaseline = 'previous',
})

-- Compact stat outside a row (config opt-in). Shows just the % change.
local compactStat = statsTab:CreateStat({
    name = 'Win Rate',
    icon = 117942554423479,
    compact = true,
    prefix = '#',
    display = 'change', -- change | value
    value = 50,
    changeMode = 'percentage',
})

statsTab:CreateSection({ name = 'Quick Actions' })

statsTab:CreateButton({
    name = 'Simulate Sale',
    callback = function()
        revenue:Set(revenue.value + math.random(500, 3000))
        compactStat:Set(compactStat.value + math.random(1, 9))
        rowStat:Set(rowStat.value + math.random(1, 20)) -- bump the row's mini stat
        rowToggle:Set(not rowToggle.value)              -- flip the row's switch
    end
})

statsTab:CreateButton({
    name = 'Reset Tracking',
    description = 'Clears the change indicator and starts fresh from the current value.',
    callback = function()
        revenue:ResetBaseline()
        compactStat:ResetBaseline()
    end
})


-- Layouts: rows, columns, grids and wrapping
local layoutTab = window:CreateTab({
    name = 'Layouts',
    icon = 84750991656135,
})

-- a plain row
layoutTab:CreateSection({ name = 'Three across' })

local threeStack = layoutTab:CreateGroup()
threeStack:CreateButton({ name = 'One', callback = function() print('one') end })
threeStack:CreateButton({ name = 'Two', callback = function() print('two') end })
threeStack:CreateButton({ name = 'Three', callback = function() print('three') end })

-- five fit fine: they shrink to share, and wrap once there's no room
layoutTab:CreateSection({ name = 'Five across' })

local fiveStack = layoutTab:CreateGroup()
for _, label in { 'A', 'B', 'C', 'D', 'E' } do
    fiveStack:CreateButton({ name = label, callback = function() end })
end

-- a grid: a row of columns, each column holding full-width elements
layoutTab:CreateSection({ name = 'Two columns - Group of columns' })

local grid = layoutTab:CreateGroup()

local leftCol = grid:CreateGroup({ direction = 'column' })
leftCol:CreateToggle({ name = 'Aimbot', flag = 'GridAimbot' })
leftCol:CreateToggle({ name = 'Triggerbot', flag = 'GridTrigger' })
leftCol:CreateSlider({ name = 'Smoothing', range = { 0, 100 }, value = 40, suffix = '%' })

local rightCol = grid:CreateGroup({ direction = 'column' })
rightCol:CreateToggle({ name = 'ESP Boxes', flag = 'GridBoxes', value = true })
rightCol:CreateToggle({ name = 'ESP Names', flag = 'GridNames' })
rightCol:CreateDropdown({
    name = 'ESP Color',
    flag = 'GridEspColor',
    options = { 'Red', 'Green', 'Blue' },
    value = 'Green',
})

-- 4. smart wrapping: each element reports the width it needs (icon + text + control +
-- padding), so the row packs as many as fit and wraps the rest instead of shrinking to mush
layoutTab:CreateSection({ name = 'Wrapping - 8 buttons' })

local wrapButtons = layoutTab:CreateGroup()
for _, label in { 'Save', 'Load', 'Reset', 'Export', 'Import', 'Copy', 'Paste', 'Clear' } do
    wrapButtons:CreateButton({ name = label, callback = function() end })
end

layoutTab:CreateSection({ name = 'Wrapping - 6 toggles (wider, wrap sooner)' })

local wrapToggles = layoutTab:CreateGroup()
for _, label in { 'Aimbot', 'ESP', 'Fly', 'Speed', 'Noclip', 'Godmode' } do
    wrapToggles:CreateToggle({ name = label, flag = 'Wrap' .. label })
end

layoutTab:CreateSection({ name = 'Wrapping - mixed label lengths' })

local wrapMixed = layoutTab:CreateGroup()
wrapMixed:CreateButton({ name = 'OK', callback = function() end })
wrapMixed:CreateButton({ name = 'Regenerate All Chunks', callback = function() end })
wrapMixed:CreateButton({ name = 'Go', callback = function() end })
wrapMixed:CreateButton({ name = 'Save Current Layout As Preset', callback = function() end })
wrapMixed:CreateButton({ name = 'X', callback = function() end })

layoutTab:CreateSection({ name = 'Wrapping - icons count toward the width' })

local wrapIcons = layoutTab:CreateGroup()
for _, label in { 'Save', 'Load', 'Reset', 'Export', 'Import', 'Delete' } do
    wrapIcons:CreateButton({ name = label, icon = 125823673784681, callback = function() end })
end

layoutTab:CreateSection({ name = 'Wrapping - stats (title + number both counted)' })

local wrapStats = layoutTab:CreateGroup()
wrapStats:CreateStat({ name = 'Kills', value = 128, display = 'value' })
wrapStats:CreateStat({ name = 'Deaths', value = 7, display = 'value' })
wrapStats:CreateStat({ name = 'KDR', value = 18, suffix = 'x', display = 'value' })
wrapStats:CreateStat({ name = 'Score', value = 45200, display = 'value' })
wrapStats:CreateStat({ name = 'Rank', value = 3, prefix = '#', display = 'value' })

layoutTab:CreateSection({ name = 'Wrapping - sliders (floored so the track stays usable)' })

local wrapSliders = layoutTab:CreateGroup()
wrapSliders:CreateSlider({ name = 'FOV', range = { 70, 120 }, value = 90, suffix = 'deg' })
wrapSliders:CreateSlider({ name = 'Sens', range = { 0, 10 }, increment = 0.1, value = 3.5 })
wrapSliders:CreateSlider({ name = 'Volume', range = { 0, 100 }, value = 80, suffix = '%' })

layoutTab:CreateSection({ name = 'Wrapping - 12 buttons (many rows)' })

local wrapMany = layoutTab:CreateGroup()
for i = 1, 12 do
    wrapMany:CreateButton({ name = 'Item ' .. i, callback = function() end })
end

layoutTab:CreateSection({ name = 'Minimal sliders (track only, dense row)' })

local bars = layoutTab:CreateGroup()
bars:CreateSlider({ minimal = true, range = { 0, 100 }, value = 30, forgetState = true })
bars:CreateSlider({ minimal = true, range = { 0, 100 }, value = 60, forgetState = true })
bars:CreateSlider({ minimal = true, range = { 0, 100 }, value = 85, forgetState = true })
bars:CreateSlider({ minimal = true, range = { 0, 100 }, value = 45, forgetState = true })

layoutTab:CreateSlider({ name = 'Normal slider for contrast', range = { 0, 100 }, value = 50 })

