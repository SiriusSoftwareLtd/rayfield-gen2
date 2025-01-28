local WindowComponent = require(game:GetService("ReplicatedStorage").Rayfield)
local window = WindowComponent.new("Window Name")

warn('init rayfield')
window:CreateTab({
    name = 'Tab Example 1',
    icon = 91452555903853,
})
window:CreateTab({
    name = 'Tab Example 2',
    icon = 129180860773723,
})

task.wait(5)

--print('unloading')

--window:Unload()