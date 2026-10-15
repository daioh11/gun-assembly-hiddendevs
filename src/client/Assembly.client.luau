local RunService = game:GetService("RunService")
local partsFolder = workspace:WaitForChild("GunParts") :: Folder

local assemblyBench = workspace:WaitForChild("AssemblyBench") :: BasePart 

local gunComponents: {Model} = {} -- models of gun components like recevier, barrel etc.
local slots: { BasePart}  = {}  -- slots for gun compoaents to snap to

local occupiedSlots = {}

local SNAP_RADIUS = 5   

local function setupGunComponent(gunPiece : Model)
    local dragDetector = gunPiece:FindFirstChildOfClass("DragDetector")
    if not dragDetector then        
        warn("Gun Component does not have a drag detector inside: " .. gunPiece.Name)
        return
    end

    dragDetector.ResponseStyle = Enum.DragDetectorResponseStyle.Geometric -- setting Gemotric cuz otherwise it will not work with anchored objects

    --checking if all parts are ancored
    for _, part in ipairs(gunPiece:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
        end
    end

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

collectObjects()

RunService.Heartbeat:Connect(function()
    if #gunComponents == 0 then return end
    local currentlySnapped = {}

    for _, piece in ipairs(gunComponents) do
        for _, slot in ipairs(slots) do
            --pieces are Model so we use GetPivot 
            local piecePos = piece:GetPivot().Position
            local pieceRot = piece:GetPivot().Rotation

            local slotPos = slot.Position
            
            if (piecePos - slotPos).Magnitude < SNAP_RADIUS then -- distance from slotPos to piecePos
                currentlySnapped[slot] = piece

                local targetCframe = CFrame.new(slotPos) * pieceRot -- keeping the original rotation
                piece:PivotTo(targetCframe + Vector3.new(0, 1.5, 0)) -- slightly above the slot to not overlap with table

                break --breaking slot loop cuz its occupied now
            end
        end 
            
    
    end

    for _, slot in ipairs(slots) do
        if currentlySnapped[slot] then
            --saving occupied slots
            occupiedSlots[slot] = currentlySnapped[slot]
        else
            --cleaning up
            occupiedSlots[slot] = nil
        end
    end
end)

while true do
    task.wait(3)
    warn(occupiedSlots)
end