local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local partsFolder = workspace:WaitForChild("GunParts") :: Folder

local assemblyBench = workspace:WaitForChild("AssemblyBench") :: BasePart 

local gunComponents: {Model} = {} -- models of gun components like recevier, barrel etc.
local slots: { BasePart}  = {}  -- slots for gun compoaents to snap to

local occupiedSlots: {[BasePart]: Model} = {}

local SNAP_RADIUS: number = 5   


local isAssembled: boolean

local activeGunTweens: {[Model] : Tween} = {} -- tracking tweens for gun pieces

local function tweenGunPiece(piece: Model, targetCFrame: CFrame)

    if activeGunTweens[piece] then
        activeGunTweens[piece]:Cancel() -- cancel tween if it already started 
    end

    local pieceCFrameValue = Instance.new("CFrameValue") -- using cframevalue for gun piece position tweening (primary part method is kinda laggy)
    pieceCFrameValue.Value = piece:GetPivot() -- storing gun piece cframe

    local conn = pieceCFrameValue.Changed:Connect(function() --saving connection for cleanup 
        piece:PivotTo(pieceCFrameValue.Value) --changing gun piece postiion when cframevalue changed
    end)


    local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad) -- 1 second smooth animation
    local tween = TweenService:Create(pieceCFrameValue, tweenInfo, {Value = targetCFrame}) -- creating a tween which gonna change pieceCFrameValue.Value
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


local function onDragEnd(gunPiece: Model) -- called when gun piece released from mouse
    if #gunComponents == 0 or #slots == 0 then return end --safe check if data hasnt initialized yet
    local currentlySnapped = {}
    local currentOccupiedCount = 0 -- tracking ouccpied slots size

    for _, slot in ipairs(slots) do
            --pieces are Model so we use GetPivot 
            local piecePos = gunPiece:GetPivot().Position
            local pieceRot = gunPiece:GetPivot().Rotation

            local slotPos = slot.Position
            
            warn((piecePos - slotPos).Magnitude)
            if (piecePos - slotPos).Magnitude < SNAP_RADIUS then -- distance from slotPos to piecePos
                currentlySnapped[slot] = gunPiece
                
                local targetCframe = CFrame.new(slotPos) * pieceRot -- keeping the original rotation
                --gunPiece:PivotTo(targetCframe + Vector3.new(0, 1.5, 0)) -- slightly above the slot to not overlap with table
                tweenGunPiece(gunPiece, targetCframe + Vector3.new(0, 1.5, 0))-- slightly above the slot to not overlap with table               break --breaking slot loop cuz its occupied now
            end
    end 
    
    for _, slot in ipairs(slots) do
        if currentlySnapped[slot] then
            --saving occupied slots
            occupiedSlots[slot] = currentlySnapped[slot]
            currentOccupiedCount += 1
        else
            --cleaning up
            occupiedSlots[slot] = nil
        end
    end

    
    if currentOccupiedCount >= #slots then
        isAssembled = true
        print("GUN ASSEMBLED!")
    else
        isAssembled = false
    end
end


local function setupGunComponent(gunPiece : Model)
    --checking if all parts are anchored ()
    for _, part in ipairs(gunPiece:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
        end
    end
    
    -- checking for primary part
    if not gunPiece.PrimaryPart then
        warn("Gun Component does not have a Primary Part inside: " .. gunPiece.Name)
    end

    --checking for drag detector
    local dragDetector = gunPiece:FindFirstChildOfClass("DragDetector")
    if not dragDetector then        
        warn("Gun Component does not have a drag detector inside: " .. gunPiece.Name)
        return
    end

    --setting up drag detector
    dragDetector.ResponseStyle = Enum.DragDetectorResponseStyle.Geometric -- setting Gemotric cuz otherwise it will not work with anchored objects
    dragDetector.DragEnd:Connect(function()
        onDragEnd(gunPiece)
    end)

    dragDetector.DragStart:Connect(function() -- canceling tween if we started to drag a piece which is already tweening
        local tween = activeGunTweens[gunPiece]
        if tween then
            tween:Cancel() -- cancel function also causes Completed event on tweens
        end
    end)
    
end


-- collecting gun parts and part slots 
local function collectObjects()
    for _, gunPiece in partsFolder:GetDescendants() do 
        if gunPiece:IsA("Model") then
            print("Found Gun Component: " .. gunPiece.Name)   
            setupGunComponent(gunPiece)
            table.insert(gunComponents, gunPiece)    
        end
    end
    for _, slot in assemblyBench:GetDescendants() do
        if slot:IsA("BasePart") then
            slot.Anchored = true -- for safety anchoring and setting cant collide
            slot.CanCollide = false
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

collectObjects() -- collecting all objects




--[[
RunService.Heartbeat:Connect(function()
    if #gunComponents == 0 then return end
    local currentlySnapped = {}
    local currentOccupiedCount = 0 -- tracking ouccpied slots size
    

    for _, piece in ipairs(gunComponents) do
        for _, slot in ipairs(slots) do
            --pieces are Model so we use GetPivot 
            local piecePos = piece:GetPivot().Position
            local pieceRot = piece:GetPivot().Rotation

            local slotPos = slot.Position
            
            if (piecePos - slotPos).Magnitude < SNAP_RADIUS then -- distance from slotPos to piecePos
                currentlySnapped[slot] = piece

                local targetCframe = CFrame.new(slotPos) * pieceRot -- keeping the original rotation
                --piece:PivotTo(targetCframe + Vector3.new(0, 1.5, 0)) -- slightly above the slot to not overlap with table
                tweenGunPiece(piece, targetCframe + Vector3.new(0, 1.5, 0))-- slightly above the slot to not overlap with table               break --breaking slot loop cuz its occupied now
            end
        end 
            
    
    end

    for _, slot in ipairs(slots) do
        if currentlySnapped[slot] then
            --saving occupied slots
            occupiedSlots[slot] = currentlySnapped[slot]
            currentOccupiedCount += 1
        else
            --cleaning up
            occupiedSlots[slot] = nil
        end
    end

    
    if currentOccupiedCount >= #slots then
        isAssembled = true
        print("GUN ASSEMBLED!")
    else
        isAssembled = false
    end

end)
--]]



--[[
while true do
    task.wait(3)
    warn(slots)
end
--]]
