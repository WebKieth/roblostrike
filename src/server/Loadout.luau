--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local GunModel = require(ReplicatedStorage.Shared.GunModel)
local Survival = require(ReplicatedStorage.Shared.Survival)

local Loadout = {}
export type Snapshot = {
	armor: number,
	helmet: boolean,
	selected: number,
	weapons: { [number]: { Ammo: number?, ReserveAmmo: number? } },
}

function Loadout.capture(player: Player): Snapshot
	local character = player.Character
	local snapshot: Snapshot = {
		armor = if character then character:GetAttribute("Armor") or 0 else 0,
		helmet = character ~= nil and character:GetAttribute("Helmet") == true,
		selected = player:GetAttribute("SelectedSlot") or 1,
		weapons = {},
	}
	for slot in Weapons do
		local tool = Loadout.find(player, slot)
		if tool then
			snapshot.weapons[slot] = { Ammo = tool:GetAttribute("Ammo"), ReserveAmmo = tool:GetAttribute("ReserveAmmo") }
		end
	end
	return snapshot
end

function Loadout.restore(player: Player, snapshot: Snapshot)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not character or not backpack then return end
	for _, container in { character, backpack } do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("WeaponSlot") then child:Destroy() end
		end
	end
	character:SetAttribute("Armor", snapshot.armor)
	character:SetAttribute("Helmet", snapshot.helmet)
	-- Prevent Backpack repair from replenishing deliberately missing weapons/grenades.
	for slot, definition in Weapons do
		character:SetAttribute("DroppedSlot" .. slot, snapshot.weapons[slot] == nil)
		if definition.HotbarSlot then
			character:SetAttribute("DroppedSlot" .. definition.HotbarSlot, true)
		end
	end
	for slot, attributes in snapshot.weapons do
		local tool = Loadout.create(slot)
		for name, value in attributes do tool:SetAttribute(name, value) end
		tool.Parent = backpack
	end
	Loadout.equip(player, snapshot.selected)
end

function Loadout.create(slot: number): Tool
	local definition = Weapons[slot]
	local tool = Instance.new("Tool")
	tool.Name = definition.ModelName
	tool.ToolTip = definition.Name
	tool.TextureId = definition.Icon
	tool.CanBeDropped = false
	tool.Enabled = false
	tool.Grip = definition.Grip
	tool:SetAttribute("WeaponSlot", slot)
	tool:SetAttribute("CatalogAssetId", definition.AssetId)
	if definition.Grenade then
		tool:SetAttribute("Ammo", definition.Count)
		tool:SetAttribute("Primed", false)
	end
	if definition.Magazine then
		tool:SetAttribute("Ammo", definition.Magazine)
		tool:SetAttribute("ReserveAmmo", definition.Magazine * Survival.SpareMagazines)
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
	return tool
end

function Loadout.find(player: Player, slot: number): Tool?
	for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("WeaponSlot") == slot then return child end
			end
		end
	end
	return nil
end

-- Concrete weapon IDs remain stable; several models occupy hotbar slot 1.
function Loadout.findHotbar(player: Player, hotbarSlot: number): Tool?
	for slot, definition in Weapons do
		if (definition.HotbarSlot or slot) == hotbarSlot then
			local tool = Loadout.find(player, slot)
			if tool then return tool end
		end
	end
	return nil
end

function Loadout.give(player: Player, preserveExisting: boolean?): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		-- Manual CharacterAutoLoads=false spawning may need this fallback.
		-- watch() repairs the loadout if Roblox subsequently replaces it.
		backpack = Instance.new("Backpack")
		backpack.Parent = player
	end
	if not preserveExisting then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("WeaponSlot") then
				child:Destroy()
			end
		end
	end
	for slot, definition in Weapons do
		if definition.PickupOnly then continue end
		if player.Character and player.Character:GetAttribute("DroppedSlot" .. slot) then continue end
		if definition.HotbarSlot and Loadout.findHotbar(player, definition.HotbarSlot) then continue end
		local existing = false
		for _, container in { player.Character, backpack } do
			if container then
				for _, child in container:GetChildren() do
					if child:IsA("Tool") and child:GetAttribute("WeaponSlot") == slot then
						existing = true
						break
					end
				end
			end
		end
		if existing then continue end
		local tool = Loadout.create(slot)
		tool.Parent = backpack
	end
	return true
end

function Loadout.equip(player: Player, slot: number)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	player:SetAttribute("SelectedSlot", slot)
	-- Both grenade definitions share hotbar key 4; WeaponSlot identifies the
	-- concrete Tool internally. Repeated key 4 cycles without adding a fifth key.
	local targetSlot = slot
	if slot == 1 then
		local primary = Loadout.findHotbar(player, 1)
		if primary then targetSlot = primary:GetAttribute("WeaponSlot") end
	end
	if slot == 4 then
		local current = character:FindFirstChildOfClass("Tool")
		local currentSlot = if current then current:GetAttribute("WeaponSlot") else nil
		targetSlot = if currentSlot == 4 then 5 else 4
	end
	for _, container in { character, backpack } do
		for _, tool in container:GetChildren() do
			if tool:IsA("Tool") and tool:GetAttribute("WeaponSlot") == targetSlot then
				if tool.Parent ~= character then humanoid:EquipTool(tool) end
				player:SetAttribute("SelectedSlot", slot)
				return
			end
		end
	end
	humanoid:UnequipTools()
end

function Loadout.watch(player: Player)
	-- Character assignment and the engine's Backpack creation are not atomic.
	-- Repair the real container when it arrives, including after every respawn.
	player.ChildAdded:Connect(function(child)
		if not child:IsA("Backpack") then return end
		task.defer(function()
			if child.Parent ~= player then return end
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if not humanoid or humanoid.Health <= 0 then return end
			if Loadout.give(player, true) then
				Loadout.equip(player, player:GetAttribute("SelectedSlot") or 1)
			end
		end)
	end)
end

return Loadout
