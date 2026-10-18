--!strict

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MapDoors = {}
local SENSOR_RADIUS = 2 / 0.28 -- metres -> studs, measured from the closed leaf.

local function actorRoot(part: BasePart): BasePart?
	local actor = part:FindFirstAncestorOfClass("Model")
	-- Only body parts count, not a weapon or accessory protruding through a door.
	if not actor or part.Parent ~= actor then return nil end
	local humanoid = actor:FindFirstChildOfClass("Humanoid")
	local root = actor:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return nil end
	return root
end

local function slidingDoor(door: Model, map: Instance)
	local panel = door:FindFirstChild("Panel") :: BasePart
	local closed = panel.CFrame
	local size = panel.Size
	local opened = closed + Vector3.new(0, size.Y + 0.15, 0)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { map }
	local open = false
	local tween: Tween? = nil
	local elapsed = 0
	local emptySince: number? = nil
	local connection: RBXScriptConnection? = nil

	local function occupied(): boolean
		for _, part in workspace:GetPartBoundsInBox(closed, size + Vector3.one * (2 * SENSOR_RADIUS), params) do
			local root = actorRoot(part)
			if not root then continue end
			local p = closed:PointToObjectSpace(root.Position)
			-- Distance to the rectangle/box, not its centre: wide doors must
			-- also respond at their edges, from either side of the passage.
			local delta = Vector3.new(math.max(0, math.abs(p.X) - size.X / 2),
				math.max(0, math.abs(p.Y) - size.Y / 2), math.max(0, math.abs(p.Z) - size.Z / 2))
			if delta.Magnitude <= SENSOR_RADIUS then return true end
		end
		return false
	end
	local function toggle(wantOpen: boolean)
		if wantOpen == open then return end
		open = wantOpen
		if tween then tween:Cancel() end
		local target = if open then opened else closed
		local duration = math.max(0.05, (target.Position - panel.Position).Magnitude / 18)
		tween = TweenService:Create(panel, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = target })
		tween:Play()
		door:SetAttribute("Open", open)
	end
	door:SetAttribute("SensorRadiusMetres", 2)
	door:SetAttribute("Open", false)
	connection = RunService.Heartbeat:Connect(function(dt)
		if not door:IsDescendantOf(workspace) then
			if tween then tween:Cancel() end
			if connection then connection:Disconnect() end
			return
		end
		elapsed += dt
		if elapsed < 0.05 then return end
		elapsed = 0
		if occupied() then
			emptySince = nil
			toggle(true) -- Immediately reverse even a partially closed panel.
		else
			local now = os.clock()
			if not emptySince then emptySince = now end
			if now - emptySince >= 0.4 then toggle(false) end
		end
	end)
end

function MapDoors.start(map: Instance)
	local folder = map:FindFirstChild("Doors")
	if not folder then return end
	for _, child in folder:GetChildren() do
		if not child:IsA("Model") then continue end
		local door = child
		local motion = door:FindFirstChild("Motion")
		if motion and motion:IsA("StringValue") and motion.Value == "Vertical" then
			slidingDoor(door, map)
			continue
		end
		local panel = door:FindFirstChild("Panel") :: BasePart
		local hinge = (door:FindFirstChild("Hinge") :: Vector3Value).Value
		local angle = (door:FindFirstChild("OpenAngle") :: NumberValue).Value
		local speed = (door:FindFirstChild("Speed") :: NumberValue).Value
		local delay = (door:FindFirstChild("CloseDelay") :: NumberValue).Value
		local pivot = CFrame.new(hinge)
		-- WorldPivot sets the hinge without translating the brush.
		door.WorldPivot = pivot
		local closedCenter = panel.Position
		local closedSize = panel.Size
		local open = false
		local busy = false
		local revision = 0
		local swing = 1
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { map }
		local driver = Instance.new("CFrameValue")
		driver.Value = pivot
		driver.Parent = door
		driver.Changed:Connect(function(value) door:PivotTo(value) end)

		local function occupied(): boolean
			-- Reserve the whole swing sector, not just the paper-thin closed panel.
			local width = closedSize.Z
			local center = CFrame.new(hinge + Vector3.new(swing * width / 2, closedCenter.Y - hinge.Y, width / 2))
			for _, part in workspace:GetPartBoundsInBox(center, Vector3.new(width + 2, closedSize.Y + 1, width + 2), params) do
				if actorRoot(part) then return true end
			end
			return false
		end

		local toggle: (boolean) -> ()
		local function scheduleClose(token: number)
			task.delay(math.max(1, delay), function()
				if not door.Parent or token ~= revision or not open then return end
				if occupied() or busy then scheduleClose(token) else toggle(false) end
			end)
		end
		toggle = function(wantOpen: boolean)
			if busy or wantOpen == open or (not wantOpen and occupied()) then return end
			busy = true
			revision += 1
			open = wantOpen
			local target = pivot * CFrame.Angles(0, math.rad(if open then angle * swing else 0), 0)
			local tween = TweenService:Create(driver, TweenInfo.new(math.abs(angle) / math.max(1, speed), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = target })
			local guard: RBXScriptConnection? = nil
			if not open then
				guard = RunService.Heartbeat:Connect(function()
					if not occupied() then return end
					if guard then guard:Disconnect(); guard = nil end
					tween:Cancel()
					busy = false
					toggle(true) -- Somebody entered the swing sector during closing.
				end)
			end
			tween.Completed:Once(function(state)
				if guard then guard:Disconnect(); guard = nil end
				if state ~= Enum.PlaybackState.Completed then return end
				busy = false
				if open then scheduleClose(revision) end
			end)
			tween:Play()
		end
		-- A narrow overlap catches physical contact even when CanTouch is disabled
		-- on the map. No proximity activation or client remote is involved.
		local elapsed = 0
		local contactConnection: RBXScriptConnection? = nil
		contactConnection = RunService.Heartbeat:Connect(function(dt)
			if not door.Parent then
				if contactConnection then contactConnection:Disconnect() end
				return
			end
			elapsed += dt
			if elapsed < 0.05 then return end
			elapsed = 0
			if busy or open then return end
			for _, part in workspace:GetPartBoundsInBox(panel.CFrame, panel.Size + Vector3.new(0.24, 0, 0), params) do
				local root = actorRoot(part)
				if not root then continue end
				-- Open away from the person pushing, on either side of the leaf.
				swing = if root.Position.X <= closedCenter.X then 1 else -1
				toggle(true)
				break
			end
		end)
	end
end

return MapDoors
