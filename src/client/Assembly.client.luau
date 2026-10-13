local RunService = game:GetService("RunService")
local partsFolder = workspace:WaitForChild("GunParts") :: Folder

local assemblyBench = workspace:WaitForChild("AssemblyBench") :: BasePart 

local gunPieces: {Model} = {}
local slots: { BasePart}  = {} 

local occupiedSlots = {}

local SNAP_RADIUS = 7 


-- collecting gun parts and part slots 
local function collectObjects()
    for _, gunPart in partsFolder:GetDescendants() do 
        if gunPart:IsA("Model") then
            table.insert(gunPieces, gunPart)
        end
    end
    for _, slot in assemblyBench:GetDescendants() do
        if slot:IsA("BasePart") then
            table.insert(slots, slot)
        end
    end

    if #gunPieces == 0 then 
        warn("no gun parts foundd") 
    end

    if #slots == 0 then 
        warn("no gun part's slots were founded")
    end
end

collectObjects()

RunService.Heartbeat:Connect(function()
    if #gunPieces == 0 then return end

    for _, piece in ipairs(gunPieces) do
        for _, slot in ipairs(slots) do
            --pieces are Model so we use GetPivot
            local piecePos = piece:GetPivot().Position
            local pieceRot = piece:GetPivot().Rotation

            local slotPos = slot.Position
            
            if (piecePos - slotPos).Magnitude < SNAP_RADIUS then -- magnitude of vector from slotPos to piecePos
                local targetCframe = CFrame.new(slotPos) * pieceRot -- keeping the original rotation
                piece:PivotTo(targetCframe + Vector3.new(0, 2, 0)) -- slightly above slot to aboid overlapping
            end
        end

    
    end
end)