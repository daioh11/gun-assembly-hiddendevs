local Players = game:GetService("Players")

local RecordStore = require(script.Parent.RecordStore)


local Leaderstats = {}

local statNames: {string} = {}
local values = {}

function Leaderstats.Register(statName: string)
	table.insert(statNames, statName)
end


local function setupLeaderstats(player: Player)
	--creating leaderstats in tab menu
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

    local playerValues = {}
    for _, name in statNames do
		local value = Instance.new("NumberValue")
		value.Name = name
		--record load yieldsso it runs before parenting
		value.Value = RecordStore.Load(player, name)
		value.Parent = leaderstats
		playerValues[name] = value
	end


	if not player.Parent then
		return --player left while the DataStore requesting
	end
    values[player] = playerValues
	leaderstats.Parent = player
end

--returns true only if time was accepted as new record
function Leaderstats.Submit(player: Player, statName: string, newTime: number): boolean
	local playerValues = values[player]
	local value = if playerValues then playerValues[statName] else nil

	-- nil means the stat was never registeredor data still loading
	if not value then
		return false
	end

	-- 0 means "no record yet"
	if value.Value == 0 or newTime < value.Value then
		value.Value = newTime
		--it gets its own thread and doesnt block caller
		task.spawn(RecordStore.Save, player, statName, newTime)
		return true
	end
	return false
end

function Leaderstats.Start()
	Players.PlayerAdded:Connect(setupLeaderstats)
	Players.PlayerRemoving:Connect(function(player: Player)
		values[player] = nil --cleanup
	end)

	-- players who joined before script started would never get leaderstats so we setting up again with task.spawn to avoid yeld
	for _, player in Players:GetPlayers() do
		task.spawn(setupLeaderstats, player)
	end
end


return Leaderstats