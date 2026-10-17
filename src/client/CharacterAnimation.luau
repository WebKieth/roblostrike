--!strict

-- Standard Roblox R6 animations; manual character spawning does not depend
-- on an avatar's Animate script or personal animation packs.
local RunService = game:GetService("RunService")

local CharacterAnimation = {}

function CharacterAnimation.start(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator
	local tracks: { [string]: AnimationTrack } = {}
	local ids = {
		idle = "rbxassetid://180435571",
		walk = "rbxassetid://180426354",
		jump = "rbxassetid://125750702",
		fall = "rbxassetid://180436148",
		tool = "rbxassetid://182393478",
	}
	for name, id in ids do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local track = animator:LoadAnimation(animation)
		track.Priority = if name == "tool" then Enum.AnimationPriority.Action else Enum.AnimationPriority.Movement
		track.Looped = name ~= "jump"
		tracks[name] = track
		animation:Destroy()
	end
	local current = ""
	local holding = false
	local connection: RBXScriptConnection? = nil
	local function stop()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		for _, track in tracks do
			track:Stop(0)
			track:Destroy()
		end
	end
	connection = RunService.Heartbeat:Connect(function()
		if humanoid.Health <= 0 or not character.Parent then
			stop()
			return
		end
		local state = humanoid:GetState()
		local equipped = character:FindFirstChildOfClass("Tool") ~= nil
		if equipped ~= holding then
			holding = equipped
			if equipped then tracks.tool:Play(0.15) else tracks.tool:Stop(0.15) end
		end
		local name = if character:GetAttribute("InWater") then "idle"
			elseif state == Enum.HumanoidStateType.Jumping then "jump"
			elseif state == Enum.HumanoidStateType.Freefall then "fall"
			elseif humanoid.MoveDirection.Magnitude > 0.05 then "walk" else "idle"
		if current ~= name then
			if tracks[current] then
				tracks[current]:Stop(0.15)
			end
			tracks[name]:Play(0.15)
			current = name
		end
		if name == "walk" then
			tracks.walk:AdjustSpeed(humanoid.WalkSpeed / 14.5)
		end
	end)
end

return CharacterAnimation
