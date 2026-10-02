local camera = workspace.CurrentCamera
local pivot = workspace:WaitForChild("Pivot") :: BasePart

local function setupCamera()
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = pivot.CFrame
end

setupCamera()