--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local GunModel = require(ReplicatedStorage.Shared.GunModel)

local Loadout = {}

function Loadout.give(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		backpack = Instance.new("Backpack")
		backpack.Parent = player
	end
	for _, child in backpack:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("WeaponSlot") then
			child:Destroy()
		end
	end
	for slot, definition in Weapons do
		local tool = Instance.new("Tool")
		tool.Name = definition.ModelName
		tool.ToolTip = definition.Name
		tool.TextureId = definition.Icon
		tool.CanBeDropped = false
		tool.Enabled = false -- Input is handled by Combat, not stock Tool activation.
		tool.Grip = definition.Grip
		tool:SetAttribute("WeaponSlot", slot)
		tool:SetAttribute("CatalogAssetId", definition.AssetId)
		if definition.Magazine then
			tool:SetAttribute("Ammo", definition.Magazine)
			tool:SetAttribute("Reloading", false)
		end

		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = definition.Size
		handle.CanCollide = false
		handle.CanTouch = false
		handle.CanQuery = false
		handle.Massless = true
		handle.Parent = tool
		if definition.Procedural then
			GunModel.build(handle, slot, false)
		else
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.FileMesh
			mesh.MeshId = definition.MeshId
			mesh.TextureId = definition.TextureId
			mesh.Scale = definition.Scale
			mesh.Parent = handle
		end
		tool.Parent = backpack
	end
end

function Loadout.equip(player: Player, slot: number)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not character or not humanoid or humanoid.Health <= 0 or not backpack then
		return
	end
	for _, container in { character, backpack } do
		for _, tool in container:GetChildren() do
			if tool:IsA("Tool") and tool:GetAttribute("WeaponSlot") == slot then
				humanoid:EquipTool(tool)
				player:SetAttribute("SelectedSlot", slot)
				return
			end
		end
	end
end

return Loadout
