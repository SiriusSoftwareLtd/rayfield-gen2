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

generalTab:CreateSection({ name = 'Row' })

local row = generalTab:CreateRow()

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

-- Compact stat outside a row (config opt-in) — shows just the % change.
local compactStat = statsTab:CreateStat({
    name = 'Win Rate',
    icon = 117942554423479,
    compact = true,
    display = 'change',
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

