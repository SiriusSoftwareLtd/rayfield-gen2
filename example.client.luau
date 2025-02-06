local WindowComponent = require(game:GetService("ReplicatedStorage").Rayfield)
local window = WindowComponent.new({
    name = 'Window name ye',

    theme = 'default'
})

warn('init rayfield')
window:CreateTab({
    name = 'Tab Example 1',
    icon = 91452555903853,
})
local tab = window:CreateTab({
    name = 'Tab Example 2',
    icon = 129180860773723,
})

tab:CreateButton({
    name = 'Button',
    -- other stuff
    
    callback = function()
        print('yo')
    end
})



task.wait(5)

--print('unloading')

--window:Unload()