--!strict

local RunService = game:GetService("RunService")

local MapMirror = {}

function MapMirror.start(map: Instance)
	local folder = map:WaitForChild("Mirrors")
	local mirror = folder:WaitForChild("PassageMirror") :: BasePart
	local planeX = mirror.Position.X + mirror.Size.X / 2
	local center = Vector3.new(planeX, mirror.Position.Y, mirror.Position.Z)
	local normal, up, right = Vector3.xAxis, Vector3.yAxis, -Vector3.zAxis
	local gui = Instance.new("SurfaceGui")
	gui.Name = "PassageReflection"
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(750, 360)
	gui.LightInfluence = 0
	gui.Parent = mirror
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundColor3 = Color3.fromRGB(55, 65, 72)
	viewport.Ambient = Color3.fromRGB(180, 180, 180)
	viewport.LightColor = Color3.fromRGB(230, 235, 240)
	viewport.LightDirection = Vector3.new(-1, -2, -1)
	viewport.Parent = gui
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 70
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local function reflect(v: Vector3): Vector3
		return Vector3.new(2 * planeX - v.X, v.Y, v.Z)
	end
	local function direction(v: Vector3): Vector3
		return Vector3.new(-v.X, v.Y, v.Z)
	end
	local function reflectedFrame(frame: CFrame): CFrame
		-- Flip local X too: Roblox CFrames must remain right-handed. Native
		-- boxes and BSP wedges are symmetric on that axis.
		return CFrame.fromMatrix(reflect(frame.Position), -direction(frame.RightVector), direction(frame.UpVector), -direction(frame.LookVector))
	end
	type Pair = { source: BasePart, copy: BasePart }
	local moving: { Pair } = {}
	local actors: { [Model]: { Pair } } = {}
	local function copyPart(source: BasePart): BasePart?
		if source.Transparency >= 1 or not source.Archivable then return nil end
		local copy = source:Clone() :: BasePart
		for _, child in copy:GetChildren() do
			if not child:IsA("DataModelMesh") then child:Destroy() end
		end
		copy.Anchored = true
		copy.CanCollide = false
		copy.CanTouch = false
		copy.CanQuery = false
		copy.LocalTransparencyModifier = 0 -- First-person hiding must not hide the reflection.
		copy.CFrame = reflectedFrame(source.CFrame)
		copy.Parent = world
		return copy
	end
	-- Exclude the thousands of grout strips and the mirror itself. No recursive
	-- viewport copies, scripts, physics, or asset uploads are needed.
	for _, groupName in { "Geometry", "Doors", "Water" } do
		local group = map:FindFirstChild(groupName)
		if not group then continue end
		for _, source in group:GetDescendants() do
			if not source:IsA("BasePart") then continue end
			-- Do not reflect the backing wall from behind the mirror: it would
			-- become an opaque sheet in front of the virtual scene.
			if source.Position.X <= planeX + 0.08 then continue end
			local copy = copyPart(source)
			if copy and groupName == "Doors" then table.insert(moving, { source = source, copy = copy }) end
		end
	end

	local function syncActors()
		for actor, pairs in actors do
			if not actor:IsDescendantOf(workspace) then
				for _, pair in pairs do pair.copy:Destroy() end
				actors[actor] = nil
			end
		end
		-- Players and bots are direct Workspace models in this project.
		for _, actor in workspace:GetChildren() do
			if not actor:IsA("Model") or not actor:FindFirstChildOfClass("Humanoid") then continue end
			local pairs = actors[actor]
			if not pairs then pairs = {}; actors[actor] = pairs end
			local known: { [BasePart]: boolean } = {}
			for i = #pairs, 1, -1 do
				local pair = pairs[i]
				if not pair.source:IsDescendantOf(actor) then
					pair.copy:Destroy()
					table.remove(pairs, i)
				else known[pair.source] = true end
			end
			for _, part in actor:GetDescendants() do
				if part:IsA("BasePart") and not known[part] then
					local copy = copyPart(part)
					if copy then table.insert(pairs, { source = part, copy = copy }) end
				end
			end
		end
	end
	local elapsed, actorElapsed = 0, 1
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		actorElapsed += dt
		if elapsed < 1 / 30 then return end
		elapsed = 0
		local view = workspace.CurrentCamera
		if not view then return end
		local offset = view.CFrame.Position - center
		local distance = offset:Dot(normal)
		gui.Enabled = distance > 0.2 and distance < 55 and math.abs(offset.Z) < 26
		if not gui.Enabled then return end
		-- Off-axis projection onto the physical rectangle. A plain lookAt camera
		-- would slide the reflection when the player looks from the side.
		local scale = mirror.Size.Y / (2 * distance * math.tan(math.rad(camera.FieldOfView / 2)))
		camera.CFrame = CFrame.fromMatrix(view.CFrame.Position, right * scale, up * scale,
			normal + right * (offset:Dot(right) / distance) + up * (offset.Y / distance))
		if actorElapsed >= 0.5 then syncActors(); actorElapsed = 0 end
		for _, pair in moving do
			if pair.source.Parent then pair.copy.CFrame = reflectedFrame(pair.source.CFrame) end
		end
		for _, pairs in actors do
			for _, pair in pairs do
				if pair.source.Parent then
					pair.copy.CFrame = reflectedFrame(pair.source.CFrame)
					pair.copy.Transparency = pair.source.Transparency
				end
			end
		end
	end)
end

return MapMirror
