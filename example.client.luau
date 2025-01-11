local WindowComponent = require(game:GetService("ReplicatedStorage").Rayfield)
local window = WindowComponent.new("Window Name")

task.wait(5)

print('unloading')

window:Unload()