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

tab:CreateStat({
    name = 'Stat',
    -- other stuff
    
    callback = function()
        --window:ChangeTheme('default')
    end
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
    description = 'This is a description for the switch component, it can be pretty long so it will automatically wrap around to the next line.',
    -- other stuffss
    
    callback = function(value)
        print(value)
    end
})

tab:CreateButton({
    name = 'Button',
    -- other stuff
    
    callback = function()
        --window:ChangeTheme('default')
    end
})


local buttontest = tab:CreateButton({
    name = 'Button 1',
    -- other stuff
    
    callback = function()
        --window:ChangeTheme('default')
    end
})

tab:CreateToggle({
    name = 'Switch 1',
    -- other stuffss
    
    callback = function(value)
        print(value)
    end
})



tab:CreateSwitch({
    name = 'Switch 2',
    -- other stuffss
    
    callback = function(value)
        print(value)
    end
})

tab:CreateButton({
    name = 'Move "Button 1" Up',
    -- other stuff
    
    callback = function()
        buttontest:MoveUp()
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

