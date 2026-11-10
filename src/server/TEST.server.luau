local Modules = script.Parent.Modules
local Leaderstats = require(Modules.Leaderstats)

Leaderstats.Register("Best Time")
Leaderstats.Start()

task.wait(5)
for _, player in game.Players:GetPlayers() do
	print(Leaderstats.Submit(player, "Best Time", 12.34)) 
end