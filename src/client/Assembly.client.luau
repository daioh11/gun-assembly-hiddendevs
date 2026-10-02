local RunService = game:GetService("RunService")
local partsFolder = workspace:WaitForChild("GunParts") :: Folder

local assemblyBench = workspace:WaitForChild("AssemblyBench") :: BasePart --bench and all gun part slots

local gunParts = {}
local partSlots = {}

-- minimum trhreshold for gun part to snap to the gun part slot
local SNAP_RADIUS = 3 


-- collecting Model gun parts and BasePart slots across whoel workspace
local function gatherGunAssemblyData()
    for _, gunPart in partsFolder:GetDescendants() do
        if gunPart:IsA("Model") then
            table.insert(gunParts, gunPart)
        end
    end

    for _, slot in assemblyBench:GetDescendants() do
        if slot:IsA("BasePart") then
            table.insert(partSlots, slot)
        end
    end

    if next(gunParts) == nil then 
        warn("no gun parts foundd")
    end

    if next(partSlots) == nil then 
        warn("no gun part's slots were founded")
    end
end

gatherGunAssemblyData()

RunService.Heartbeat:Connect(function()
    if not gunParts then return end
    --TODO optimize it, maybe im gonna add dt fraction later
    for _, part in ipairs(gunParts) do
        for _, slot in ipairs(partSlots) do
            if (part:GetPivot().Position - slot.Position).Magnitude < SNAP_RADIUS then
                print("can snap")
            end
        end

    
    end
end)