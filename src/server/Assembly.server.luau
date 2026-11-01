-- Connected Discord-GitHub

-- gun assembly script where you drag a gun components in slots 
-- despite client logic its a server script for leaderstats working


local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local gunComponents: { Model } = {} -- models of gun components like recevier, barrel etc.
local slots: { BasePart } = {} -- slots for gun compoaents to snap to
local occupiedSlots: { [BasePart]: Model } = {} -- slots occupied by snapped gun components

local SNAP_RADIUS: number = 5

--tags for searching objects
local PART_TAG: string = "GunPart" 
local SLOT_TAG: string = "GunSlot"	



local activeGunTweens: { [Model]: Tween } = {} -- tracking tweens for gun pieces
local function tweenGunPiece(piece: Model, targetCFrame: CFrame) -- smooth snapping a piece
	if activeGunTweens[piece] then
		activeGunTweens[piece]:Cancel() -- cancel tween if it already started
	end

	local pieceCFrameValue = Instance.new("CFrameValue") -- using cframevalue for gun piece position tweening (primary part method is kinda laggy)
	pieceCFrameValue.Value = piece:GetPivot() -- storing gun piece cframe

	local conn = pieceCFrameValue.Changed:Connect(function() --saving connection for cleanup
		piece:PivotTo(pieceCFrameValue.Value) --changing gun piece postiion when cframevalue changed
	end)

	local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad) -- 1 second smooth animation
	local tween = TweenService:Create(pieceCFrameValue, tweenInfo, { Value = targetCFrame }) -- creating a tween which gonna change pieceCFrameValue.Value
	activeGunTweens[piece] = tween -- saving current tween

	-- cleaning up
	tween.Completed:Connect(function() --disconnecting and destroying all data and cleaning tweens data
		conn:Disconnect()
		pieceCFrameValue:Destroy()
		if activeGunTweens[piece] == tween then
			activeGunTweens[piece] = nil
		end
	end)

	tween:Play()
end

-- stopwatch logic 

local startedAt = nil

local function startStopwatch()
	if startedAt then return end -- if not nil it means already started so we returning to not overwrite
	print("the clock has started")
	startedAt = os.clock() --saving time
end

local function stopAndGetStopwatch()
	if not startedAt then return nil end -- if not started then we just return nil

	local elapsed = os.clock() - startedAt -- elapsed time from start
	startedAt = nil --cleanuo
	return elapsed
end



--leaderstats logic

Players.PlayerAdded:Connect(function(player) -- this function called on spawning a player
    local leaderstats = Instance.new("Folder") --creating a leaderstats instance to track records
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local bestTimeVal = Instance.new("NumberValue") -- creating a stat in Tab menu
    bestTimeVal.Name = "Best Time" 
    bestTimeVal.Value = 0 
    bestTimeVal.Parent = leaderstats
end)


local function updateBestTime(player, newTime: number) -- function for updating record time
    local leaderstats = player:FindFirstChild("leaderstats") --checking for leaderstats instancae
    if not leaderstats then return end
    
    local bestTimeVal = leaderstats:FindFirstChild("Best Time") --checking for best time 
    if not bestTimeVal then return end

    -- checking if its a first assembly or new time is lower then current
    if bestTimeVal.Value == 0 or newTime < bestTimeVal.Value then
        bestTimeVal.Value = tonumber(string.format("%.2f", newTime)) -- rounding score to 2 decimal places
        print(string.format("New personal record: %.2f sec", bestTimeVal.Value)) -- printing rounded score 
    end
end


-- ASSEMBlY BENCH

local AssemblyBench = {}
AssemblyBench.__index = AssemblyBench  -- failed lookups on an object fall through to this table

function AssemblyBench.new(slots) 
	local highlights: { [BasePart]: Highlight } = {}


	for _, slot in slots do
		-- anchored and non-collidable so pieces dropped near a slot are not pushed away by it
		slot.Anchored = true
		slot.CanCollide = false

		if not slot:GetAttribute("ComponentType") then
			warn("Slot for gun component does not have an attribute ComponentType: " .. slot.Name)
		end

		-- searching once and caching the result avoids repeated child lookups later
		local highlight = slot:FindFirstChildOfClass("Highlight")
		if highlight then
			highlight.Enabled = false -- start hidden so only the slot being approached lights up
			highlights[slot] = highlight
		else
			warn("Slot for gun component does not have a Highlight object inside: " .. slot.Name)
		end
	end

	return setmetatable({ --returning new assembly bench object
		slots = slots,
		highlights = highlights,
		occupied = {},
		occupiedCount = 0,
	}, AssemblyBench)


end

function AssemblyBench.FindClosestSlot(self, piece: Model): BasePart?
	-- GetPivot works for any Model, even one that has no PrimaryPart set
	local piecePos = piece:GetPivot().Position
	local closestSlot: BasePart? = nil --BasePart? cuz no slot may be in range
	local closestDistance = SNAP_RADIUS -- starting at the radius makes the "in range" check part of the comparison

	for _, slot in self.slots do
		if self.occupied[slot] then
			continue -- an occupied slot cannot take a second piece
		end

		local distance = (piecePos - slot.Position).Magnitude
		if distance < closestDistance then
			closestDistance = distance
			closestSlot = slot	
		end
	end

	return closestSlot
end


function AssemblyBench.UpdateHighlights(self, closestSlot: BasePart?)
	--only the closest slot is lit
	for slot, highlight in self.highlights do
		highlight.Enabled = (slot == closestSlot)
	end
end

function AssemblyBench.Release(self, piece: Model)
	for slot, occupant in self.occupied do
		if occupant == piece then
			self.occupied[slot] = nil
			self.occupiedCount -= 1
			break --piece sits in one slot at most, so there is nothing left to search
		end
	end
end

function AssemblyBench.Snap(self, piece: Model, slot: BasePart)
	self.occupied[slot] = piece
	self.occupiedCount += 1

	--keeping the piece's own rotation and lifting it by 1.5 studs so it does not overlap the bench
	local targetCFrame = CFrame.new(slot.Position) * piece:GetPivot().Rotation + Vector3.new(0, 1.5, 0)
	tweenGunPiece(piece, targetCFrame)
end

function AssemblyBench.IsComplete(self): boolean
	return self.occupiedCount >= #self.slots
end

function AssemblyBench.VerifyAssembly(self): boolean
	-- gun piece is correct when its ComponentType attribute matches the slot it sits in
	for slot, piece in self.occupied do
		if slot:GetAttribute("ComponentType") ~= piece:GetAttribute("ComponentType") then
			return false
		end
	end
	return true
end

function AssemblyBench.OnDragStart(self, piece: Model)
	-- clock starts only on an empty bench, so moving pieces around mid-assembly does not restart it
	if self.occupiedCount == 0 then
		startStopwatch()
	end

	-- if gun piece is still animating, the tween would keep pulling it away from the cursor
	local tween = activeGunTweens[piece]
	if tween then
		tween:Cancel()
	end

	self:Release(piece) --a grabbed gun piece frees its slot so another piece can use it
end

function AssemblyBench.OnDragContinue(self, piece: Model)
	self:UpdateHighlights(self:findClosestSlot(piece))
end


function AssemblyBench.OnDragEnd(self, player: Player, piece: Model)
	self:UpdateHighlights(nil) -- nothing is about to snap once the mouse is released

	local closestSlot = self:FindClosestSlot(piece)
	if closestSlot then
		self:Snap(piece, closestSlot)
	end

	if not self:IsComplete() then
		return
	end

	if not self:VerifyAssembly() then
		print("Gun assembled incorrectly")
		return
	end

	print("Gun assembled correctly")
	local time = stopAndGetStopwatch()
	--nil means the run never started so there is nothign to record
	if time then
		print(string.format("Gun assembled in %.2f seconds", time))
		updateBestTime(player, time)
	end
end


local function getClosestGunSlot(gunPiece: Model, searchRadius: number): BasePart?
	--pieces are Model so we use GetPivot to get a cframe
	local piecePos = gunPiece:GetPivot().Position
	local closestSlot = nil
	local closestDistance = searchRadius

	for _, slot in ipairs(slots) do
		if occupiedSlots[slot] then
			continue -- we skipping occupied slots
		end

		local distance = (piecePos - slot.Position).Magnitude -- distance between piece pos and slot pos
		if distance < closestDistance then -- updating variables if we found slot in radius
			closestDistance = distance
			closestSlot = slot
		end
	end

	return closestSlot
end

local slotHighlights: {} = {} -- storing highlight objects for slots

local function onDragStart(gunPiece: Model)
	if #gunComponents == 0 or #slots == 0 then --safe check if data hasnt initialized yet
		return
	end

	if next(occupiedSlots) == nil then -- !!! starting stopwatch again only if bench is empty          ("next" func cuz occupiedSlots is a dict)
		startStopwatch() --starting time
	end
	-- canceling tween if we started to drag a piece which is already tweening
	local tween = activeGunTweens[gunPiece]
	if tween then
		tween:Cancel() -- cancel function also causes Completed event on tweens
	end

	-- if piece which we started to drag were in slot we free up this slot
	for slot, occupiedPiece in occupiedSlots do
		if occupiedPiece == gunPiece then
			occupiedSlots[slot] = nil
		end
	end
end

local function onDragEnd(player, gunPiece: Model) -- called when gun piece released from mouse
	if #gunComponents == 0 or #slots == 0 then
		return
	end

	for _, highlight in slotHighlights do -- disabling all highlights
		highlight.Enabled = false
	end

	local closesSlot = getClosestGunSlot(gunPiece, SNAP_RADIUS)

	if closesSlot then
		occupiedSlots[closesSlot] = gunPiece --assigning gun piece to closest slot

		local targetCframe = CFrame.new(closesSlot.Position) * gunPiece:GetPivot().Rotation -- keeping the original rotation

		tweenGunPiece(gunPiece, targetCframe + Vector3.new(0, 1.5, 0)) -- slightly above the slot to not overlap with table
	end

	local currentOccupiedCount = 0 -- tracking ouccpied slots size
	for _, slot in ipairs(slots) do
		if occupiedSlots[slot] then
			currentOccupiedCount += 1
		end
	end

	if currentOccupiedCount >= #slots then
		if verifyAssembly() then
			print("Gun assembled correctly")
			local time = stopAndGetStopwatch() -- stopping and saving stopwatch time	

			if time then -- if time is nil it means assembly didnt start yet
				print(string.format("Gun assembled in %.2f seconds", time)) --rounding second to 2 decimal places

				updateBestTime(player, time) --updating record

			end
		else
			print("Gun assembled incorrectly")
		end
	end
end

local function onDragContinue(gunPiece: Model) --called every frame on piece dragging
	local closestSlot = getClosestGunSlot(gunPiece, SNAP_RADIUS) -- getting closest slto

	for slot, highlight in slotHighlights do
		if closestSlot == slot then --checking if we are nearby a closest slot
			highlight.Enabled = true
		else
			highlight.Enabled = false
		end
	end
end

local function setupGunComponent( gunPiece: Model)
	if not gunPiece:GetAttribute("ComponentType") then 
		warn("Gun Component does not have an attribute ComponentType: " .. gunPiece.Name)
	end

	-- anchored pieces cannot fall off the bench or be knocked by physics while dragged
	for _, part in ipairs(gunPiece:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end

	local dragDetector = gunPiece:FindFirstChildOfClass("DragDetector")
	if not dragDetector then
		warn("Gun Component does not have a drag detector inside: " .. gunPiece.Name)
		return
	end

	--setting up drag detector

	dragDetector.ResponseStyle = Enum.DragDetectorResponseStyle.Geometric --- Geometric moves the piece by setting its CFrame so it works with anchored parts
	
	dragDetector.DragEnd:Connect(function(player)
		onDragEnd(player, gunPiece) -- passing player for updating records
	end)

	dragDetector.DragStart:Connect(function() 
		onDragStart(gunPiece)
	end)

	dragDetector.DragContinue:Connect(function() -- fires every frame of mouse dragging 
		onDragContinue(gunPiece)
	end)
end


-- collecting gun parts and part slots
local function setupAllObjects()
	local slots: { BasePart } = {}
	for _, slot in CollectionService:GetTagged(SLOT_TAG) do --searchign slots by tags game-wide
		if slot:IsA("BasePart") then
			table.insert(slots, slot)
		end
	end

	if #slots == 0 then
		warn("no gun part's slots were founded")
		return 
	end


	local pieceCount = 0
	for _, gunPiece in CollectionService:GetTagged(PART_TAG) do --searching gun components by tags too
		if gunPiece:IsA("Model") then
			setupGunComponent( gunPiece)
			pieceCount += 1
		end
	end

	if pieceCount == 0 then
		warn("no gun parts foundd")
	end
end

setupAllObjects() -- collecting all objects


