--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Config = require(ReplicatedStorage.Shared.Config)
local SCALE = Config.ViewmodelScale
local Style = require(ReplicatedStorage.Shared.PoliceStyle)
local GunModel = require(ReplicatedStorage.Shared.GunModel)
local Effects = require(script.Parent.ShotEffects)
local WeaponAnimation = require(ReplicatedStorage.Shared.WeaponAnimation)
local WeaponParts = require(script.Parent.WeaponParts)

local Viewmodel = {}

local function part(name: string, size: Vector3, color: Color3, parent: Model, blocky: boolean?): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Size = size * (if name == "Weapon" then 1 else SCALE)
	result.Color = color
	result.Material = Enum.Material.SmoothPlastic
	result.Anchored = true
	result.CanCollide = false
	result.CanTouch = false
	result.CanQuery = false
	result.CastShadow = false
	if name ~= "Weapon" and not blocky then
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
	elbow = wrist + (elbow - wrist) * SCALE
	arm.Size = Vector3.new(0.45 * SCALE, (wrist - elbow).Magnitude, 0.45 * SCALE)
	arm.CFrame = CFrame.lookAt((elbow + wrist) * 0.5, wrist) * CFrame.Angles(math.pi / 2, 0, 0)
	if glove then
		glove.CFrame = arm.CFrame * CFrame.new(0, arm.Size.Y * 0.5 - 0.08 * SCALE, 0)
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
	local grenadePose: CFrame? = nil
	local animateParts: any = nil

	local function clear()
		Effects.clearMuzzle()
		if model then
			model:Destroy()
		end
		model, weapon, rightArm, leftArm = nil, nil, nil, nil
		rightGlove, leftGlove = nil, nil
		currentTool = nil
		grenadePose = nil
		animateParts = nil
		combat.Muzzle = nil
	end
	player.CharacterRemoving:Connect(clear)

	RunService:BindToRenderStep("RobostrikeViewmodel", Enum.RenderPriority.Camera.Value + 2, function(dt)
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
			weaponModel:ScaleTo(SCALE)
			animateParts = WeaponParts.bind(handle, SCALE)
			local uniform = if player:GetAttribute("TeamId") == "Red" then Style.TerroristUniform else Style.Uniform
			local blocky = player:GetAttribute("TeamId") ~= "Red"
			rightArm = part("RightSleeve", Vector3.new(0.55, 1.5, 0.55), uniform, newModel, blocky)
			rightGlove = part("RightGlove", Vector3.new(0.4, 0.48, 0.4), Style.Leather, newModel, blocky)
			if definition.LeftHand then
				leftArm = part("LeftSleeve", Vector3.new(0.55, 1.5, 0.55), uniform, newModel, blocky)
				leftGlove = part("LeftGlove", Vector3.new(0.4, 0.48, 0.4), Style.Leather, newModel, blocky)
			end
		end
		-- Hide only the local world weapon. Other players still see the real Tool.
		for _, descendant in tool:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = 1
			end
		end
		local moving = humanoid.MoveDirection.Magnitude > 0.05
		local bob = if moving then math.sin(os.clock() * humanoid.WalkSpeed * 0.55) * 0.075 else 0
		local base = camera.CFrame * CFrame.new(0, bob, 0)
		local weaponFrame = base * definition.View
		local now = workspace:GetServerTimeNow()
		local pose = WeaponAnimation.fromTool(tool, now, if tool == combat.ShotTool then now - combat.ShotTime else nil)
		if definition.Knife then
			local knifePose = combat.KnifePose or CFrame.identity
			weaponFrame *= CFrame.new(knifePose.Position * SCALE) * knifePose.Rotation
		end
		if definition.Grenade then
			local hip = tool:GetAttribute("GrenadeHip") == true
			local winding = tool:GetAttribute("GrenadeWinding") == true
			local pose = if winding then
				(if hip then CFrame.new(0.65, -1.15, -0.7) * CFrame.Angles(math.rad(-35), 0, 0)
				else CFrame.new(0.7, -0.35, -0.55) * CFrame.Angles(math.rad(65), 0, math.rad(-15)))
				else definition.View
			local smoothed = (grenadePose or definition.View):Lerp(pose, 1 - math.exp(-dt * 16))
			grenadePose = smoothed
			weaponFrame = base * smoothed
		end
		if definition.FireInterval then
			-- Combat already resolved cover, reticle and firing from this pose.
			weaponFrame = combat.WeaponFrame or weaponFrame
			combat.Muzzle = weaponFrame:PointToWorldSpace(definition.Muzzle * SCALE)
			Effects.updateMuzzle(combat.Muzzle, weaponFrame.LookVector)
		end
		if weapon then
			weapon:PivotTo(weaponFrame)
		end
		if animateParts then animateParts(pose, slot, SCALE) end
		if rightArm then
			placeArm(rightArm, rightGlove, base:PointToWorldSpace(Vector3.new(1, -1.65, 0.15)),
				weaponFrame:PointToWorldSpace((pose.RightHand or definition.RightHand) * SCALE))
		end
		if leftArm and definition.LeftHand then
			placeArm(leftArm, leftGlove, base:PointToWorldSpace(Vector3.new(-0.25, -1.65, 0.1)),
				weaponFrame:PointToWorldSpace((pose.LeftHand or definition.LeftHand) * SCALE))
		end
		if model then
			for _, child in model:GetDescendants() do
				if child:IsA("BasePart") then child.LocalTransparencyModifier = if combat.Scoped then 1 else 0 end
			end
		end
	end)
end

return Viewmodel
