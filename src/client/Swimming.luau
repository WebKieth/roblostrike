--!strict

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Water = require(ReplicatedStorage.Shared.Water)
local Settings = Water.Settings
local Swimming = {}

function Swimming.start(player: Player, pools: { Water.Pool })
	local active = false
	local rising = false
	local requested = false
	local cooldown = 0
	local currentCharacter: Model? = nil
	local verticalVelocity: LinearVelocity? = nil
	local attachment: Attachment? = nil
	local savedJump = 35
	local function release()
		if verticalVelocity then verticalVelocity:Destroy() end
		if attachment then attachment:Destroy() end
		verticalVelocity, attachment = nil, nil
		if currentCharacter then
			currentCharacter:SetAttribute("InWater", false)
			local humanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.JumpPower = savedJump end
		end
		active, rising, requested = false, false, false
	end
	ContextActionService:BindActionAtPriority("RobostrikeSwim", function(_, state)
		if not active or UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then requested = true end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Space)
	RunService.PreSimulation:Connect(function(dt)
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if currentCharacter ~= character then
			release()
			currentCharacter = character
			cooldown = 0
		end
		if not character or not humanoid or not root or humanoid.Health <= 0 or player:GetAttribute("SessionBlocked") or player:GetAttribute("TeamMenuOpen") then
			release()
			return
		end
		cooldown = math.max(0, cooldown - dt)
		local pool: Water.Pool? = nil
		for _, candidate in pools do
			if Water.contains(candidate, root.Position) and root.Position.Y < candidate.y + 0.15 then
				pool = candidate
				break
			end
		end
		if not pool or cooldown > 0 then
			if active then release() end
			return
		end
		if not active then
			active = true
			-- Space may already be held when crossing the water surface.
			rising = UserInputService:IsKeyDown(Enum.KeyCode.Space)
				and UserInputService:GetFocusedTextBox() == nil
			savedJump = humanoid.JumpPower
			attachment = Instance.new("Attachment")
			attachment.Parent = root
			-- Enforce vertical speed throughout the physics step, including when
			-- the Humanoid is grounded on the pool floor. Leave WASD axes free.
			local controller = Instance.new("LinearVelocity")
			controller.Attachment0 = attachment
			controller.RelativeTo = Enum.ActuatorRelativeTo.World
			controller.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
			controller.LineDirection = Vector3.yAxis
			controller.ForceLimitsEnabled = false
			controller.LineVelocity = math.max(root.AssemblyLinearVelocity.Y / 4, -Settings.SinkSpeed)
			controller.Parent = root
			verticalVelocity = controller
			character:SetAttribute("InWater", true)
			-- Absorb entry momentum immediately instead of falling to the bottom first.
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y / 4, -Settings.SinkSpeed), v.Z)
		end
		humanoid.Jump = false
		humanoid.JumpPower = 0
		-- Check held input at any depth, not only on entry or a Begin event.
		-- Keep rising latched after release so one press reaches the surface.
		if requested or (UserInputService:IsKeyDown(Enum.KeyCode.Space)
			and UserInputService:GetFocusedTextBox() == nil) then
			rising = true
		end
		requested = false
		local time = workspace:GetServerTimeNow()
		local surface = Water.height(pool, root.Position.X, root.Position.Z, time)
		local targetY = surface + Settings.SurfaceOffset + Settings.BobHeight * math.sin(time * 2.6)
		local velocity = root.AssemblyLinearVelocity
		local vy: number
		if rising then
			-- Critically damped spring: eases into ascent and settles without a hard snap.
			local omega = 5
			local errorY = targetY - root.Position.Y
			local decay = math.exp(-omega * dt)
			vy = (velocity.Y + (omega * errorY - velocity.Y) * omega * dt) * decay
			vy = math.clamp(vy, -Settings.RiseSpeed, Settings.RiseSpeed)
		else
			vy = velocity.Y + (-Settings.SinkSpeed - velocity.Y) * (1 - math.exp(-dt / 0.28))
		end
		if verticalVelocity then verticalVelocity.LineVelocity = vy end
		if not rising or math.abs(root.Position.Y - targetY) > 0.4 then return end
		local direction = humanoid.MoveDirection * Vector3.new(1, 0, 1)
		if direction.Magnitude < 0.1 then return end
		direction = direction.Unit
		local ahead = root.Position + direction * 2.6
		if Water.contains(pool, ahead) then return end
		local filter = RaycastParams.new()
		filter.FilterType = Enum.RaycastFilterType.Exclude
		filter.FilterDescendantsInstances = { character }
		filter.RespectCanCollide = true
		local landing = workspace:Raycast(Vector3.new(ahead.X, pool.y + 4, ahead.Z), Vector3.new(0, -5, 0), filter)
		if not landing or landing.Normal.Y < 0.8 then return end
		local stepHeight = landing.Position.Y - pool.y
		if stepHeight < -0.1 or stepHeight > 1.6 then return end
		local clearance = OverlapParams.new()
		clearance.FilterType = Enum.RaycastFilterType.Exclude
		clearance.FilterDescendantsInstances = { character }
		clearance.RespectCanCollide = true
		if #workspace:GetPartBoundsInBox(CFrame.new(landing.Position + Vector3.new(0, 2.6, 0)),
			Vector3.new(2.2, 4.8, 2.2), clearance) > 0 then return end
		local height = landing.Position.Y + 3.25 - root.Position.Y
		if height > 5.5 then return end
		release()
		cooldown = 0.65
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		root.AssemblyLinearVelocity = direction * 8 + Vector3.new(0, math.sqrt(2 * workspace.Gravity * math.max(height, 0.1)), 0)
	end)
end

return Swimming
