--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Style = require(ReplicatedStorage.Shared.PoliceStyle)
local Config = require(ReplicatedStorage.Shared.Config)

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
function PoliceSkin.apply(character: Model, teamId: string?)
	local terrorist = teamId == "Red"
	local uniform = if terrorist then Style.TerroristUniform else Style.Uniform
	local trousers = if terrorist then Color3.fromRGB(109, 112, 81) else Style.Uniform
	local outfit = Instance.new("Model")
	outfit.Name = if terrorist then "PhoenixUniform" else "PoliceUniform"
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
	piece("Shirt", torso, Vector3.new(2.05, 2.15, 1.05), CFrame.identity, uniform, terrorist)
	piece("BodyArmor", torso, Vector3.new(1.85, 1.65, 1.18), CFrame.new(0, 0.07, 0), Style.Vest, terrorist)
	if not terrorist then
		for _, x in { -0.49, 0.49 } do
			piece("ChestPlate", torso, Vector3.new(0.9, 0.92, 0.16), CFrame.new(x, 0.23, -0.64), Style.ArmorPlate)
			piece("PlateRim", torso, Vector3.new(0.9, 0.055, 0.04), CFrame.new(x, 0.69, -0.74), Style.ArmorEdge)
			piece("ShoulderStrap", torso, Vector3.new(0.27, 0.18, 1.15), CFrame.new(x * 1.4, 0.93, 0), Style.Leather)
		end
		local chest = piece("PoliceChestPatch", torso, Vector3.new(0.8, 0.24, 0.06), CFrame.new(0.43, 0.4, -0.75), Style.Vest)
		label(chest, Enum.NormalId.Front, "POLICE", Style.Silver)
		local back = piece("PoliceBackPatch", torso, Vector3.new(1.25, 0.38, 0.06), CFrame.new(0, 0.35, 0.57), Style.Vest)
		label(back, Enum.NormalId.Back, "POLICE", Style.Silver)
		local badge = piece("UnitBadge", torso, Vector3.new(0.36, 0.4, 0.06), CFrame.new(-0.49, 0.38, -0.75), Style.Leather)
		label(badge, Enum.NormalId.Front, "◆", Style.Silver)
	else
		piece("JacketZip", torso, Vector3.new(0.055, 1.65, 0.06), CFrame.new(0, 0, -0.53), Style.Leather)
		for _, x in { -0.55, 0.55 } do
			piece("JacketPocket", torso, Vector3.new(0.43, 0.36, 0.12), CFrame.new(x, 0.25, -0.48), Color3.fromRGB(91, 61, 43))
		end
	end
	for _, x in { -0.65, 0.65 } do
		piece("VestStrap", torso, Vector3.new(0.24, 0.62, 0.12), CFrame.new(x, 0.65, -0.43), Style.Leather)
		piece("AmmoPouch", torso, Vector3.new(0.38, 0.42, 0.2), CFrame.new(x * 0.55, -0.25, -0.57), Style.Leather)
	end
	local radio = piece("Radio", torso, Vector3.new(0.27, 0.4, 0.2), CFrame.new(-0.65, 0.01, -0.57), Style.Leather)
	piece("RadioAntenna", torso, Vector3.new(0.045, 0.36, 0.045), CFrame.new(-0.73, 0.37, -0.58), Style.Leather)
	label(radio, Enum.NormalId.Front, "•••", Style.Silver)
	piece("DutyBelt", torso, Vector3.new(1.85, 0.23, 1.08), CFrame.new(0, -0.78, 0), Style.Leather)
	piece("BeltBuckle", torso, Vector3.new(0.27, 0.18, 0.09), CFrame.new(0, -0.78, -0.58), Style.Silver)
	piece("Holster", torso, Vector3.new(0.3, 0.68, 0.45), CFrame.new(1, -0.92, 0), Style.Leather, terrorist)
	piece("UtilityPouch", torso, Vector3.new(0.3, 0.4, 0.42), CFrame.new(-1, -0.79, 0), Style.Leather, terrorist)

	for _, side in { "Left", "Right" } do
		local arm = character:WaitForChild(side .. " Arm") :: BasePart
		local leg = character:WaitForChild(side .. " Leg") :: BasePart
		arm.Transparency = 1
		leg.Transparency = 1
		piece(side .. "Sleeve", arm, Vector3.new(0.84, 1.8, 0.85), CFrame.new(0, 0.16, 0), uniform, terrorist)
		piece(side .. "Cuff", arm, Vector3.new(0.65, 0.25, 0.68), CFrame.new(0, -0.59, 0), Style.Leather, terrorist)
		piece(side .. "Glove", arm, Vector3.new(0.66, 0.57, 0.72), CFrame.new(0, -0.8, 0), Style.Leather, terrorist)
		piece(side .. "Trousers", leg, Vector3.new(0.88, 1.9, 0.9), CFrame.new(0, 0.12, 0), trousers, terrorist)
		if terrorist then
			for i, y in { -0.45, 0.15, 0.65 } do
				piece(side .. "CamoPatch", leg, Vector3.new(0.52, 0.24, 0.07), CFrame.new(if i % 2 == 0 then -0.14 else 0.14, y, -0.43) * CFrame.Angles(0, 0, 0.35 * i), Color3.fromRGB(61, 68, 47), true)
			end
		end
		piece(side .. "KneePad", leg, Vector3.new(0.57, 0.53, 0.2), CFrame.new(0, -0.05, -0.41), Style.Vest, terrorist)
		piece(side .. "Boot", leg, Vector3.new(0.85, 0.7, 1.07), CFrame.new(0, -0.68, -0.1), Style.Leather, terrorist)
		piece(side .. "Sole", leg, Vector3.new(0.79, 0.14, 1), CFrame.new(0, -0.94, -0.11), Style.Leather)
		if not terrorist then
			piece(side .. "ShoulderArmor", arm, Vector3.new(0.98, 0.66, 1.02), CFrame.new(0, 0.64, 0) * CFrame.Angles(0, 0, if side == "Left" then -0.08 else 0.08), Style.ArmorPlate)
			piece(side .. "ForearmArmor", arm, Vector3.new(0.87, 0.64, 0.16), CFrame.new(0, -0.27, -0.46), Style.ArmorPlate)
			local patch = piece(side .. "ShoulderPatch", arm, Vector3.new(0.06, 0.34, 0.36), CFrame.new(if side == "Left" then -0.51 else 0.51, 0.58, 0), Style.Leather)
			label(patch, if side == "Left" then Enum.NormalId.Left else Enum.NormalId.Right, "◆", Style.Silver)
			patch.CastShadow = false
		end
	end

	-- Keep the R6 head/camera attachment; only the visible headwear changes.
	if terrorist then
		-- Original geometry inspired by the classic Phoenix silhouette, not a catalog skin.
		head.Transparency = 1
		for _, child in head:GetChildren() do
			if child:IsA("Decal") then child.Transparency = 1 end
		end
		piece("Balaclava", head, Vector3.new(1.3, 1.2, 1.22), CFrame.identity, Style.Leather, true)
		piece("EyeOpening", head, Vector3.new(0.92, 0.23, 0.08), CFrame.new(0, 0.17, -0.58), Style.Skin, true)
		for _, x in { -0.23, 0.23 } do
			piece("Eye", head, Vector3.new(0.1, 0.09, 0.04), CFrame.new(x, 0.17, -0.63), Style.Leather, true)
		end
		piece("MaskNose", head, Vector3.new(0.22, 0.22, 0.15), CFrame.new(0, 0.04, -0.6), Style.Leather, true)
	else
		head.Transparency = 1
		for _, child in head:GetChildren() do
			if child:IsA("Decal") then child.Transparency = 1 end
		end
		piece("TacticalHood", head, Vector3.new(1.32, 1.16, 1.22), CFrame.identity, Style.Leather)
		piece("FaceOpening", head, Vector3.new(1.16, 0.43, 0.08), CFrame.new(0, 0.06, -0.63), Style.Skin)
		for _, x in { -0.24, 0.24 } do
			piece("Eye", head, Vector3.new(0.09, 0.2, 0.04), CFrame.new(x, 0.06, -0.69), Style.Leather, true)
		end
		piece("FaceGuard", head, Vector3.new(1.3, 0.48, 0.22), CFrame.new(0, -0.36, -0.6), Style.Leather)
		piece("TacticalHelmet", head, Vector3.new(1.49, 0.62, 1.44), CFrame.new(0, 0.56, 0), Style.ArmorPlate)
		piece("HelmetStripe", head, Vector3.new(0.22, 0.025, 1.46), CFrame.new(0, 0.88, 0), Style.ArmorEdge)
		piece("GoggleStrap", head, Vector3.new(1.54, 0.2, 1.47), CFrame.new(0, 0.4, 0), Style.Leather)
		piece("GoggleFrame", head, Vector3.new(1.39, 0.46, 0.17), CFrame.new(0, 0.42, -0.78), Style.Leather)
		piece("GoggleLens", head, Vector3.new(1.19, 0.31, 0.05), CFrame.new(0, 0.43, -0.88), Style.Visor)
		piece("GoggleHighlight", head, Vector3.new(0.035, 0.24, 0.015), CFrame.new(-0.46, 0.44, -0.91) * CFrame.Angles(0, 0, -0.2), Style.ArmorEdge)
		for _, x in { -0.72, 0.72 } do
			piece("HelmetEarGuard", head, Vector3.new(0.16, 0.56, 0.6), CFrame.new(x, 0.02, 0), Style.ArmorPlate)
		end
	end
	local helmet = piece("ArmorHelmet", head, Vector3.new(1.55, 0.85, 1.5), CFrame.new(0, 0.42, 0), Style.Vest, true)
	local armorParts = { BodyArmor = true, PoliceChestPatch = true, PoliceBackPatch = true, VestStrap = true, AmmoPouch = true }
	local function updateArmor()
		local armored = (character:GetAttribute("Armor") or 0) > 0
		local helmeted = armored and character:GetAttribute("Helmet") == true
		for _, part in outfit:GetChildren() do
			if not part:IsA("BasePart") then continue end
			-- Blue tactical plates are cosmetic, not a grant of gameplay armor.
			if armorParts[part.Name] then part.Transparency = if armored or not terrorist then 0 else 1 end
			if string.sub(part.Name, 1, 3) == "Cap" then part.Transparency = if helmeted then 1 else 0 end
			for _, child in part:GetChildren() do
				if child:IsA("SurfaceGui") and armorParts[part.Name] then child.Enabled = armored or not terrorist end
			end
		end
		helmet.Transparency = if helmeted and terrorist then 0 else 1
	end
	character:GetAttributeChangedSignal("Armor"):Connect(updateArmor)
	character:GetAttributeChangedSignal("Helmet"):Connect(updateArmor)
	updateArmor()
	-- Scale the complete R6 rig, joints and uniform together for players and bots.
	character:ScaleTo(Config.CharacterScale)
	character:SetAttribute("CharacterScale", Config.CharacterScale)
end

return PoliceSkin
