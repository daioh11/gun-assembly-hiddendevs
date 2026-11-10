local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.AssemblyConfig)

local SnapAnimator = {}

-- one tween per Model gun piece
local activeTweens: { [Model]: Tween } = {}

function SnapAnimator.Cancel(piece: Model)
	local tween = activeTweens[piece]
	if tween then
		tween:Cancel() -- also fires Completed
	end
end

function SnapAnimator.Play(piece: Model, target: CFrame)
	SnapAnimator.Cancel(piece)

	-- using cframevalue for gun piece position tweening (primary part method is laggy)
	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = piece:GetPivot()
	local connection = cframeValue.Changed:Connect(function(newValue: CFrame)
		piece:PivotTo(newValue)
	end)

	local tweenInfo = TweenInfo.new(Config.SnapTime, Enum.EasingStyle.Quad)
	local tween = TweenService:Create(cframeValue, tweenInfo, { Value = target })
    --saving tween for piece
	activeTweens[piece] = tween

	tween.Completed:Connect(function() --cleanup
		connection:Disconnect()
		cframeValue:Destroy()
		--only clear if its still ours
		if activeTweens[piece] == tween then
			activeTweens[piece] = nil
		end
	end)

	tween:Play()
end

return SnapAnimator