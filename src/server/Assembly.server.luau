-- Connected Discord-GitHub

-- gun assembly script where you drag a gun components in slots
-- despite client logic its a server script for leaderstats working

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local SNAP_RADIUS: number = 3

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
	if not leaderstats then
		return
	end

	local bestTimeVal = leaderstats:FindFirstChild("Best Time") --checking for best time
	if not bestTimeVal then
		return
	end

	-- checking if its a first assembly or new time is lower then current
	if bestTimeVal.Value == 0 or newTime < bestTimeVal.Value then
		bestTimeVal.Value = tonumber(string.format("%.2f", newTime)) -- rounding score to 2 decimal places
		print(string.format("New personal record: %.2f sec", bestTimeVal.Value)) -- printing rounded score
	end
end

-- ASSEMBlY BENCH

local AssemblyBench = {}
AssemblyBench.__index = AssemblyBench -- failed lookups on an object fall through to this table

function AssemblyBench.new(slots)
	local highlights: { [BasePart]: Highlight } = {}

	-- 
	local filter: { Instance } = {} -- filter for searching slots

	for _, slot in slots do
		table.insert(filter, slot)
		
		-- anchored and non-collidable so pieces doesnt collide with slots
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

	-- creating OverlapParams with Include filter so it restricts the collisions to slots only
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = filter

	return setmetatable({ --returning new assembly bench object
		slots = slots,
		overlapParams = overlapParams,
		hovered = {}, -- last slot found for each piece being dragged
		highlights = highlights,
		occupied = {},
		occupiedCount = 0,
		startedAt = nil, -- os.clock() value at the start of the run, nil while no run is active
		assembler = nil, -- player who started the run
	}, AssemblyBench)
end


-- distance from a point to the surface of a slot's box
--center distance is wrong for large slots, a point rihgt above the edge of big slot is far from its center
local function distanceToSlotSurface(point: Vector3, slot: BasePart): number
	--slot's local space makes the box axis-aligned even ifslot is rotated in the world 
	local localPoint = slot.CFrame:PointToObjectSpace(point)
	local half = slot.Size / 2

	--clamp each axis to the slots half size
	local clamped = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)

	return (localPoint - clamped).Magnitude
end

function AssemblyBench.FindClosestSlot(self, piece: Model): BasePart?
	-- GetPivot works for any Model, even one that has no PrimaryPart set
	local piecePos = piece:GetPivot().Position
	local closestSlot: BasePart? = nil --BasePart? cuz no slot may be in range

	local closestDistance: number = SNAP_RADIUS -- starting at the snap radius


	-- game returns only slots near the piece
	for _, slot in workspace:GetPartBoundsInRadius(piecePos, SNAP_RADIUS, self.overlapParams) do
		if self.occupied[slot] then
			continue -- an occupied slot cannot take a second piece
		end
		
		---query only tells us which slot boxes touch the sphere
		local distance = distanceToSlotSurface(piecePos, slot)
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

function AssemblyBench.BeginRun(self, player: Player)
	if self.startedAt then
		return --a run is already started
	end

	self.startedAt = os.clock()
	self.assembler = player
	print(player.Name .. " started the run")
end

-- returns both values to know the caller and how long did run took
function AssemblyBench.FinishRun(self): (Player?, number?)
	local startedAt = self.startedAt
	local assembler = self.assembler

	--resetting before returning sp it cant award twice
	self.startedAt = nil
	self.assembler = nil

	-- nil means the run never started
	if not startedAt then
		return nil, nil
	end
	return assembler, os.clock() - startedAt
end

function AssemblyBench.AbandonRun(self, player: Player)
	-- if player leaves mid-run the clock would keep ticking
	if self.assembler == player then
		self.startedAt = nil
		self.assembler = nil
	end
end

function AssemblyBench.OnDragStart(self, player: Player, piece: Model)
	-- clock starts only on an empty bench, so moving pieces around mid-assembly does not restart it
	if self.occupiedCount == 0 then
		self:BeginRun(player)
	end

	-- if gun piece is still animating, the tween would keep pulling it away from the cursor
	local tween = activeGunTweens[piece]
	if tween then
		tween:Cancel()
	end

	self:Release(piece) --a grabbed gun piece frees its slot so another piece can use it
end

function AssemblyBench.OnDragContinue(self, piece: Model)
	local closesSlot = self:FindClosestSlot(piece)
	self.hovered[piece] = closesSlot --saved so OnDragEnd doesmnt repeat the same query
	self:UpdateHighlights(closesSlot)
end

function AssemblyBench.OnDragEnd(self, piece: Model)
	self:UpdateHighlights(nil) -- nothing is about to snap once mouse is released

	local closestSlot = self.hovered[piece]
	self.hovered[piece] = nil --cleared so stale slot cant be reused on next drag

	if closestSlot and not self.occupied[closestSlot] then
		self:Snap(piece, closestSlot)
	end

	if not self:IsComplete() then
		return
	end

	if not self:VerifyAssembly() then
		print("Gun assembled incorrectly")
		return
	end

	local assembler, seconds = self:FinishRun()
	if assembler and seconds then --nil means the run never started so there is nothign to record
		print(string.format("%s assembled the gun in %.2f seconds", assembler.Name, seconds))
		updateBestTime(assembler, seconds)
	end
end


local function setupGunComponent(assemblyBench, gunPiece: Model)
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

	dragDetector.DragEnd:Connect(function()
		assemblyBench:OnDragEnd(gunPiece)
	end)

	dragDetector.DragStart:Connect(function(player)
		assemblyBench:OnDragStart(player, gunPiece)
	end)

	dragDetector.DragContinue:Connect(function() -- fires every frame of mouse dragging
		assemblyBench:OnDragContinue(gunPiece)
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

	local bench = AssemblyBench.new(slots)

	-- connected here because this is the only place that holds a reference to the assembly bench
	Players.PlayerRemoving:Connect(function(player: Player)
		bench:AbandonRun(player)
	end)

	local pieceCount = 0
	for _, gunPiece in CollectionService:GetTagged(PART_TAG) do --searching gun components by tags too
		if gunPiece:IsA("Model") then
			setupGunComponent(bench, gunPiece)
			pieceCount += 1
		end
	end

	if pieceCount == 0 then
		warn("no gun parts foundd")
	end
end

setupAllObjects() -- collecting all objects
