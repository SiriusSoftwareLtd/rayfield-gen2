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
        fileName = 'ExampleConfig',
    },
})


-- General
local generalTab = window:CreateTab({
    name = 'General',
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

generalTab:CreateButton({
    name = 'Reset Interface Layout',
    icon = 125823673784681,
    callback = function()
        print('Interface layout reset')
    end
})


-- stats
local statsTab = window:CreateTab({
    name = 'Statistics',
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

statsTab:CreateSection({ name = 'Quick Actions' })

statsTab:CreateButton({
    name = 'Simulate Sale',
    callback = function()
        revenue:Set(revenue.value + math.random(500, 3000))
    end
})

statsTab:CreateButton({
    name = 'Reset Tracking',
    description = 'Clears the change indicator and starts fresh from the current value.',
    callback = function()
        revenue:ResetBaseline()
    end
})

