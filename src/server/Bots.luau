--!strict
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Combat = require(script.Parent.Combat)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Bots = {}

function Bots.start(slots: any, state: Folder, remotes: Folder)
	local brains: { [Model]: any } = {}
	local random = Random.new()
	local elapsed = 0
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
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then return end
		elapsed = 0
		for model in brains do if not living(model) then brains[model] = nil end end
		if state:GetAttribute("Phase") ~= "Combat" then return end
		local now = os.clock()
		for id, roster in slots do
			for _, slot in roster do
				local model = slot.model
				if slot.player or not living(model) then continue end
				local h = model:FindFirstChildOfClass("Humanoid") :: Humanoid
				local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
				local head = model:FindFirstChild("Head") :: BasePart
				local brain = brains[model]
				if not brain then
					brain = { nextShot = 0, nextPath = 0, waypoints = {}, waypoint = 1, burst = 0 }
					brains[model] = brain
					root:SetNetworkOwner(nil)
				end
				local target: Model? = nil
				local visible = false
				local distance = math.huge
				local filter = RaycastParams.new()
				filter.FilterDescendantsInstances = { model }
				filter.IgnoreWater = true
				for _, enemy in slots[if id == "Red" then "Blue" else "Red"] do
					if not living(enemy.model) then continue end
					local enemyHead = enemy.model:FindFirstChild("Head") :: BasePart?
					if not enemyHead then continue end
					local delta = enemyHead.Position - head.Position
					local hit = workspace:Raycast(head.Position, delta, filter)
					local seen = hit == nil or hit.Instance:IsDescendantOf(enemy.model)
					if (seen and not visible) or (seen == visible and delta.Magnitude < distance) then
						target, visible, distance = enemy.model, seen, delta.Magnitude
					end
				end
				if not visible or target ~= brain.target then
					-- React anew after cover or a target switch; no instant snap shots.
					brain.nextShot = now + random:NextNumber(0.9, 1.6)
					brain.burst = 0
				end
				brain.target = if visible then target else nil
				if not target then continue end
				local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart
				if visible then
					h.AutoRotate = false
					local flat = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
					if (flat - root.Position).Magnitude > 0.1 then root.CFrame = CFrame.lookAt(root.Position, flat) end
					move(model, h, root, if distance > 35 then targetRoot.Position else root.Position, roster)
					if now >= brain.nextShot then
						local tool = model:FindFirstChildOfClass("Tool")
						if not tool then continue end
						if (tool:GetAttribute("Ammo") or 0) <= 0 then
							if not brain.reloading then brain.reloading = now + Weapons[1].ReloadTime end
							if now >= brain.reloading then tool:SetAttribute("Ammo", Weapons[1].Magazine); brain.reloading = nil end
							continue
						end
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
					if now >= brain.nextPath and not brain.computing then
						brain.nextPath, brain.computing = now + 2, true
						local destination = targetRoot.Position
						task.spawn(function()
							local path = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4 })
							local ok = pcall(function() path:ComputeAsync(root.Position, destination) end)
							if ok and path.Status == Enum.PathStatus.Success then
								brain.waypoints, brain.waypoint = path:GetWaypoints(), 2
								model:SetAttribute("PathFailed", false)
							else model:SetAttribute("PathFailed", true) end
							brain.computing = false
						end)
					end
					local waypoint = brain.waypoints[brain.waypoint]
					if waypoint then
						if (root.Position - waypoint.Position).Magnitude < 3 then brain.waypoint += 1 end
						h.Jump = waypoint.Action == Enum.PathWaypointAction.Jump
						move(model, h, root, waypoint.Position, roster)
					else move(model, h, root, targetRoot.Position, roster) end
				end
			end
		end
	end)
end

return Bots
