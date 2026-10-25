local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local partsFolder = workspace:WaitForChild("GunParts") :: Folder

local assemblyBench = workspace:WaitForChild("AssemblyBench") :: BasePart

local gunComponents: { Model } = {} -- models of gun components like recevier, barrel etc.
local slots: { BasePart } = {} -- slots for gun compoaents to snap to
local occupiedSlots: { [BasePart]: Model } = {}

local SNAP_RADIUS: number = 5

local function verifyAssembly()
	for slot, piece in occupiedSlots do
		if slot:GetAttribute("ComponentType") == piece:GetAttribute("ComponentType") then
			return true
		else
			return false
		end
	end
	return false
end


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
	return tween
end

local function onDragStart(gunPiece: Model)
	if #gunComponents == 0 or #slots == 0 then
		return
	end --safe check if data hasnt initialized yet
	-- canceling tween if we started to drag a piece which is already tweening
	local tween = activeGunTweens[gunPiece]
	if tween then
		tween:Cancel() -- cancel function also causes Completed event on tweens
	end

    -- if piece which we started to drag were in slot we free up this slot
	for slot, occupiedPiece in pairs(occupiedSlots) do
		if occupiedPiece == gunPiece then
			occupiedSlots[slot] = nil
		end
	end
end

local function onDragEnd(gunPiece: Model) -- called when gun piece released from mouse
	if #gunComponents == 0 or #slots == 0 then
		return
	end

	for _, slot in ipairs(slots) do
		--pieces are Model so we use GetPivot to get a CFrame
		local piecePos = gunPiece:GetPivot().Position
		local pieceRot = gunPiece:GetPivot().Rotation

		local slotPos = slot.Position

		if not occupiedSlots[slot] then --safe check to avoid stacking pieces on top of each other
			if (piecePos - slotPos).Magnitude < SNAP_RADIUS then -- distance from slotPos to piecePos
				occupiedSlots[slot] = gunPiece

				local targetCframe = CFrame.new(slotPos) * pieceRot -- keeping the original rotation
				tweenGunPiece(gunPiece, targetCframe + Vector3.new(0, 1.5, 0)) -- slightly above the slot to not overlap with table
				break --breaking slot loop cuz its occupied now
			end
		end
	end

	local currentOccupiedCount = 0 -- tracking ouccpied slots size
	for _, slot in ipairs(slots) do
		if occupiedSlots[slot] then
			currentOccupiedCount += 1
		end
	end

	if currentOccupiedCount >= #slots then	
		if verifyAssembly() then
			warn("Gun assembled correctly")
		else
			warn("Gun assembled incorrectly")
		end
	end
end

local function setupGunComponent(gunPiece: Model)
	if not gunPiece:GetAttribute("ComponentType") then
		warn("Gun Component does not have an attribute ComponentType: " .. gunPiece.Name)
	end

	--checking if all parts are anchored ()
	for _, part in ipairs(gunPiece:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end

	--checking for drag detector
	local dragDetector = gunPiece:FindFirstChildOfClass("DragDetector")
	if not dragDetector then
		warn("Gun Component does not have a drag detector inside: " .. gunPiece.Name)
		return
	end

	--setting up drag detector
	dragDetector.ResponseStyle = Enum.DragDetectorResponseStyle.Geometric -- setting Gemotric cuz otherwise it will not work with anchored objects
	dragDetector.DragEnd:Connect(function() -- connecting a helper function on end of mouse drag
		onDragEnd(gunPiece)
	end)

	dragDetector.DragStart:Connect(function()
		onDragStart(gunPiece)
	end)
end

local function setupGunSlot(slot: BasePart)
	slot.Anchored = true -- for safety anchoring and setting cant collide
	slot.CanCollide = false


	if not slot:GetAttribute("ComponentType") then
		warn("Slot for gun component does not have an attribute ComponentType: " .. slot.Name)
	end
end
-- collecting gun parts and part slots
local function setupAllObjects()
	for _, gunPiece in partsFolder:GetDescendants() do
		if gunPiece:IsA("Model") then
			print("Found Gun Component: " .. gunPiece.Name)
			setupGunComponent(gunPiece)
			table.insert(gunComponents, gunPiece)
		end
	end
	for _, slot in assemblyBench:GetDescendants() do
		if slot:IsA("BasePart") then
			setupGunSlot(slot)
			table.insert(slots, slot)
		end
	end

	if #gunComponents == 0 then
		warn("no gun parts foundd")
	end

	if #slots == 0 then
		warn("no gun part's slots were founded")
	end
end

setupAllObjects() -- collecting all objects
