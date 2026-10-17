--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Style = require(ReplicatedStorage.Shared.PoliceStyle)

local PoliceSkin = {}

function PoliceSkin.description(): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = Style.Skin
	description.LeftArmColor = Style.Uniform
	description.RightArmColor = Style.Uniform
	description.TorsoColor = Style.Uniform
	description.LeftLegColor = Style.Uniform
	description.RightLegColor = Style.Uniform
	return description
end

-- Cosmetic shells follow the stock R6 joints; movement and collision dimensions
-- stay unchanged. No catalog clothing or privately owned meshes are required.
function PoliceSkin.apply(character: Model)
	local outfit = Instance.new("Model")
	outfit.Name = "PoliceUniform"
	outfit.Parent = character

	local function piece(name: string, limb: BasePart, size: Vector3, offset: CFrame, color: Color3, rounded: boolean?): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CFrame = limb.CFrame * offset
		if rounded then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = limb
		weld.Part1 = part
		weld.Parent = part
		part.Parent = outfit
		return part
	end

	local function label(part: BasePart, face: Enum.NormalId, text: string, color: Color3)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(400, 160)
		gui.LightInfluence = 1
		gui.Parent = part
		local caption = Instance.new("TextLabel")
		caption.Size = UDim2.fromScale(1, 1)
		caption.BackgroundTransparency = 1
		caption.Text = text
		caption.TextColor3 = color
		caption.TextScaled = true
		caption.Font = Enum.Font.GothamBold
		caption.Parent = gui
	end

	local torso = character:WaitForChild("Torso") :: BasePart
	local head = character:WaitForChild("Head") :: BasePart
	torso.Transparency = 1
	piece("Shirt", torso, Vector3.new(2.05, 2.15, 1.05), CFrame.identity, Style.Uniform, true)
	piece("BodyArmor", torso, Vector3.new(1.85, 1.65, 1.18), CFrame.new(0, 0.07, 0), Style.Vest, true)
	local chest = piece("PoliceChestPatch", torso, Vector3.new(1.05, 0.3, 0.06), CFrame.new(0.18, 0.35, -0.57), Style.Vest)
	label(chest, Enum.NormalId.Front, "POLICE", Style.Silver)
	local back = piece("PoliceBackPatch", torso, Vector3.new(1.25, 0.38, 0.06), CFrame.new(0, 0.35, 0.57), Style.Vest)
	label(back, Enum.NormalId.Back, "POLICE", Style.Silver)
	piece("Badge", torso, Vector3.new(0.22, 0.29, 0.08), CFrame.new(-0.58, 0.38, -0.55), Style.Gold, true)
	for _, x in { -0.65, 0.65 } do
		piece("VestStrap", torso, Vector3.new(0.24, 0.62, 0.12), CFrame.new(x, 0.65, -0.43), Style.Leather)
		piece("AmmoPouch", torso, Vector3.new(0.38, 0.42, 0.2), CFrame.new(x * 0.55, -0.25, -0.57), Style.Leather)
	end
	local radio = piece("Radio", torso, Vector3.new(0.27, 0.4, 0.2), CFrame.new(-0.65, 0.01, -0.57), Style.Leather)
	piece("RadioAntenna", torso, Vector3.new(0.045, 0.36, 0.045), CFrame.new(-0.73, 0.37, -0.58), Style.Leather)
	label(radio, Enum.NormalId.Front, "•••", Style.Silver)
	piece("DutyBelt", torso, Vector3.new(1.85, 0.23, 1.08), CFrame.new(0, -0.78, 0), Style.Leather)
	piece("BeltBuckle", torso, Vector3.new(0.27, 0.18, 0.09), CFrame.new(0, -0.78, -0.58), Style.Silver)
	piece("Holster", torso, Vector3.new(0.3, 0.68, 0.45), CFrame.new(1, -0.92, 0), Style.Leather, true)
	piece("UtilityPouch", torso, Vector3.new(0.3, 0.4, 0.42), CFrame.new(-1, -0.79, 0), Style.Leather, true)

	for _, side in { "Left", "Right" } do
		local arm = character:WaitForChild(side .. " Arm") :: BasePart
		local leg = character:WaitForChild(side .. " Leg") :: BasePart
		arm.Transparency = 1
		leg.Transparency = 1
		piece(side .. "Sleeve", arm, Vector3.new(0.84, 1.8, 0.85), CFrame.new(0, 0.16, 0), Style.Uniform, true)
		piece(side .. "Cuff", arm, Vector3.new(0.65, 0.25, 0.68), CFrame.new(0, -0.59, 0), Style.Leather, true)
		piece(side .. "Glove", arm, Vector3.new(0.66, 0.57, 0.72), CFrame.new(0, -0.8, 0), Style.Leather, true)
		piece(side .. "Trousers", leg, Vector3.new(0.88, 1.9, 0.9), CFrame.new(0, 0.12, 0), Style.Uniform, true)
		piece(side .. "KneePad", leg, Vector3.new(0.57, 0.53, 0.2), CFrame.new(0, -0.05, -0.41), Style.Vest, true)
		piece(side .. "Boot", leg, Vector3.new(0.85, 0.7, 1.07), CFrame.new(0, -0.68, -0.1), Style.Leather, true)
		piece(side .. "Sole", leg, Vector3.new(0.79, 0.14, 1), CFrame.new(0, -0.94, -0.11), Style.Leather)
		local patch = piece(side .. "ShoulderPatch", arm, Vector3.new(0.08, 0.34, 0.31), CFrame.new(if side == "Left" then -0.4 else 0.4, 0.58, 0), Style.Gold, true)
		patch.CastShadow = false
	end

	-- The stock head mesh and face remain; a shaped crown and visor replace
	-- the bare noob silhouette without changing the camera's head attachment.
	piece("CapCrown", head, Vector3.new(1.35, 0.54, 1.28), CFrame.new(0, 0.55, 0), Style.Uniform, true)
	piece("CapBand", head, Vector3.new(1.22, 0.18, 1.14), CFrame.new(0, 0.39, 0), Style.Leather, true)
	piece("CapVisor", head, Vector3.new(1.25, 0.12, 0.86), CFrame.new(0, 0.34, -0.53), Style.Leather, true)
	piece("CapBadge", head, Vector3.new(0.23, 0.27, 0.08), CFrame.new(0, 0.53, -0.61), Style.Gold, true)
	local helmet = piece("ArmorHelmet", head, Vector3.new(1.55, 0.85, 1.5), CFrame.new(0, 0.42, 0), Style.Vest, true)
	local armorParts = { BodyArmor = true, PoliceChestPatch = true, PoliceBackPatch = true, VestStrap = true, AmmoPouch = true }
	local function updateArmor()
		local armored = (character:GetAttribute("Armor") or 0) > 0
		local helmeted = armored and character:GetAttribute("Helmet") == true
		for _, part in outfit:GetChildren() do
			if not part:IsA("BasePart") then continue end
			if armorParts[part.Name] then part.Transparency = if armored then 0 else 1 end
			if string.sub(part.Name, 1, 3) == "Cap" then part.Transparency = if helmeted then 1 else 0 end
			for _, child in part:GetChildren() do
				if child:IsA("SurfaceGui") and armorParts[part.Name] then child.Enabled = armored end
			end
		end
		helmet.Transparency = if helmeted then 0 else 1
	end
	character:GetAttributeChangedSignal("Armor"):Connect(updateArmor)
	character:GetAttributeChangedSignal("Helmet"):Connect(updateArmor)
	updateArmor()
end

return PoliceSkin
