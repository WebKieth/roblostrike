--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Style = require(ReplicatedStorage.Shared.PoliceStyle)
local GunModel = require(ReplicatedStorage.Shared.GunModel)

local Viewmodel = {}

local function part(name: string, size: Vector3, color: Color3, parent: Model): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Size = size
	result.Color = color
	result.Material = Enum.Material.SmoothPlastic
	result.Anchored = true
	result.CanCollide = false
	result.CanTouch = false
	result.CanQuery = false
	result.CastShadow = false
	if name ~= "Weapon" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = result
	end
	result.Parent = parent
	return result
end

-- Keep the wrist on the weapon, with the elbow tucked below/behind the camera.
-- Both endpoints share the weapon's bob instead of floating independently.
local function placeArm(arm: Part, glove: Part?, elbow: Vector3, wrist: Vector3)
	arm.Size = Vector3.new(0.45, (wrist - elbow).Magnitude, 0.45)
	arm.CFrame = CFrame.lookAt((elbow + wrist) * 0.5, wrist) * CFrame.Angles(math.pi / 2, 0, 0)
	if glove then
		glove.CFrame = arm.CFrame * CFrame.new(0, arm.Size.Y * 0.5 - 0.08, 0)
	end
end

function Viewmodel.start(player: Player, combat: any)
	local model: Model? = nil
	local weapon: Model? = nil
	local rightArm: Part? = nil
	local leftArm: Part? = nil
	local rightGlove: Part? = nil
	local leftGlove: Part? = nil
	local currentTool: Tool? = nil

	local function clear()
		if model then
			model:Destroy()
		end
		model, weapon, rightArm, leftArm = nil, nil, nil, nil
		rightGlove, leftGlove = nil, nil
		currentTool = nil
		combat.Muzzle = nil
	end
	player.CharacterRemoving:Connect(clear)

	RunService:BindToRenderStep("RobostrikeViewmodel", Enum.RenderPriority.Camera.Value + 2, function()
		local character = player.Character
		local camera = workspace.CurrentCamera
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local tool = if character then character:FindFirstChildOfClass("Tool") else nil
		local slot = if tool then tool:GetAttribute("WeaponSlot") else nil
		if not camera or not humanoid or humanoid.Health <= 0 or not tool or not slot then
			clear()
			return
		end
		local definition = Weapons[slot]
		if not definition then
			clear()
			return
		end
		if tool ~= currentTool or not model or model.Parent ~= camera then
			clear()
			local newModel = Instance.new("Model")
			newModel.Name = "FirstPersonArms"
			newModel.Parent = camera
			model = newModel
			currentTool = tool
			local weaponModel = Instance.new("Model")
			weaponModel.Name = definition.ModelName
			weaponModel.Parent = newModel
			local handle = part("Weapon", definition.Size, Color3.new(1, 1, 1), weaponModel)
			weaponModel.PrimaryPart = handle
			weapon = weaponModel
			if definition.Procedural then
				GunModel.build(handle, slot, true)
			else
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.FileMesh
				mesh.MeshId = definition.MeshId
				mesh.TextureId = definition.TextureId
				mesh.Scale = definition.ViewScale or definition.Scale
				mesh.Parent = handle
			end
			rightArm = part("RightSleeve", Vector3.new(0.55, 1.5, 0.55), Style.Uniform, newModel)
			rightGlove = part("RightGlove", Vector3.new(0.4, 0.48, 0.4), Style.Leather, newModel)
			if definition.LeftHand then
				leftArm = part("LeftSleeve", Vector3.new(0.55, 1.5, 0.55), Style.Uniform, newModel)
				leftGlove = part("LeftGlove", Vector3.new(0.4, 0.48, 0.4), Style.Leather, newModel)
			end
		end
		-- Hide only the local world weapon. Other players still see the real Tool.
		for _, descendant in tool:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = 1
			end
		end
		local moving = humanoid.MoveDirection.Magnitude > 0.05
		local bob = if moving then math.sin(os.clock() * humanoid.WalkSpeed * 0.55) * 0.025 else 0
		local base = camera.CFrame * CFrame.new(0, bob, 0)
		local weaponFrame = base * definition.View
		if definition.FireInterval then
			-- Sight line, sway, recoil and HUD all use Combat's one aim frame.
			local aim = combat.Aim
			local translation = definition.View.Position:Lerp(definition.ADS.Position, combat.ADS)
			local position = aim:PointToWorldSpace(translation)
			local filter = RaycastParams.new()
			filter.FilterDescendantsInstances = { character :: Model, camera }
			filter.IgnoreWater = true
			local result = workspace:Raycast(aim.Position, aim.LookVector * definition.Range, filter)
			local target = if result then result.Position else aim.Position + aim.LookVector * definition.Range
			if (target - aim.Position).Magnitude < 3 then
				target = aim.Position + aim.LookVector * 50
			end
			local sightOrigin = position + aim.UpVector * definition.SightHeight
			local rotation = CFrame.lookAt(sightOrigin, target, aim.UpVector).Rotation
			weaponFrame = CFrame.new(position) * rotation
			-- Rearward slide stays on the sight line instead of tilting the
			-- gun away from the reticle independently of ballistic recoil.
			weaponFrame *= CFrame.new(0, 0, combat.Kick * 0.07)
			if tool:GetAttribute("Reloading") then
				weaponFrame *= CFrame.new(0.15, -0.35, 0.15) * CFrame.Angles(0, 0, math.rad(-25))
			end
			combat.Muzzle = weaponFrame:PointToWorldSpace(definition.Muzzle)
		end
		if weapon then
			weapon:PivotTo(weaponFrame)
		end
		if rightArm then
			placeArm(rightArm, rightGlove, base:PointToWorldSpace(Vector3.new(1, -1.65, 0.15)),
				weaponFrame:PointToWorldSpace(definition.RightHand))
		end
		if leftArm and definition.LeftHand then
			placeArm(leftArm, leftGlove, base:PointToWorldSpace(Vector3.new(-0.25, -1.65, 0.1)),
				weaponFrame:PointToWorldSpace(definition.LeftHand))
		end
	end)
end

return Viewmodel
