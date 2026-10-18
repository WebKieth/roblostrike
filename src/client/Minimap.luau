--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Minimap = {}

-- A bounded, client-only floor plan, sampled once per map; no cloned geometry or assets.
function Minimap.start(player: Player, gui: ScreenGui)
	local panel = Instance.new("Frame")
	panel.Name, panel.Size, panel.Position = "Minimap", UDim2.fromOffset(270, 156), UDim2.new(1, -294, 0, 48)
	panel.BackgroundColor3, panel.BorderSizePixel = Color3.fromRGB(15, 20, 30), 0
	panel.ClipsDescendants, panel.Visible, panel.Parent = true, false, gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
	local cells = Instance.new("Frame")
	cells.Size, cells.BackgroundTransparency, cells.Parent = UDim2.fromScale(1, 1), 1, panel
	local marker = Instance.new("TextLabel")
	marker.Name, marker.Text = "PlayerPosition", "▲"
	marker.Size, marker.AnchorPoint = UDim2.fromOffset(18, 18), Vector2.new(0.5, 0.5)
	marker.BackgroundTransparency, marker.TextColor3 = 1, Color3.fromRGB(255, 230, 95)
	marker.Font, marker.TextSize, marker.ZIndex = Enum.Font.GothamBold, 18, 3
	marker.Parent = panel
	local active: Model? = nil
	local descendants: RBXScriptConnection? = nil
	local center, width, depth = Vector3.zero, 1, 1
	local contacts: { TextLabel } = {}
	local function clearContacts()
		for _, contact in contacts do contact:Destroy() end
		table.clear(contacts)
	end
	local function position(point: Vector3): UDim2
		return UDim2.fromScale(math.clamp(0.5 + (point.X - center.X) / width, 0.03, 0.97),
			math.clamp(0.5 + (point.Z - center.Z) / depth, 0.05, 0.95))
	end
	local lastContacts = 0
	local event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MinimapContacts") :: RemoteEvent
	event.OnClientEvent:Connect(function(packet: { any })
		clearContacts()
		lastContacts = os.clock()
		if player:GetAttribute("InSession") ~= true or not active then return end
		for _, entry in packet do
			if entry.model == player.Character then continue end
			local contact = Instance.new("TextLabel")
			contact.Name, contact.Text = if entry.enemy then "EnemyContact" else "AllyContact", "●"
			contact.Size, contact.AnchorPoint = UDim2.fromOffset(12, 12), Vector2.new(0.5, 0.5)
			contact.BackgroundTransparency, contact.ZIndex = 1, 2
			contact.Font, contact.TextSize = Enum.Font.GothamBold, 13
			contact.TextColor3 = if entry.enemy then Color3.fromRGB(255, 85, 85) else Color3.fromRGB(90, 205, 255)
			contact.Position, contact.Parent = position(entry.position), panel
			table.insert(contacts, contact)
		end
	end)
	local function rebuild(map: Model)
		cells:ClearAllChildren()
		local frame, size = map:GetBoundingBox()
		center = frame.Position
		width = math.max(size.X, size.Z * 270 / 156) + 8
		depth = width * 156 / 270
		local spawns = map:FindFirstChild("TeamSpawns")
		local spawn = if spawns then spawns:FindFirstChild("Blue1") else nil
		local height = if spawn and spawn:IsA("BasePart") then spawn.Position.Y + 1 else 4
		local ray = RaycastParams.new()
		ray.FilterType, ray.FilterDescendantsInstances = Enum.RaycastFilterType.Include, { map }
		ray.RespectCanCollide, ray.IgnoreWater = true, true
		local overlap = OverlapParams.new()
		overlap.FilterType, overlap.FilterDescendantsInstances = Enum.RaycastFilterType.Include, { map }
		overlap.RespectCanCollide, overlap.MaxParts = true, 1
		local columns, rows = 64, 36
		for z = 0, rows - 1 do
			if active ~= map or map.Parent ~= workspace then return end
			for x = 0, columns - 1 do
				local point = Vector3.new(center.X + ((x + 0.5) / columns - 0.5) * width,
					height, center.Z + ((z + 0.5) / rows - 0.5) * depth)
				local wall = #workspace:GetPartBoundsInBox(CFrame.new(point), Vector3.new(width / columns, 0.2, depth / rows), overlap) > 0
				local floor = workspace:Raycast(point, Vector3.new(0, -64, 0), ray)
				if not wall and not floor then continue end
				local cell = Instance.new("Frame")
				cell.BorderSizePixel = 0
				cell.Position, cell.Size = UDim2.fromScale(x / columns, z / rows), UDim2.new(1 / columns, 1, 1 / rows, 1)
				cell.BackgroundColor3 = if wall then Color3.fromRGB(137, 158, 178) else Color3.fromRGB(48, 65, 80)
				cell.Parent = cells
			end
			if z % 4 == 0 then task.wait() end
		end
	end
	local function added(child: Instance)
		if child.Name ~= "ActiveMap" or not child:IsA("Model") then return end
		if descendants then descendants:Disconnect() end
		active = child
		clearContacts()
		cells:ClearAllChildren()
		local revision, queued = 0, false
		local queue: () -> ()
		queue = function()
			revision += 1
			if queued then return end
			queued = true
			task.spawn(function()
				local sampled = revision
				repeat
					sampled = revision
					task.wait(0.2) -- Replicated descendants may arrive after the model itself.
				until active ~= child or sampled == revision
				if active == child then rebuild(child) end
				queued = false
				if active == child and sampled ~= revision then queue() end
			end)
		end
		descendants = child.DescendantAdded:Connect(queue)
		queue()
	end
	workspace.ChildAdded:Connect(added)
	workspace.ChildRemoved:Connect(function(child)
		if child == active then
			active = nil
			clearContacts()
			if descendants then descendants:Disconnect(); descendants = nil end
			cells:ClearAllChildren()
		end
	end)
	local map = workspace:FindFirstChild("ActiveMap")
	if map then added(map) end
	RunService:BindToRenderStep("RobostrikeMinimap", Enum.RenderPriority.Camera.Value + 6, function()
		panel.Visible = player:GetAttribute("InSession") == true and active ~= nil
		if not panel.Visible or os.clock() - lastContacts > 1 then clearContacts() end
		local camera = workspace.CurrentCamera
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		marker.Visible = root ~= nil and humanoid ~= nil and humanoid.Health > 0
		if root and root:IsA("BasePart") then
			marker.Position = UDim2.fromScale(math.clamp(0.5 + (root.Position.X - center.X) / width, 0.03, 0.97),
				math.clamp(0.5 + (root.Position.Z - center.Z) / depth, 0.05, 0.95))
			if camera then marker.Rotation = math.deg(math.atan2(camera.CFrame.LookVector.X, -camera.CFrame.LookVector.Z)) end
		end
	end)
end

return Minimap
