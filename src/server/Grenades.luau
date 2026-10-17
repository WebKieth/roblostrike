--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Rules = require(ReplicatedStorage.Shared.Grenades)
local SessionRules = require(ReplicatedStorage.Shared.SessionRules)
local Combat = require(script.Parent.Combat)

local Grenades = {}

local function finiteDirection(value: any): boolean
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.Magnitude - 1) < 0.01
end

function Grenades.start(remotes: Folder)
	local action = Instance.new("RemoteEvent")
	action.Name, action.Parent = "GrenadeAction", remotes
	local effects = Instance.new("RemoteEvent")
	effects.Name, effects.Parent = "GrenadeExplosion", remotes
	local damageNumbers = remotes:WaitForChild("DamageNumber") :: RemoteEvent
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "ThrownGrenades", workspace
	local primed: { [Player]: any } = {}
	local projectiles: { any } = {}
	local lastAim: { [Player]: number } = {}
	local nextPrime: { [Player]: number } = {}

	local function params(exclude: { Instance }): RaycastParams
		local result = RaycastParams.new()
		result.FilterDescendantsInstances = exclude
		result.IgnoreWater = true
		return result
	end

	local function cancel(player: Player)
		local held = primed[player]
		if held then
			if held.Connection then held.Connection:Disconnect() end
			held.Tool:SetAttribute("Primed", false)
		end
		primed[player] = nil
	end

	local function explode(position: Vector3, owner: Model)
		-- Resolve ALL visibility before applying damage: the first body remains
		-- a shield for this explosion even if this same blast kills it.
		local victims = {}
		local filter = params({ folder }) -- Never exclude the thrower or other bodies.
		for _, descendant in workspace:GetDescendants() do
			if not descendant:IsA("Humanoid") or descendant.Health <= 0 then continue end
			local body = descendant.Parent
			if body and body ~= owner and SessionRules.friendly(owner, body :: Model) then continue end
			local root = if body then body:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			if not root then continue end
			local delta = root.Position - position
			local damage = Rules.damage(delta.Magnitude)
			if damage <= 0 then continue end
			local hit = if delta.Magnitude > 0.001 then workspace:Raycast(position, delta, filter) else nil
			if not hit or hit.Instance:IsDescendantOf(body) then
				table.insert(victims, { Humanoid = descendant, Body = body, Position = root.Position, Damage = damage })
			end
		end
		for _, victim in victims do
			-- Grenade HP damage is linear and does not use firearm zone/armor rules.
			local health = victim.Humanoid.Health
			if not victim.Body:GetAttribute("Immortal") then victim.Humanoid:TakeDamage(victim.Damage) end
			if victim.Humanoid.Health < health then Combat.incoming(victim.Body, position, false) end
			Combat.feedback(damageNumbers, owner, victim.Position, victim.Damage)
		end
		effects:FireAllClients(position)
	end

	local function consume(held: any)
		held.Tool:SetAttribute("Ammo", math.max(0, (held.Tool:GetAttribute("Ammo") or 0) - 1))
	end

	local function handContact(held: any, position: Vector3): RaycastResult?
		local filter = params({ held.Character, folder })
		local head = held.Character:FindFirstChild("Head") :: BasePart?
		if not head then return nil end
		local reach = position - head.Position
		local contact = if reach.Magnitude > 0.001
			then workspace:Spherecast(head.Position, Rules.Radius, reach, filter) else nil
		if contact then return contact end
		local travel = position - held.LastHand
		if travel.Magnitude > 0.001 then
			return workspace:Spherecast(held.LastHand, Rules.Radius, travel, filter)
		end
		return nil
	end

	local function handOverlaps(held: any, position: Vector3): boolean
		-- Swept casts do not report initial overlaps, including a quick click
		-- released before the first Heartbeat has checked the primed hand.
		local overlap = OverlapParams.new()
		overlap.FilterDescendantsInstances = { held.Character, folder }
		return #workspace:GetPartBoundsInRadius(position, Rules.Radius, overlap) > 0
	end

	action.OnServerEvent:Connect(function(player: Player, command: any, direction: any, hip: any)
		if command == "Cancel" then cancel(player); return end
		if SessionRules.blocked(player) then cancel(player); return end
		if command ~= "Prime" and command ~= "Aim" and command ~= "Throw" then return end
		if not finiteDirection(direction) or typeof(hip) ~= "boolean" then return end
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local tool = if character then character:FindFirstChildOfClass("Tool") else nil
		local head = if character then character:FindFirstChild("Head") :: BasePart? else nil
		local slot = if tool then tool:GetAttribute("WeaponSlot") else nil
		local definition = if typeof(slot) == "number" then Weapons[slot] else nil
		if not character or not humanoid or humanoid.Health <= 0 or not head or not tool
			or not definition or not definition.Grenade or (tool:GetAttribute("Ammo") or 0) <= 0 then
			cancel(player)
			return
		end
		local now = os.clock()
		if command == "Prime" then
			if primed[player] or now < (nextPrime[player] or 0) then return end
			nextPrime[player] = now + 0.35
			primed[player] = { Tool = tool, Character = character, Definition = definition,
				Direction = direction, Hip = hip, LastHand = head.Position }
			primed[player].Connection = tool.AncestryChanged:Connect(function()
				if tool.Parent ~= character then cancel(player) end
			end)
			tool:SetAttribute("Primed", true)
		else
			local held = primed[player]
			if not held or held.Tool ~= tool or held.Character ~= character then cancel(player); return end
			if command == "Aim" and now - (lastAim[player] or -math.huge) < 0.05 then return end
			lastAim[player] = now
			held.Direction, held.Hip = direction, hip
			if command == "Throw" then
				local origin = Rules.hand(CFrame.lookAt(head.Position, head.Position + direction), hip)
				local cover = handContact(held, origin)
				consume(held)
				cancel(player)
				if definition.Grenade == "Impact" and (cover or handOverlaps(held, origin)) then
					explode(if cover then cover.Position + cover.Normal * (Rules.Radius + 0.02) else origin, character)
					return
				end
				if cover then origin = cover.Position + cover.Normal * (Rules.Radius + 0.02) end
				local part = Instance.new("Part")
				part.Name = definition.ModelName
				part.Size = Vector3.one * Rules.Radius * 2
				part.Anchored = true
				part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
				part.Color = if definition.Grenade == "Impact" then Color3.fromRGB(134, 76, 40) else Color3.fromRGB(68, 83, 43)
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType, mesh.MeshId, mesh.TextureId = Enum.MeshType.FileMesh, definition.MeshId, definition.TextureId
				mesh.Scale, mesh.Parent = definition.Scale, part
				part.Position, part.Parent = origin, folder
				local ground = workspace:Raycast(origin, Vector3.new(0, -256, 0), params({ character, folder }))
				local height = if ground then math.max(0.01, origin.Y - ground.Position.Y - Rules.Radius) else 0.01
				table.insert(projectiles, { Part = part, Position = origin, Velocity = Rules.velocity(direction, hip, workspace.Gravity, height),
					Age = 0, Impact = definition.Grenade == "Impact", Owner = character })
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		for player, held in primed do
			local humanoid = held.Character:FindFirstChildOfClass("Humanoid")
			local head = held.Character:FindFirstChild("Head") :: BasePart?
			if SessionRules.blocked(player) or player.Character ~= held.Character or held.Tool.Parent ~= held.Character or not head
				or not humanoid or humanoid.Health <= 0 then cancel(player); continue end
			local position = Rules.hand(CFrame.lookAt(head.Position, head.Position + held.Direction), held.Hip)
			if held.Definition.Grenade == "Impact" then
				local contact = handContact(held, position)
				if contact or handOverlaps(held, position) then
					consume(held)
					cancel(player)
					explode(if contact then contact.Position + contact.Normal * (Rules.Radius + 0.02) else position, held.Character)
					continue
				end
			end
			held.LastHand = position
		end
		for index = #projectiles, 1, -1 do
			local projectile = projectiles[index]
			local session = ReplicatedStorage:FindFirstChild("SessionState")
			if session and session:GetAttribute("Phase") ~= "Combat" then
				projectile.Part:Destroy()
				table.remove(projectiles, index)
				continue
			end
			local remaining = dt
			local detonated = false
			-- Swept, fixed-size substeps prevent tunnelling and frame-rate-dependent bounces.
			while remaining > 0 do
				local step = math.min(remaining, 1 / 120)
				remaining -= step
				projectile.Age += step
				local acceleration = Vector3.new(0, -workspace.Gravity, 0)
				local travel = projectile.Velocity * step + acceleration * (step * step * 0.5)
				projectile.Velocity += acceleration * step
				-- Briefly ignore the throwing body while the grenade clears the hand.
				local filter = params(if projectile.Age < 0.15 then { folder, projectile.Owner } else { folder })
				local hit = if travel.Magnitude > 0.00001
					then workspace:Spherecast(projectile.Position, Rules.Radius, travel, filter) else nil
				if hit then
					projectile.Position = hit.Position + hit.Normal * (Rules.Radius + 0.02)
					if projectile.Impact then detonated = true; break end
					local normalSpeed = projectile.Velocity:Dot(hit.Normal)
					projectile.Velocity = (projectile.Velocity - hit.Normal * (math.min(normalSpeed, 0) * 1.35)) * 0.65
				else
					projectile.Position += travel
				end
				if not projectile.Impact and projectile.Age >= Rules.Fuse then
					detonated = true; break
				end
				if projectile.Age >= 30 then break end
			end
			if detonated or projectile.Age >= 30 then
				projectile.Part:Destroy()
				table.remove(projectiles, index)
				if detonated then explode(projectile.Position, projectile.Owner) end
			else
				projectile.Part.CFrame = CFrame.new(projectile.Position) * CFrame.Angles(projectile.Age * 5, 0, projectile.Age * 3)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		cancel(player)
		lastAim[player], nextPrime[player] = nil, nil
	end)
end

return Grenades
