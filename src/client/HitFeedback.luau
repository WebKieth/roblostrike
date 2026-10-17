--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Rules = require(ReplicatedStorage.Shared.HitFeedback)
local HitFeedback = {}

function HitFeedback.start(player: Player): () -> (number, number)
	local event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DamageTaken") :: RemoteEvent
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn = "IncomingDamage", true, false
	gui.DisplayOrder = 11
	gui.Parent = player:WaitForChild("PlayerGui")
	local arcs: { { Frame: Frame, Origin: Vector3, Time: number, Segments: { Frame } } } = {}
	local flinchTime, flinchStrength = -math.huge, 0
	local function clear()
		for _, arc in arcs do arc.Frame:Destroy() end
		table.clear(arcs)
		flinchTime, flinchStrength = -math.huge, 0
	end
	player.CharacterRemoving:Connect(clear)
	player.CharacterAdded:Connect(clear)
	local function alive(): boolean
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		return humanoid ~= nil and humanoid.Health > 0
	end
	event.OnClientEvent:Connect(function(body: Model, origin: Vector3, headshot: boolean)
		-- Ignore delayed packets from an old life and never kick a spectator camera.
		if body ~= player.Character or not alive() then return end
		local now = os.clock()
		if headshot then
			flinchStrength = math.min(1.5, 1 + flinchStrength * Rules.weight(now - flinchTime, Rules.Recovery))
			flinchTime = now
		end
		if #arcs >= 8 then table.remove(arcs, 1).Frame:Destroy() end
		local frame = Instance.new("Frame")
		frame.Name, frame.BackgroundTransparency = "DamageArc", 1
		frame.AnchorPoint, frame.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromOffset(0, 0)
		frame.Parent = gui
		local segments: { Frame } = {}
		for i = -16, 16 do
			local segment = Instance.new("Frame")
			segment.AnchorPoint = Vector2.new(0.5, 0.5)
			segment.BorderSizePixel = 0
			segment.BackgroundColor3 = Color3.fromRGB(244, 32, 24)
			segment.Parent = frame
			-- Soft radial edges; segment opacity also tapers along the arc.
			local gradient = Instance.new("UIGradient")
			gradient.Rotation = 90
			gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.05),
				NumberSequenceKeypoint.new(1, 1),
			})
			gradient.Parent = segment
			table.insert(segments, segment)
		end
		table.insert(arcs, { Frame = frame, Origin = origin, Time = now, Segments = segments })
	end)
	RunService:BindToRenderStep("RobostrikeDamageArcs", Enum.RenderPriority.Camera.Value + 3, function()
		if not alive() then clear(); return end
		local camera = workspace.CurrentCamera
		if not camera then return end
		local now = os.clock()
		local size = math.min(camera.ViewportSize.X, camera.ViewportSize.Y)
		local radius, thickness = size * 0.24, math.max(12, size * 0.032)
		for i = #arcs, 1, -1 do
			local arc = arcs[i]
			local weight = Rules.weight(now - arc.Time, Rules.ArcLifetime)
			if weight == 0 then
				arc.Frame:Destroy()
				table.remove(arcs, i)
				continue
			end
			local direction = camera.CFrame:VectorToObjectSpace(arc.Origin - camera.CFrame.Position)
			arc.Frame.Rotation = math.deg(Rules.bearing(direction.X, direction.Z))
			for n, segment in arc.Segments do
				local t = (n - 17) / 16
				local angle = t * math.rad(50)
				segment.Position = UDim2.fromOffset(math.sin(angle) * radius, -math.cos(angle) * radius)
				segment.Size = UDim2.fromOffset(radius * math.rad(3.3), thickness)
				segment.Rotation = math.deg(angle)
				segment.BackgroundTransparency = 1 - weight * (1 - t * t) * 0.9
			end
		end
	end)
	return function(): (number, number)
		if not alive() then return 0, 0 end
		local weight = flinchStrength * Rules.weight(os.clock() - flinchTime, Rules.Recovery)
		return Rules.CameraPitch * weight, Rules.AimDrop * weight
	end
end

return HitFeedback
