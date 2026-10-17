--!strict

-- Pose each rig on every observer: Motor6D.Transform does not replicate.
-- No uploaded animation assets, and no MoveDirection dependency for remote rigs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local CharacterAnimation = {}
local active: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

function CharacterAnimation.start(character: Model)
	if active[character] then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("Torso")
	if not humanoid or not root or not root:IsA("BasePart") or not torso or not torso:IsA("BasePart") then return end
	local joints: { [string]: Motor6D } = {}
	for _, child in torso:GetChildren() do
		if child:IsA("Motor6D") then joints[child.Name] = child end
	end
	active[character] = true
	local phase = 0
	local speed = 0
	local connection: RBXScriptConnection? = nil
	local function stop()
		if connection then connection:Disconnect(); connection = nil end
		for _, joint in joints do joint.Transform = CFrame.identity end
		active[character] = nil
	end
	local function rotate(name: string, pitch: number, roll: number)
		local joint = joints[name]
		if not joint then return end
		-- R6 hips have opposing local axes; rotate in torso space instead.
		local basis = joint.C0.Rotation
		joint.Transform = basis:Inverse() * CFrame.Angles(pitch, 0, roll) * basis
	end
	local function armFrame(joint: Motor6D, wrist: Vector3): CFrame
		local shoulder = joint.C0.Position
		local direction = (wrist - shoulder).Unit
		local length = if joint.Part1 then joint.Part1.Size.Y else 2 * character:GetScale()
		local center = wrist - direction * length * 0.5
		return CFrame.lookAt(center, center + direction) * CFrame.Angles(math.pi / 2, 0, 0)
	end
	connection = RunService.PreSimulation:Connect(function(dt: number)
		if humanoid.Health <= 0 or not character.Parent then stop(); return end
		local velocity = root.AssemblyLinearVelocity
		local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air and not character:GetAttribute("InWater")
		local targetSpeed = if grounded then horizontal.Magnitude else 0
		speed += (targetSpeed - speed) * (1 - math.exp(-14 * dt))
		phase += speed * dt / character:GetScale() * 0.65
		local crouched = character:GetAttribute("Crouching") == true
		local stride = math.sin(phase) * math.clamp(speed / 14, 0, 1) * (if crouched then 0.3 else 0.7)
		local direction = torso.CFrame:VectorToObjectSpace(horizontal)
		local forward = if horizontal.Magnitude > 0.1 then -direction.Z / horizontal.Magnitude else 1
		local sideways = if horizontal.Magnitude > 0.1 then direction.X / horizontal.Magnitude else 0
		rotate("Left Hip", stride * forward, stride * sideways)
		rotate("Right Hip", -stride * forward, -stride * sideways)
		rotate("Left Shoulder", -stride * 0.6, -0.06)
		rotate("Right Shoulder", stride * 0.6, 0.06)

		local tool = character:FindFirstChildOfClass("Tool")
		local slot = if tool then tool:GetAttribute("WeaponSlot") else nil
		local definition = if typeof(slot) == "number" then Weapons[slot] else nil
		local right = joints["Right Shoulder"]
		local left = joints["Left Shoulder"]
		if tool and right and right.Part1 then
			local scale = character:GetScale()
			local wrist = right.C0.Position + Vector3.new(-0.5, -0.5, -0.7).Unit * right.Part1.Size.Y
			local frame = armFrame(right, wrist)
			right.Transform = right.C0:Inverse() * frame * right.C1
			local grip = right.Part1:FindFirstChild("RightGrip")
			if definition and definition.Procedural and left and grip
				and (grip:IsA("Motor6D") or grip:IsA("Weld")) then
				-- Aim the HANDLE in torso space, not along the sloping rigid R6 arm.
				-- GunModel's bore is -Z. Both hands then follow this level weapon.
				local weaponFrame = CFrame.new(Vector3.new(0.7, 0.65, -1.25) * scale)
				local trigger = definition.RightHand or Vector3.new(0, -0.4, 0.3)
				frame = armFrame(right, weaponFrame:PointToWorldSpace(trigger * scale))
				right.Transform = right.C0:Inverse() * frame * right.C1
				grip.C0 = frame:Inverse() * weaponFrame * grip.C1
				local anchor = definition.LeftHand or Vector3.new(-0.2, -0.4, 0.3)
				local support = weaponFrame:PointToWorldSpace(anchor * scale)
				left.Transform = left.C0:Inverse() * armFrame(left, support) * left.C1
			end
		end
	end)
end

return CharacterAnimation
