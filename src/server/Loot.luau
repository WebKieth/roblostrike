--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Survival = require(ReplicatedStorage.Shared.Survival)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Loadout = require(script.Parent.Loadout)

local Loot = {}
local resetRound: (() -> ())? = nil
local activeMap: Instance? = nil
local dropBotInventory: ((Model) -> ())? = nil

function Loot.dropBot(model: Model)
	if dropBotInventory then dropBotInventory(model) end
end

function Loot.setMap(map: Instance)
	activeMap = map
	Loot.reset()
end

function Loot.reset()
	if resetRound then resetRound() end
end

type Item = {
	visual: Model, position: Vector3, velocity: Vector3?, tool: Tool?, helmet: boolean?,
	spawnAt: Vector3?, readyAt: number?,
	slot: number?, armor: number?,
}

local function armorVisual(helmet: boolean): Model
	local model = Instance.new("Model")
	local vest = Instance.new("Part")
	vest.Name = "Vest"
	vest.Size = Vector3.new(1.6, 0.4, 1.5)
	vest.Color = Color3.fromRGB(45, 69, 85)
	vest.Parent = model
	model.PrimaryPart = vest
	if helmet then
		local shell = Instance.new("Part")
		shell.Name = "Helmet"
		shell.Shape = Enum.PartType.Ball
		shell.Size = Vector3.new(0.9, 0.65, 0.9)
		shell.CFrame = CFrame.new(0, 0.45, 0)
		shell.Color = vest.Color
		shell.Parent = model
	end
	return model
end

function Loot.start(remotes: Folder, map: Instance?)
	activeMap = map
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "Loot", workspace
	-- Real Tools never enter Workspace, so stock touch-pickup cannot bypass slots.
	local storage = Instance.new("Folder")
	storage.Name, storage.Parent = "LootTools", ServerStorage
	local drop = Instance.new("RemoteEvent")
	drop.Name, drop.Parent = "DropWeapon", remotes
	local items: { Item } = {}
	local lastDrop: { [Player]: number } = {}

	local function add(position: Vector3, tool: Tool?, helmet: boolean?, spawnAt: Vector3?, armor: number?): Item
		local visual: Model
		if tool then
			tool.Parent = storage
			visual = Instance.new("Model")
			local handle = (tool:FindFirstChild("Handle") :: BasePart):Clone()
			handle.Parent = visual
			visual.PrimaryPart = handle
		else
			visual = armorVisual(helmet == true)
		end
		visual.Name = if tool then tool.Name else if helmet then "Броня + каска" else "Бронежилет"
		for _, part in visual:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			end
		end
		local label = Instance.new("BillboardGui")
		label.Size = UDim2.fromOffset(150, 28)
		label.StudsOffset = Vector3.new(0, 1.1, 0)
		label.MaxDistance = 28
		label.Parent = visual.PrimaryPart
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextColor3 = Color3.fromRGB(225, 240, 255)
		text.TextStrokeTransparency = 0.3
		text.TextSize = 14
		text.Text = visual.Name
		text.Parent = label
		visual:PivotTo(CFrame.new(position))
		visual.Parent = folder
		local item: Item = {visual = visual, position = position, tool = tool, helmet = helmet, spawnAt = spawnAt,
			slot = if tool then tool:GetAttribute("WeaponSlot") else nil, armor = if tool then nil else armor or Survival.MaxArmor}
		table.insert(items, item)
		return item
	end

	dropBotInventory = function(model: Model)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not model:GetAttribute("Bot") or not humanoid or humanoid.Health > 0 or not root then return end
		local index = 0
		for _, tool in model:GetChildren() do
			if not tool:IsA("Tool") then continue end
			local slot = tool:GetAttribute("WeaponSlot")
			local definition = if typeof(slot) == "number" then Weapons[slot] else nil
			if not definition then continue end
			local primary = (definition.HotbarSlot or slot) == 1
			if not primary and not (definition.Grenade and (tool:GetAttribute("Ammo") or 0) > 0) then continue end
			tool:SetAttribute("Reloading", false)
			tool:SetAttribute("Primed", false)
			local item = add(root.Position, tool, nil, nil)
			local angle = index * 2.4
			item.velocity = Vector3.new(math.cos(angle) * 4, 3, math.sin(angle) * 4)
			index += 1
		end
	end

	resetRound = function()
		-- Clear hidden cooldown visuals as well as dropped items and stored Tools.
		for _, item in items do item.visual:Destroy() end
		table.clear(items)
		storage:ClearAllChildren()
		table.clear(lastDrop)
		local markers = if activeMap then activeMap:FindFirstChild("LootSpawns") else nil
		if markers then
			for _, marker in markers:GetChildren() do
				if not marker:IsA("BasePart") then continue end
				local weapon = marker:FindFirstChild("WeaponId") :: IntValue?
				local position = marker.Position + Vector3.new(0, 0.6, 0)
				add(position, if weapon then Loadout.create(weapon.Value) else nil, false, position)
			end
			return
		end
		-- Both tiled spawn rooms. Each pickup owns its own cooldown, not the room.
		for _, z in { -10, -65 } do
			for index, x in { -25, -18, -10, 3 } do
				local position = Vector3.new(x, 0.6, z)
				add(position, if index <= 2 then Loadout.create(index) else nil, index == 4, position)
			end
			for index, x in { -25, -18, -10 } do
				local position = Vector3.new(x, 0.6, z + (if z == -10 then 4 else -4))
				add(position, Loadout.create(index + 5), nil, position)
			end
		end
	end
	Loot.reset()

	drop.OnServerEvent:Connect(function(player: Player)
		if player:GetAttribute("SessionBlocked") or player:GetAttribute("TeamMenuOpen") then return end
		local now = os.clock()
		if now - (lastDrop[player] or -math.huge) < 0.25 then return end
		lastDrop[player] = now
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		local tool = if character then character:FindFirstChildOfClass("Tool") else nil
		local slot = if tool then tool:GetAttribute("WeaponSlot") else nil
		local definition = if typeof(slot) == "number" then Weapons[slot] else nil
		if not character or not humanoid or humanoid.Health <= 0 or not root or not tool or not definition or not definition.Magazine then return end
		character:SetAttribute("DroppedSlot" .. (definition.HotbarSlot or slot), true)
		tool:SetAttribute("Reloading", false)
		local forward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if forward.Magnitude < 0.001 then forward = Vector3.new(0, 0, -1) end
		local item = add(root.Position - Vector3.new(0, 0.5, 0), tool, nil, nil)
		local up = 5
		local flightTime = (up + math.sqrt(up * up + 2 * workspace.Gravity * 2)) / workspace.Gravity
		item.velocity = forward.Unit * (Survival.DropDistance / flightTime) + Vector3.new(0, up, 0)
	end)

	Players.PlayerRemoving:Connect(function(player) lastDrop[player] = nil end)
	RunService.Heartbeat:Connect(function(dt)
		local exclusions: { Instance } = { folder }
		local actors = workspace:FindFirstChild("SessionActors")
		if actors then table.insert(exclusions, actors) end
		for _, player in Players:GetPlayers() do
			if player.Character then table.insert(exclusions, player.Character) end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclusions
		params.RespectCanCollide = true
		local now = os.clock()
		for index = #items, 1, -1 do
			local item = items[index]
			if item.readyAt then
				if now >= item.readyAt then
					add(item.spawnAt :: Vector3, if item.slot then Loadout.create(item.slot) else nil,
						item.helmet, item.spawnAt)
					item.visual:Destroy()
					table.remove(items, index)
				end
				continue
			end
			if item.velocity then
				-- Swept volume + substeps: no tunnelling through walls on a slow frame.
				local remaining = math.min(dt, 0.25)
				while remaining > 0 and item.velocity do
					local step = math.min(remaining, 1 / 60)
					remaining -= step
					local gravity = Vector3.new(0, -workspace.Gravity, 0)
					local delta = item.velocity * step + gravity * (step * step / 2)
					local hit = if delta.Magnitude > 0.00001 then workspace:Spherecast(item.position, 0.55, delta, params) else nil
					item.velocity += gravity * step
					if hit then
						item.position += delta.Unit * hit.Distance + hit.Normal * 0.02
						if hit.Normal.Y > 0.5 then
							item.velocity = nil
						else
							-- A wall kills the forward throw; gravity drops it straight down.
							item.velocity = Vector3.new(0, math.min(0, item.velocity.Y), 0)
						end
					else
						item.position += delta
					end
				end
				item.visual:PivotTo(CFrame.new(item.position))
			end
			if item.position.Y < workspace.FallenPartsDestroyHeight then
				if item.tool then item.tool:Destroy() end
				item.visual:Destroy()
				table.remove(items, index)
				continue
			end
			if item.velocity then continue end -- No reclaiming a throw before it lands.
			for _, player in Players:GetPlayers() do
				local state = ReplicatedStorage:FindFirstChild("SessionState")
				local phase = if state then state:GetAttribute("Phase") else nil
				if not player:GetAttribute("InSession") or (phase ~= "Combat" and phase ~= "Freeze") then continue end
				local character = player.Character
				local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
				local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
				if not character or not humanoid or humanoid.Health <= 0 or not root then continue end
				if (root.Position - item.position).Magnitude > Survival.PickupRadius then continue end
				if workspace:Raycast(root.Position, item.position - root.Position, params) then continue end
				if item.tool then
					local slot = item.tool:GetAttribute("WeaponSlot")
					local definition = Weapons[slot]
					local hotbarSlot = if definition.Grenade then 4 else definition.HotbarSlot or slot
					local existing = Loadout.find(player, slot)
					if existing then
						if definition.Grenade then
							local ammo = existing:GetAttribute("Ammo") or 0
							local available = item.tool:GetAttribute("Ammo") or 0
							local transfer = math.min(definition.Count - ammo, available)
							if transfer <= 0 then continue end
							existing:SetAttribute("Ammo", ammo + transfer)
							if transfer < available then
								item.tool:SetAttribute("Ammo", available - transfer)
								continue
							end
						else
							local reserve = existing:GetAttribute("ReserveAmmo") or 0
							local available = (item.tool:GetAttribute("Ammo") or 0) + (item.tool:GetAttribute("ReserveAmmo") or 0)
							local transfer = math.min(definition.Magazine * Survival.SpareMagazines - reserve, available)
							if transfer <= 0 then continue end
							existing:SetAttribute("ReserveAmmo", reserve + transfer)
						end
						item.tool:Destroy()
					else
						if not definition.Grenade and Loadout.findHotbar(player, hotbarSlot) then continue end
						local backpack = player:FindFirstChildOfClass("Backpack")
						if not backpack then continue end
						character:SetAttribute("DroppedSlot" .. hotbarSlot, false)
						item.tool.Parent = backpack
						if player:GetAttribute("SelectedSlot") == hotbarSlot then Loadout.equip(player, hotbarSlot) end
					end
				else
					local armor = character:GetAttribute("Armor") or 0
					local helmet = character:GetAttribute("Helmet") == true
					local available = item.armor or Survival.MaxArmor
					if item.helmet and not helmet then
						-- Upgrading replaces the kit, leaving its actual remaining durability.
						if armor > 0 then add(item.position + Vector3.new(1, 0, 0), nil, false, nil, armor) end
						character:SetAttribute("Armor", available)
						character:SetAttribute("Helmet", true)
					else
						local transfer = math.min(Survival.MaxArmor - armor, available)
						if transfer <= 0 then continue end
						character:SetAttribute("Armor", armor + transfer)
						-- Refilling from a vest must not remove an already owned helmet.
					end
				end
				item.visual.Parent = nil
				if item.spawnAt then
					item.readyAt = now + Survival.LootRespawn
				else
					item.visual:Destroy()
					table.remove(items, index)
				end
				break
			end
		end
	end)
end

return Loot
