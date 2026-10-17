--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Weapons = require(ReplicatedStorage.Shared.Weapons)

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
	result.Parent = parent
	return result
end

-- Keep the wrist on the weapon, with the elbow tucked below/behind the camera.
-- Both endpoints share the weapon's bob instead of floating independently.
local function placeArm(arm: Part, elbow: Vector3, wrist: Vector3)
	arm.Size = Vector3.new(0.45, (wrist - elbow).Magnitude, 0.45)
	arm.CFrame = CFrame.lookAt((elbow + wrist) * 0.5, wrist) * CFrame.Angles(math.pi / 2, 0, 0)
end

function Viewmodel.start(player: Player)
	local model: Model? = nil
	local weapon: Part? = nil
	local rightArm: Part? = nil
	local leftArm: Part? = nil
	local currentTool: Tool? = nil

	local function clear()
		if model then
			model:Destroy()
		end
		model, weapon, rightArm, leftArm = nil, nil, nil, nil
		currentTool = nil
	end
	player.CharacterRemoving:Connect(clear)

	RunService:BindToRenderStep("RobostrikeViewmodel", Enum.RenderPriority.Camera.Value + 1, function()
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
			weapon = part("Weapon", definition.Size, Color3.new(1, 1, 1), newModel)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.FileMesh
			mesh.MeshId = definition.MeshId
			mesh.TextureId = definition.TextureId
			mesh.Scale = definition.ViewScale or definition.Scale
			mesh.Parent = weapon
			local skin = Color3.fromRGB(245, 205, 48)
			rightArm = part("RightArm", Vector3.new(0.55, 1.5, 0.55), skin, newModel)
			if definition.LeftHand then
				leftArm = part("LeftArm", Vector3.new(0.55, 1.5, 0.55), skin, newModel)
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
		if weapon then
			weapon.CFrame = weaponFrame
		end
		if rightArm then
			placeArm(rightArm, base:PointToWorldSpace(Vector3.new(1, -1.65, 0.15)),
				weaponFrame:PointToWorldSpace(definition.RightHand))
		end
		if leftArm and definition.LeftHand then
			placeArm(leftArm, base:PointToWorldSpace(Vector3.new(-0.25, -1.65, 0.1)),
				weaponFrame:PointToWorldSpace(definition.LeftHand))
		end
	end)
end

return Viewmodel
