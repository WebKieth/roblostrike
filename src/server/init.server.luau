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

local spawnCharacter: (Player) -> ()
spawnCharacter = function(player: Player)
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
		task.delay(Config.RespawnDelay, spawnCharacter, player)
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
	character:PivotTo(Config.SpawnCFrame * root.CFrame:Inverse() * character:GetPivot())
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Characters"
		end
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		Instance.new("Animator", humanoid)
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
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
		task.delay(Config.RespawnDelay, spawnCharacter, player)
	end)
end

equip.OnServerEvent:Connect(function(player: Player, slot: any)
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
		if now - (lastEquip[player] or 0) >= 0.06 then
			pendingEquip[player] = nil
			lastEquip[player] = now
			Loadout.equip(player, slot)
		end
	end
end)

local function onPlayerAdded(player: Player)
	player.RespawnLocation = roomSpawn
	task.spawn(spawnCharacter, player)
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

print(string.format("[%s] Server ready — v%s", Config.GameName, Config.Version))
