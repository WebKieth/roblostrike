--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Rules = require(ReplicatedStorage.Shared.Knife)
local Combat = require(script.Parent.Combat)
local SessionRules = require(ReplicatedStorage.Shared.SessionRules)
local Knife = {}

local function validDirection(value: any): boolean
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.Magnitude - 1) < 0.01
end

function Knife.start(remotes: Folder)
	local action = Instance.new("RemoteEvent")
	action.Name, action.Parent = "KnifeAction", remotes
	local damageNumbers = remotes:WaitForChild("DamageNumber") :: RemoteEvent
	local attacks: { [Player]: any } = {}
	local cooldown: { [Player]: number } = {}
	local function equipped(player: Player): (Model?, Tool?)
		if SessionRules.blocked(player) then return nil, nil end
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local tool = if character then character:FindFirstChildOfClass("Tool") else nil
		local slot = if tool then tool:GetAttribute("WeaponSlot") else nil
		local definition = if typeof(slot) == "number" then Weapons[slot] else nil
		if humanoid and humanoid.Health > 0 and definition and definition.Knife then return character, tool end
		return nil, nil
	end
	local function cancel(player: Player)
		local attack = attacks[player]
		if attack then
			attack.Tool:SetAttribute("KnifeMode", nil)
			attack.Connection:Disconnect()
			attacks[player] = nil
		end
	end
	action.OnServerEvent:Connect(function(player: Player, mode: any, direction: any)
		if mode == "Cancel" then cancel(player); return end
		if not validDirection(direction) then return end
		local character, tool = equipped(player)
		if not character or not tool then return end
		local now = os.clock()
		if mode == "Aim" then
			local attack = attacks[player]
			if attack and now - attack.LastAim >= 0.025 then
				attack.Direction, attack.LastAim = direction.Unit, now
			end
			return
		end
		if mode ~= "Slash" and mode ~= "Stab" then return end
		if now < (cooldown[player] or 0) then return end
		cancel(player)
		local rules = Rules[mode]
		cooldown[player] = now + rules.Duration
		local attack: any = { Character = character, Tool = tool, Rules = rules, Mode = mode,
			Started = now, Direction = direction.Unit, LastAim = now, Hit = false }
		attack.Connection = tool.AncestryChanged:Connect(function()
			if tool.Parent ~= character then cancel(player) end
		end)
		attacks[player] = attack
		tool:SetAttribute("KnifeStarted", workspace:GetServerTimeNow())
		tool:SetAttribute("KnifeMode", mode)
	end)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player, attack in attacks do
			local character, tool = equipped(player)
			local age = now - attack.Started
			if not character or not tool or character ~= attack.Character or tool ~= attack.Tool or age >= attack.Rules.Duration then
				cancel(player)
				continue
			end
			if attack.Hit or not Rules.active(attack.Rules, age) then continue end
			local head = character:FindFirstChild("Head") :: BasePart?
			if not head then continue end
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { character }
			params.IgnoreWater = true
			local frame = CFrame.lookAt(head.Position, head.Position + attack.Direction)
			local yaw = if attack.Mode == "Slash" then math.rad(45 - 90 * Rules.stroke(attack.Rules, age)) else 0
			local direction = (frame * CFrame.Angles(0, yaw, 0)).LookVector
			-- Start inside the head so even touching cover blocks the blade.
			-- Reach is measured beyond the head's surface, not from its centre.
			local localDirection = head.CFrame:VectorToObjectSpace(direction)
			local half = head.Size * 0.5
			local surface = math.min(half.X / math.max(math.abs(localDirection.X), 1e-6),
				half.Y / math.max(math.abs(localDirection.Y), 1e-6), half.Z / math.max(math.abs(localDirection.Z), 1e-6))
			local hit = workspace:Raycast(head.Position, direction * (surface + attack.Rules.Reach), params)
			if hit then
				local victim = Combat.damage(hit, attack.Rules.DamageMultiplier, damageNumbers, character)
				if victim then attack.Hit = true end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		cancel(player)
		cooldown[player] = nil
	end)
end

return Knife
