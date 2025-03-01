local rep = game:GetService("ReplicatedStorage")

local Rayfield = require(rep.Rayfield)

task.wait(2)
local window = Rayfield:CreateWindow({
    name = 'Window',
    subtitle = 'Rayfield Gen2',
    --icon = 118726904892537,

    theme = 'default'
})

local tab = window:CreateTab({
    name = 'Tab Example 1',
    icon = 91452555903853,
})
window:CreateTab({
    name = 'Tab Example 2',
    icon = 91452555903853,
})

tab:CreateButton({
    name = 'Button',
    -- other stuff
    
    callback = function()
        --window:ChangeTheme('default')
    end
})

tab:CreateToggle({
    name = 'Switch',
    -- other stuffss
    
    callback = function(value)
        print(value)
    end
})
