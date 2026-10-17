--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Combat = {}

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
	local nextShot: { [Player]: number } = {}
	local lastRequest: { [Player]: number } = {}
	local reloadTokens: { [Tool]: number } = setmetatable({}, { __mode = "k" }) :: any

	local function equipped(player: Player): (Model?, Tool?, any)
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

	fire.OnServerEvent:Connect(function(player: Player, origin: any, direction: any)
		local now = os.clock()
		-- Cheap flood guard before raycasts and ancestry work.
		if now - (lastRequest[player] or -math.huge) < 0.025 then
			return
		end
		lastRequest[player] = now
		if not finiteVector(origin) or not finiteVector(direction) or math.abs(direction.Magnitude - 1) > 0.01 then
			return
		end
		local character, tool, definition = equipped(player)
		if not character or not tool then
			return
		end
		local head = character:FindFirstChild("Head") :: BasePart?
		local handle = tool:FindFirstChild("Handle") :: BasePart?
		if not head or not handle or (origin - head.Position).Magnitude > 2.5 then
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
		local offset = origin - head.Position
		if offset.Magnitude > 0.01 and workspace:Raycast(head.Position, offset, params) then
			return -- A camera position behind a wall must never shoot through it.
		end
		nextShot[player] = math.max(now, due) + definition.FireInterval
		tool:SetAttribute("Ammo", ammo - 1)
		direction = direction.Unit
		-- The camera ray is exactly the displayed reticle, never a random cone.
		local hit = workspace:Raycast(origin, direction * definition.Range, params)
		local target = if hit then hit.Position else origin + direction * definition.Range
		local muzzle = handle.CFrame:PointToWorldSpace(definition.Muzzle)
		-- Occluded barrels/nearby cover take priority over the screen-space target.
		-- Start at the head too, so a model clipped THROUGH a wall cannot bypass it.
		local obstruction = workspace:Raycast(head.Position, muzzle - head.Position, params)
		if obstruction then
			muzzle = head.Position
			hit = obstruction
		else
			local path = target - muzzle
			if path.Magnitude > 0.001 then
				local barrelHit = workspace:Raycast(muzzle, path.Unit * (path.Magnitude + 0.02), params)
				if barrelHit then
					hit = barrelHit
				end
			end
		end
		target = if hit then hit.Position else target
		local victim: Humanoid? = nil
		if hit then
			local ancestor: Instance? = hit.Instance
			while ancestor and ancestor ~= workspace do
				if ancestor:IsA("Model") then
					victim = ancestor:FindFirstChildOfClass("Humanoid")
					if victim then break end
				end
				ancestor = ancestor.Parent
			end
			if victim and victim.Health > 0 then
				victim:TakeDamage(definition.Damage * (if hit.Instance.Name == "Head" then 2 else 1))
			end
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
		if not character or not tool or tool:GetAttribute("Reloading") or tool:GetAttribute("Ammo") == definition.Magazine then
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
				tool:SetAttribute("Ammo", definition.Magazine)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		nextShot[player], lastRequest[player] = nil, nil
	end)
end

return Combat
