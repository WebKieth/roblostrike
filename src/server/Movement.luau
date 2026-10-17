--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

type State = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	walking: boolean,
	wantsCrouch: boolean,
	crouching: boolean,
	hipHeight: number,
	hips: { [Motor6D]: CFrame },
	filter: OverlapParams,
}
local states: { [Player]: State } = {}
local Movement = {}

function Movement.add(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local hips: { [Motor6D]: CFrame } = {}
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") and (joint.Name == "Left Hip" or joint.Name == "Right Hip") then
			hips[joint] = joint.C0
		end
	end
	local filter = OverlapParams.new()
	filter.FilterType = Enum.RaycastFilterType.Exclude
	filter.FilterDescendantsInstances = { character }
	filter.RespectCanCollide = true
	filter.CollisionGroup = "Characters"
	states[player] = {
		character = character,
		humanoid = humanoid,
		root = character.HumanoidRootPart :: BasePart,
		walking = false,
		wantsCrouch = false,
		crouching = false,
		hipHeight = humanoid.HipHeight,
		hips = hips,
		filter = filter,
	}
	character:SetAttribute("Crouching", false)
end

function Movement.remove(player: Player)
	states[player] = nil
end

function Movement.set(player: Player, walking: boolean, crouching: boolean)
	local state = states[player]
	if state then
		state.walking = walking
		state.wantsCrouch = crouching
	end
end

local function canStand(state: State): boolean
	-- R6 head top is root+2. Check only the extra space needed to stand,
	-- not the floor/legs; stay crouched under a low ceiling until it is clear.
	local center = state.root.CFrame * CFrame.new(0, 2 + Config.CrouchDepth / 2 + 0.025, 0)
	return #workspace:GetPartBoundsInBox(center, Vector3.new(1.9, Config.CrouchDepth, 1.9), state.filter) == 0
end

function Movement.step(_dt: number)
	for _, state in states do
		local humanoid = state.humanoid
		if humanoid.Health <= 0 or not state.character.Parent then
			continue
		end
		local crouching = state.wantsCrouch or (state.crouching and not canStand(state))
		if crouching ~= state.crouching then
			state.crouching = crouching
			humanoid.HipHeight = state.hipHeight - (if crouching then Config.CrouchDepth else 0)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not crouching)
			for joint, original in state.hips do
				-- Bend both classic R6 legs; C0 replication makes the pose visible to others.
				local sign = if joint.Name == "Left Hip" then -1 else 1
				joint.C0 = if crouching
					then original * CFrame.Angles(0, 0, math.rad(50) * sign)
					else original
			end
			state.character:SetAttribute("Crouching", crouching)
		end
		humanoid.WalkSpeed = if crouching then Config.CrouchSpeed
			elseif state.walking then Config.WalkSpeed else Config.RunSpeed
	end
end

return Movement
