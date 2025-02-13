local rep = game:GetService("ReplicatedStorage")

local WindowComponent = require(rep.Rayfield)

local window = WindowComponent.new({
    name = 'Window',
    subtitle = 'Rayfield Gen2',
    --icon = 118726904892537,

    theme = 'pacific'
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
        window:ChangeTheme('default')
    end
})

tab:CreateToggle({
    name = 'Switch',
    -- other stuff
    
    callback = function(value)
        print(value)
    end
})



task.wait(5)

--window:Unload()