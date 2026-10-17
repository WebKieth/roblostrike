--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Ballistics = require(ReplicatedStorage.Shared.Ballistics)
local Survival = require(ReplicatedStorage.Shared.Survival)
local Rules = require(ReplicatedStorage.Shared.SessionRules)
local Combat = {}

function Combat.feedback(event: RemoteEvent, source: Model?, position: Vector3, damage: number)
	-- Damage numbers belong to the attacker, never to other clients or bot AI.
	local attacker = if source then Players:GetPlayerFromCharacter(source) else nil
	if attacker then event:FireClient(attacker, position, damage) end
end

-- Shared by bullets and knife contacts: identical zones, armor wear and feedback.
function Combat.damage(hit: RaycastResult, multiplier: number?, damageNumbers: RemoteEvent, source: Model?): Humanoid?
	local ancestor: Instance? = hit.Instance
	local victim: Humanoid? = nil
	while ancestor and ancestor ~= workspace do
		if ancestor:IsA("Model") then
			victim = ancestor:FindFirstChildOfClass("Humanoid")
			if victim then break end
		end
		ancestor = ancestor.Parent
	end
	if victim and victim.Health > 0 then
		local body = victim.Parent :: Model
		if Rules.friendly(source, body) then return nil end
		local damage, armor = Survival.damage(hit.Instance.Name,
			body:GetAttribute("Armor") or 0, body:GetAttribute("Helmet") == true, multiplier)
		body:SetAttribute("Armor", armor)
		if armor == 0 then body:SetAttribute("Helmet", false) end
		if not body:GetAttribute("Immortal") then victim:TakeDamage(damage) end
		local head = body:FindFirstChild("Head") :: BasePart?
		Combat.feedback(damageNumbers, source, if head then head.Position else hit.Position, damage)
	end
	return victim
end

local function finiteVector(value: any): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < 1e6 and math.abs(value.Y) < 1e6 and math.abs(value.Z) < 1e6
end

function Combat.start(remotes: Folder)
	local function remote(name: string): RemoteEvent
		local event = Instance.new("RemoteEvent")
		event.Name, event.Parent = name, remotes
		return event
	end
	local fire = remote("FireShot")
	local reload = remote("ReloadWeapon")
	local effects = remote("ShotEffect")
	local damageNumbers = remote("DamageNumber")
	local nextShot: { [Player]: number } = {}
	local lastRequest: { [Player]: number } = {}
	local reloadTokens: { [Tool]: number } = setmetatable({}, { __mode = "k" }) :: any

	local function equipped(player: Player): (Model?, Tool?, any)
		if Rules.blocked(player) then return nil, nil, nil end
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local tool = if character then character:FindFirstChildOfClass("Tool") else nil
		local slot = if tool then tool:GetAttribute("WeaponSlot") else nil
		local definition = if typeof(slot) == "number" then Weapons[slot] else nil
		if not character or not humanoid or humanoid.Health <= 0 or not tool or not definition or not definition.FireInterval then
			return nil, nil, nil
		end
		return character, tool, definition
	end

	fire.OnServerEvent:Connect(function(player: Player, muzzleOffset: any, direction: any)
		local now = os.clock()
		-- Cheap flood guard before raycasts and ancestry work.
		if now - (lastRequest[player] or -math.huge) < 0.025 then
			return
		end
		lastRequest[player] = now
		if not finiteVector(muzzleOffset) or not finiteVector(direction) or math.abs(direction.Magnitude - 1) > 0.01 then
			return
		end
		local character, tool, definition = equipped(player)
		if not character or not tool then
			return
		end
		local head = character:FindFirstChild("Head") :: BasePart?
		local handle = tool:FindFirstChild("Handle") :: BasePart?
		if not head or not handle or muzzleOffset.Magnitude > Ballistics.MaxMuzzleOffset then
			return
		end
		local ammo = tool:GetAttribute("Ammo")
		if typeof(ammo) ~= "number" or ammo <= 0 or tool:GetAttribute("Reloading") then
			return
		end
		-- Carry scheduling debt instead of letting the jitter allowance increase RPM.
		local due = nextShot[player] or now
		if now < due - 0.025 then
			return
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		params.IgnoreWater = true
		nextShot[player] = math.max(now, due) + definition.FireInterval
		tool:SetAttribute("Ammo", ammo - 1)
		direction = direction.Unit
		-- The first-person barrel, not the independently animated world Tool.
		local muzzle = head.Position + muzzleOffset
		local obstruction = if muzzleOffset.Magnitude > 0.001
			then workspace:Raycast(head.Position, muzzle - head.Position, params) else nil
		local hit: RaycastResult? = nil
		if obstruction then
			muzzle = head.Position
			hit = obstruction
		else
			hit = workspace:Raycast(muzzle, direction * definition.Range, params)
		end
		local target = if hit then hit.Position else muzzle + direction * definition.Range
		local victim: Humanoid? = nil
		if hit then
			victim = Combat.damage(hit, definition.DamageMultiplier, damageNumbers, character)
		end
		local material = if hit then hit.Material else nil
		if hit and hit.Instance.Parent and hit.Instance.Parent.Name == "Water" then
			material = Enum.Material.Water -- Imported pool surfaces are Glass Parts.
		end
		effects:FireAllClients(player.UserId, tool:GetAttribute("WeaponSlot"), muzzle, target,
			if hit then hit.Normal else nil, material,
			if hit then hit.Instance else nil, victim ~= nil)
	end)

	reload.OnServerEvent:Connect(function(player: Player)
		local character, tool, definition = equipped(player)
		if not character or not tool or tool:GetAttribute("Reloading") or tool:GetAttribute("Ammo") == definition.Magazine
			or (tool:GetAttribute("ReserveAmmo") or 0) <= 0 then
			return
		end
		local token = (reloadTokens[tool] or 0) + 1
		reloadTokens[tool] = token
		tool:SetAttribute("Reloading", true)
		-- Switching weapons cancels rather than finishing a reload in the backpack.
		local connection: RBXScriptConnection? = nil
		connection = tool.AncestryChanged:Connect(function()
			if tool.Parent ~= character then
				reloadTokens[tool] = token + 1
				tool:SetAttribute("Reloading", false)
				if connection then connection:Disconnect() end
			end
		end)
		task.delay(definition.ReloadTime, function()
			if connection then connection:Disconnect() end
			if reloadTokens[tool] ~= token then return end
			tool:SetAttribute("Reloading", false)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if player.Character == character and humanoid and humanoid.Health > 0 and tool.Parent == character then
				local reserve = tool:GetAttribute("ReserveAmmo") or 0
				local transfer = math.min(definition.Magazine - (tool:GetAttribute("Ammo") or 0), reserve)
				tool:SetAttribute("ReserveAmmo", reserve - transfer)
				tool:SetAttribute("Ammo", (tool:GetAttribute("Ammo") or 0) + transfer)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		nextShot[player], lastRequest[player] = nil, nil
	end)
end

return Combat
