local DataStoreService = game:GetService("DataStoreService")

local Config = require(script.Parent.AssemblyConfig)

local RecordStore = {}

local recordStore = DataStoreService:GetDataStore(Config.StoreName)

local function getKeyFor(player: Player, statName: string): string
	--record follows user id
	return "Player_" .. player.UserId .. "_" .. statName
end

function RecordStore.Load(player: Player, statName: string): number
	--pcall keeps a failed load from breaking the player's join
	local ok, stored = pcall(function()
		return recordStore:GetAsync(getKeyFor(player, statName))
	end)

    -- typeof guards against corrupted valeu 
    --if ok is false stored holds the error text
	if ok and typeof(stored) == "number" then
		return stored
	end
	return 0 -- 0means "no record yet"
end

function RecordStore.Save(player: Player, statName: string, newRecord: number): boolean
	for attempt = 1, 3 do -- few attempts for saving just in case
		local ok = pcall(function()
			-- updateAsync re-reads the stored value before writing so old server can never overwrite a better time that another server has saved unlike SetAsync
			recordStore:UpdateAsync(getKeyFor(player, statName), function(old)
				if old and old > 0 and old <= newRecord then
					return old -- stored time is already better
				end
				return newRecord
			end)
		end)

		if ok then
			return true
		end
		task.wait(2 ^ attempt) -- waiting 2, 4, 8 secndos sp retries do not hit same window
	end

	warn("Could not save record for " .. player.Name)
	return false
end

return RecordStore