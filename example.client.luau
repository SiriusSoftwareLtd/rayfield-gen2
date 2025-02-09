local WindowComponent = require(game:GetService("ReplicatedStorage").Rayfield)

local window = WindowComponent.new({
    name = 'Window',
    subtitle = 'Rayfield Gen2',
    --icon = 118726904892537,

    theme = 'pacific'
})

warn('init rayfield')
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
        print(5)
    end
})



task.wait(5)

--print('unloading')

--window:Unload()