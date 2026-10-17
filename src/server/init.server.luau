--!strict

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Never let Roblox's automatic placement lift a character above the room roof.
Players.CharacterAutoLoads = false

local Config = require(ReplicatedStorage.Shared.Config)
local Loadout = require(script.Loadout)
local movement = require(script.Movement)
local PoliceSkin = require(script.PoliceSkin)
local Survival = require(ReplicatedStorage.Shared.Survival)
local SessionRules = require(ReplicatedStorage.Shared.SessionRules)
local CharacterCollision = require(script.CharacterCollision)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local equip = Instance.new("RemoteEvent")
equip.Name = "EquipWeapon"
equip.Parent = remotes
local stance = Instance.new("RemoteEvent")
stance.Name = "SetMovement"
stance.Parent = remotes
require(script.Combat).start(remotes)
require(script.Knife).start(remotes)
require(script.Grenades).start(remotes)

PhysicsService:RegisterCollisionGroup("Characters")
PhysicsService:CollisionGroupSetCollidable("Characters", "Characters", false)

local map = workspace:WaitForChild("FyPoolDay")
for _, descendant in map:GetDescendants() do
	if descendant:IsA("SpawnLocation") then
		descendant.Enabled = false
		descendant.Transparency = 1
		descendant.CanCollide = false
		descendant.CanQuery = false
	end
end

require(script.Loot).start(remotes)

local roomSpawn = Instance.new("SpawnLocation")
roomSpawn.Name = "BlueRoomRespawn"
roomSpawn.Size = Vector3.new(3, 0.1, 3)
roomSpawn.CFrame = CFrame.new(Config.SpawnCFrame.Position.X, 0.08, Config.SpawnCFrame.Position.Z)
roomSpawn.Anchored = true
roomSpawn.CanCollide = false
roomSpawn.CanTouch = false
roomSpawn.CanQuery = false
roomSpawn.Transparency = 1
roomSpawn.Neutral = true
roomSpawn.Duration = 0
roomSpawn.Parent = workspace

local spawning: { [Player]: boolean } = {}
local lastEquip: { [Player]: number } = {}
local pendingEquip: { [Player]: number } = {}

local function spawnCharacter(player: Player, spawnAt: CFrame): Model?
	if spawning[player] or player.Parent ~= Players then
		return
	end
	spawning[player] = true
	local description = PoliceSkin.description()
	local success, result = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)
	end)
	description:Destroy()
	if not success then
		spawning[player] = nil
		warn("[Robostrike] Character creation failed: " .. tostring(result))
		return
	end
	local character = result :: Model
	if player.Parent ~= Players then
		character:Destroy()
		spawning[player] = nil
		return
	end
	local oldCharacter = player.Character
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate:Destroy() -- Client/CharacterAnimation supplies the stock R6 tracks.
	end
	character.Name = player.Name
	PoliceSkin.apply(character)
	root.Anchored = true
	-- Exact root placement BEFORE entering Workspace; no MoveTo/ceiling raycasts.
	character:PivotTo(spawnAt * root.CFrame:Inverse() * character:GetPivot())
	CharacterCollision.apply(character)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		Instance.new("Animator", humanoid)
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.MaxHealth = Survival.MaxHealth
	humanoid.Health = Survival.MaxHealth
	character:SetAttribute("Armor", 0)
	character:SetAttribute("Helmet", false)
	humanoid.WalkSpeed = Config.RunSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 35
	player:SetAttribute("SelectedSlot", 1)
	character.Parent = workspace
	player.Character = character
	if oldCharacter then
		oldCharacter:Destroy()
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = false
	root:SetNetworkOwner(player)
	movement.add(player, character)
	Loadout.give(player)
	Loadout.equip(player, 1)
	spawning[player] = nil
	humanoid.Died:Once(function()
		movement.remove(player)
	end)
	return character
end

equip.OnServerEvent:Connect(function(player: Player, slot: any)
	if SessionRules.blocked(player) then return end
	if typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > 4 then
		return
	end
	-- Keep the newest request instead of dropping it when network packets bunch
	-- together. Remote spam cannot create more than one pending equip per player.
	pendingEquip[player] = slot
end)

stance.OnServerEvent:Connect(function(player: Player, walking: any, crouching: any)
	if typeof(walking) == "boolean" and typeof(crouching) == "boolean" then
		movement.set(player, walking, crouching)
	end
end)
RunService.Heartbeat:Connect(function(dt)
	movement.step(dt)
	local now = os.clock()
	for player, slot in pendingEquip do
		if SessionRules.blocked(player) then pendingEquip[player] = nil; continue end
		if now - (lastEquip[player] or 0) >= 0.06 then
			pendingEquip[player] = nil
			lastEquip[player] = now
			Loadout.equip(player, slot)
		end
	end
end)

local function onPlayerAdded(player: Player)
	player.RespawnLocation = roomSpawn
	Loadout.watch(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	movement.remove(player)
	lastEquip[player] = nil
	pendingEquip[player] = nil
	spawning[player] = nil
end)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

require(script.Session).start(remotes, spawnCharacter)

print(string.format("[%s] Server ready — v%s", Config.GameName, Config.Version))
