--!strict
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Combat = require(script.Parent.Combat)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Rules = require(ReplicatedStorage.Shared.SessionRules)
local Tactics = require(script.Parent.BotTactics)
local Bots = {}

function Bots.start(slots: any, state: Folder, remotes: Folder)
	local brains: { [Model]: any } = {}
	local random = Random.new()
	local elapsed = 0
	local reports: { [string]: any } = {}
	local function living(model: Model?): boolean
		local h = if model then model:FindFirstChildOfClass("Humanoid") else nil
		return model ~= nil and model.Parent ~= nil and h ~= nil and h.Health > 0
	end
	local function move(model: Model, humanoid: Humanoid, root: BasePart, destination: Vector3, roster: any)
		local direction = Vector3.new(destination.X - root.Position.X, 0, destination.Z - root.Position.Z)
		for _, ally in roster do
			if ally.model == model or not living(ally.model) then continue end
			local other = ally.model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not other then continue end
			local away = Vector3.new(root.Position.X - other.Position.X, 0, root.Position.Z - other.Position.Z)
			local radius = if ally.player then 6 else 4
			if away.Magnitude >= radius then continue end
			-- Yield to humans and spread out without applying forces or teleporting.
			if away.Magnitude > 0.1 and away.Magnitude < radius - 1 then
				local step = away.Unit * (radius - away.Magnitude)
				local filter = RaycastParams.new()
				filter.FilterDescendantsInstances = { model, ally.model }
				filter.RespectCanCollide = true
				filter.CollisionGroup = "Characters"
				if not workspace:Raycast(root.Position, step * 2, filter) then
					humanoid:MoveTo(root.Position + step)
					return
				end
			end
			if direction:Dot(away) < 0 or away.Magnitude <= 0.1 then
				humanoid:MoveTo(root.Position)
				return
			end
		end
		humanoid:MoveTo(destination)
	end
	local function navigate(model: Model, h: Humanoid, root: BasePart, brain: any, destination: Vector3, roster: any, now: number)
		if (root.Position - destination).Magnitude < 3 then
			move(model, h, root, root.Position, roster)
			return
		end
		local changed = not brain.pathGoal or (brain.pathGoal - destination).Magnitude > 6
		if changed then
			brain.waypoints, brain.waypoint, brain.nextPath, brain.pathGoal = {}, 1, 0, destination
		end
		if now >= brain.nextPath and not brain.computing then
			brain.nextPath, brain.computing = now + 1.5, true
			local start = root.Position
			local goal = brain.pathGoal
			task.spawn(function()
				local path = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4 })
				local ok = pcall(function() path:ComputeAsync(start, goal) end)
				-- ComputeAsync may finish after a death, round end, or change of plan.
				if brains[model] == brain and living(model) and state:GetAttribute("Phase") == "Combat"
					and brain.pathGoal == goal then
					if ok and path.Status == Enum.PathStatus.Success then
						brain.waypoints, brain.waypoint = path:GetWaypoints(), 2
						model:SetAttribute("PathFailed", false)
					else
						brain.waypoints = {}
						model:SetAttribute("PathFailed", true)
					end
				end
				brain.computing = false
			end)
		end
		local waypoint = brain.waypoints[brain.waypoint]
		while waypoint and (root.Position - waypoint.Position).Magnitude < 3 do
			brain.waypoint += 1
			waypoint = brain.waypoints[brain.waypoint]
		end
		if waypoint then
			h.Jump = waypoint.Action == Enum.PathWaypointAction.Jump
			move(model, h, root, waypoint.Position, roster)
		else
			-- Failed/pending paths must not make the bot run straight into a wall.
			move(model, h, root, root.Position, roster)
		end
		if now >= (brain.progressAt or 0) then
			if brain.progress and (root.Position - brain.progress).Magnitude < 1 then
				brain.nextPath = 0
			end
			brain.progress, brain.progressAt = root.Position, now + 1.5
		end
	end
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then return end
		elapsed = 0
		for model in brains do if not living(model) then brains[model] = nil end end
		if state:GetAttribute("Phase") ~= "Combat" then
			table.clear(reports)
			return
		end
		local now = os.clock()
		for id, roster in slots do
			for index, slot in roster do
				local model = slot.model
				if slot.player or not living(model) then continue end
				local h = model:FindFirstChildOfClass("Humanoid") :: Humanoid
				local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
				local head = model:FindFirstChild("Head") :: BasePart
				local brain = brains[model]
				if not brain then
					brain = { nextShot = 0, nextPath = 0, waypoints = {}, waypoint = 1, burst = 0,
						nextPlan = 0, health = h.Health, hurtUntil = 0, lastSeenAt = -math.huge,
						side = if index % 2 == 0 then -1 else 1, patrol = index }
					brains[model] = brain
					root:SetNetworkOwner(nil)
				end
				local target: Model? = nil
				local visible = false
				local distance = math.huge
				local filter = RaycastParams.new()
				filter.FilterDescendantsInstances = { model }
				filter.IgnoreWater = true
				local enemies: { Vector3 } = {}
				local allies: { Vector3 } = {}
				local characters: { Instance } = { model }
				for _, team in slots do
					for _, member in team do
						if living(member.model) then
							table.insert(characters, member.model)
							if team == roster and member.model ~= model then
								table.insert(allies, (member.model.HumanoidRootPart :: BasePart).Position)
							end
						end
					end
				end
				local geometry = RaycastParams.new()
				geometry.FilterDescendantsInstances = characters
				geometry.IgnoreWater, geometry.RespectCanCollide = true, true
				geometry.CollisionGroup = "Characters"
				for _, enemy in slots[if id == "Red" then "Blue" else "Red"] do
					if not living(enemy.model) then continue end
					local enemyHead = enemy.model:FindFirstChild("Head") :: BasePart?
					if not enemyHead then continue end
					local delta = enemyHead.Position - head.Position
					local hit = workspace:Raycast(head.Position, delta, filter)
					local seen = hit == nil or hit.Instance:IsDescendantOf(enemy.model)
					if seen then table.insert(enemies, enemyHead.Position) end
					-- Stick to the current visible opponent unless another is much closer.
					local priority = delta.Magnitude * (if enemy.model == brain.target then 0.75 else 1)
					if seen and priority < distance then
						target, visible, distance = enemy.model, true, priority
					end
				end
				if not visible or target ~= brain.target then
					-- React anew after cover or a target switch; no instant snap shots.
					brain.nextShot = now + random:NextNumber(0.9, 1.6)
					brain.burst = 0
				end
				brain.target = if visible then target else nil
				if h.Health < brain.health then brain.hurtUntil, brain.nextPlan = now + 2, 0 end
				brain.health = h.Health
				local tool = model:FindFirstChildOfClass("Tool")
				-- Reload independently of visibility: hiding must not stall the timer.
				if tool then
					local ammo = tool:GetAttribute("Ammo") or 0
					if not brain.reloading and (ammo <= 0 or (not visible and ammo < 10)) then
						brain.reloading, brain.nextPlan = now + Weapons[1].ReloadTime, 0
						tool:SetAttribute("Reloading", true)
					end
					if brain.reloading and now >= brain.reloading then
						tool:SetAttribute("Ammo", Weapons[1].Magazine)
						tool:SetAttribute("Reloading", false)
						brain.reloading, brain.nextPlan = nil, 0
					end
				end
				local targetRoot = if target then target:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
				if targetRoot then
					distance = (targetRoot.Position - root.Position).Magnitude
					brain.lastSeen, brain.lastSeenAt = targetRoot.Position, now
					reports[id] = { position = targetRoot.Position, time = now }
				end
				local report = reports[id]
				local known = if now - brain.lastSeenAt < 7 then brain.lastSeen
					else if report and now - report.time < 6 then report.position else nil
				local mode = Tactics.mode(h.Health, brain.reloading ~= nil, now < brain.hurtUntil, #enemies, #allies + 1)
				local retreat = mode == "Retreat"
				-- Briefly hold cover, then take a firing angle instead of immediately rushing out.
				local contact = now - brain.lastSeenAt < 4
				local peek = (now + index) % 5 > 1.5
				if known and (visible or retreat or contact) then
					if now >= brain.nextPlan or brain.mode ~= mode then
						brain.nextPlan = now + random:NextNumber(1.2, 2)
						brain.destination = Tactics.choose(model, root.Position, known + Vector3.new(0, 1.5, 0),
							enemies, allies, retreat, brain.side, geometry, peek)
					end
					brain.pathGoal, brain.waypoints = nil, {}
					move(model, h, root, brain.destination, roster)
				else
					-- Search only a remembered location; patrol fixed map objectives when it goes cold.
					local destination = known
					if not destination then
						destination = Rules.spawn(if id == "Red" then "Blue" else "Red", brain.patrol).Position
					end
					if (root.Position - destination).Magnitude < 5 then
						brain.lastSeenAt = -math.huge
						brain.patrol = brain.patrol % Rules.TeamSize + 1
					end
					navigate(model, h, root, brain, destination, roster, now)
				end
				brain.mode = mode
				model:SetAttribute("BotTactic", if retreat and known then "Retreat" else if visible then "Engage" else if known then "Search" else "Patrol")
				if visible and targetRoot then
					h.AutoRotate = false
					local flat = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
					if (flat - root.Position).Magnitude > 0.1 then root.CFrame = CFrame.lookAt(root.Position, flat) end
					if now >= brain.nextShot and tool and not brain.reloading then
						brain.burst += 1
						if brain.burst >= 3 then
							brain.nextShot = now + random:NextNumber(0.8, 1.4)
							brain.burst = 0
						else
							brain.nextShot = now + random:NextNumber(0.22, 0.38)
						end
						tool:SetAttribute("Ammo", tool:GetAttribute("Ammo") - 1)
						local spread = 2.5 + distance * 0.07
						local aim = targetRoot.Position + Vector3.new(random:NextNumber(-spread, spread),
							random:NextNumber(-spread * 0.5, spread * 0.5), random:NextNumber(-spread, spread))
						local direction = (aim - head.Position).Unit
						local hit = workspace:Raycast(head.Position, direction * Weapons[1].Range, filter)
						local victim = if hit then Combat.damage(hit, Weapons[1].DamageMultiplier, remotes.DamageNumber :: RemoteEvent, model) else nil
						(remotes.ShotEffect :: RemoteEvent):FireAllClients(0, 1, head.Position,
							if hit then hit.Position else head.Position + direction * Weapons[1].Range,
							if hit then hit.Normal else nil, if hit then hit.Material else nil, if hit then hit.Instance else nil, victim ~= nil)
					end
				else
					h.AutoRotate = true
				end
			end
		end
	end)
end

return Bots
