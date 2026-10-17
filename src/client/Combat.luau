--!strict

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Ballistics = require(ReplicatedStorage.Shared.Ballistics)
local Effects = require(script.Parent.ShotEffects)

local Combat = {}

function Combat.start(player: Player)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local fire = remotes:WaitForChild("FireShot") :: RemoteEvent
	local reload = remotes:WaitForChild("ReloadWeapon") :: RemoteEvent
	local effects = remotes:WaitForChild("ShotEffect") :: RemoteEvent
	local state = {
		Aim = CFrame.identity,
		ADS = 0,
		Kick = 0,
		Muzzle = nil :: Vector3?,
		Active = false,
	}
	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHUD"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Parent = player:WaitForChild("PlayerGui")
	local crosshair = Instance.new("Frame")
	crosshair.Name = "BallisticReticle"
	crosshair.Size = UDim2.fromOffset(2, 2)
	crosshair.BackgroundTransparency = 1
	crosshair.Visible = false
	crosshair.Parent = gui
	local lines: { Frame } = {}
	for _, geometry in {
		{ -8, 0, 5, 2 }, { 8, 0, 5, 2 }, { 0, -8, 2, 5 }, { 0, 8, 2, 5 }, { 0, 0, 2, 2 },
	} do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromOffset(geometry[1], geometry[2])
		line.Size = UDim2.fromOffset(geometry[3], geometry[4])
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.new(0.9, 1, 0.94)
		line.Parent = crosshair
		local stroke = Instance.new("UIStroke")
		stroke.Transparency = 0.4
		stroke.Parent = line
		table.insert(lines, line)
	end
	local status = Instance.new("TextLabel")
	status.AnchorPoint = Vector2.new(1, 1)
	status.Position = UDim2.new(1, -28, 1, -28)
	status.Size = UDim2.fromOffset(280, 60)
	status.BackgroundTransparency = 1
	status.TextColor3 = Color3.fromRGB(232, 239, 244)
	status.TextStrokeTransparency = 0.4
	status.Font = Enum.Font.GothamMedium
	status.TextSize = 18
	status.TextXAlignment = Enum.TextXAlignment.Right
	status.Parent = gui

	local held, aiming, queued = false, false, false
	local currentTool: Tool? = nil
	local carry, impulse = Vector2.zero, Vector2.zero
	local lastShot, nextShot, hitUntil = -math.huge, 0, 0
	local index, phase, movement = 0, 0, 0
	local defaultFov = 70
	local lastCamera: Camera? = nil
	local function release()
		held, aiming, queued = false, false, false
	end
	UserInputService.WindowFocusReleased:Connect(release)
	UserInputService.TextBoxFocused:Connect(release)
	GuiService.MenuOpened:Connect(release)
	player.CharacterRemoving:Connect(function()
		release()
		currentTool = nil
		carry, impulse = Vector2.zero, Vector2.zero
		lastShot = -math.huge
	end)
	ContextActionService:BindActionAtPriority("RobostrikeCombat", function(_, inputState, input)
		if inputState == Enum.UserInputState.Cancel then
			release()
			return Enum.ContextActionResult.Sink
		end
		local pressed = inputState == Enum.UserInputState.Begin
		if pressed and UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if pressed then held, queued = true, true
			elseif inputState == Enum.UserInputState.End then held = false end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			aiming = pressed
		elseif pressed and input.KeyCode == Enum.KeyCode.R then
			reload:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 1,
		Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.KeyCode.R)

	effects.OnClientEvent:Connect(function(shooter: number, _slot: number, muzzle: Vector3, target: Vector3,
		normal: Vector3?, material: Enum.Material?, hit: Instance?, flesh: boolean)
		if shooter == player.UserId then
			muzzle = state.Muzzle or muzzle
			if flesh then hitUntil = os.clock() + 0.12 end
		else
			Effects.flash(muzzle)
		end
		Effects.tracer(muzzle, target)
		if normal and material then Effects.impact(target, normal, material, hit, flesh) end
	end)

	-- After Roblox mouse look, before Viewmodel: one aim transform drives the
	-- screen marker, gun sights AND the network ray. No post-ray random spread.
	RunService:BindToRenderStep("RobostrikeCombat", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		if not camera then return end
		if camera ~= lastCamera then
			lastCamera = camera
			defaultFov = camera.FieldOfView
		end
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		local tool = if character then character:FindFirstChildOfClass("Tool") else nil
		local slot = if tool then tool:GetAttribute("WeaponSlot") else nil
		local definition = if typeof(slot) == "number" then Weapons[slot] else nil
		if tool ~= currentTool then
			currentTool = tool
			-- Switching cannot erase recoil or bypass the shared firing cooldown.
			queued = false
			state.Muzzle = nil
		end
		local active = humanoid ~= nil and humanoid.Health > 0 and definition ~= nil and definition.FireInterval ~= nil
		state.Active = active
		state.ADS += ((if active and aiming and tool and not tool:GetAttribute("Reloading") then 1 else 0) - state.ADS) * (1 - math.exp(-dt * 16))
		camera.FieldOfView = defaultFov + (55 - defaultFov) * state.ADS
		crosshair.Visible, status.Visible = active, active
		if not active or not tool or not humanoid then
			state.Aim = camera.CFrame
			held, queued = false, false
			return
		end
		local speed = if root then (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude else 0
		local amount = math.clamp(speed / 22, 0, 1)
		if humanoid.FloorMaterial == Enum.Material.Air then amount = math.max(amount, 0.8) end
		movement += (amount - movement) * (1 - math.exp(-dt * 12))
		phase += dt * (6 + speed * 0.34)
		local age = os.clock() - lastShot
		local rise = math.clamp(age / 0.035, 0, 1)
		rise = rise * rise * (3 - 2 * rise)
		local recoil = (carry + impulse * rise) * Ballistics.recovery(age)
		local offset = recoil + Ballistics.sway(phase, movement, state.ADS)
		state.Aim = camera.CFrame * CFrame.Angles(offset.Y, -offset.X, 0)
		state.Kick = math.max(0, 1 - age / 0.12)
		local point = camera:WorldToViewportPoint(state.Aim.Position + state.Aim.LookVector * 1000)
		crosshair.Position = UDim2.fromOffset(point.X, point.Y)
		for n, line in lines do
			-- Keep a tiny dot in ADS as a verifiable ballistic reference; the
			-- remaining cross arms fade so iron sights do not get covered by UI.
			line.BackgroundTransparency = if n == 5 then state.ADS * 0.65 else state.ADS
			line.BackgroundColor3 = if os.clock() < hitUntil then Color3.fromRGB(255, 111, 92) else Color3.new(0.9, 1, 0.94)
			local stroke = line:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Transparency = 0.4 + state.ADS * 0.6 end
		end
		local reloading = tool:GetAttribute("Reloading") == true
		local ammo = tool:GetAttribute("Ammo") or 0
		status.Text = string.format("%s   %d / %d\n%s", definition.ModelName, ammo, definition.Magazine,
			if reloading then "Перезарядка…" else "ЛКМ — огонь  ·  ПКМ — прицел  ·  R — перезарядка")
		status.TextSize = 15
		local now = os.clock()
		if (held or queued) and not reloading and ammo > 0 and now >= nextShot then
			queued = false
			nextShot = Ballistics.nextShot(now, nextShot, definition.FireInterval, dt)
			-- Send the displayed direction BEFORE starting the next recoil kick.
			fire:FireServer(state.Aim.Position, state.Aim.LookVector)
			if state.Muzzle then Effects.flash(state.Muzzle) end
			index += 1
			carry = recoil
			impulse = Ballistics.kick(index, now - lastShot, definition.Recoil)
			if state.ADS > 0.5 then impulse *= 0.65 end
			lastShot = now
		end
	end)
	return state
end

return Combat
