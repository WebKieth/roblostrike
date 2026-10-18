--!strict

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Config = require(ReplicatedStorage.Shared.Config)
local SCALE = Config.ViewmodelScale
local Ballistics = require(ReplicatedStorage.Shared.Ballistics)
local Effects = require(script.Parent.ShotEffects)
local WeaponAnimation = require(ReplicatedStorage.Shared.WeaponAnimation)

local Combat = {}

function Combat.start(player: Player)
	local hitFeedback = require(script.Parent.HitFeedback).start(player)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local fire = remotes:WaitForChild("FireShot") :: RemoteEvent
	local reload = remotes:WaitForChild("ReloadWeapon") :: RemoteEvent
	local effects = remotes:WaitForChild("ShotEffect") :: RemoteEvent
	local equip = remotes:WaitForChild("EquipWeapon") :: RemoteEvent
	local state = {
		Aim = CFrame.identity,
		WeaponFrame = nil :: CFrame?,
		ADS = 0,
		Kick = 0,
		Muzzle = nil :: Vector3?,
		Active = false,
		ShotTime = -math.huge,
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
	local dispersion = Vector2.zero
	local random = Random.new()
	local lastShot, nextShot, hitUntil = -math.huge, 0, 0
	local index, phase, movement = 0, 0, 0
	local defaultFov = 70
	local lastCamera: Camera? = nil
	local lastEquipRequest = 0
	local recoilCamera: Camera? = nil
	local cameraRotation = CFrame.identity
	local function release()
		held, aiming, queued = false, false, false
	end
	UserInputService.WindowFocusReleased:Connect(release)
	UserInputService.TextBoxFocused:Connect(release)
	GuiService.MenuOpened:Connect(release)
	player:GetAttributeChangedSignal("SettingsOpen"):Connect(release)
	player:GetAttributeChangedSignal("HUDCursorFree"):Connect(release)
	player.CharacterRemoving:Connect(function()
		release()
		currentTool = nil
		carry, impulse = Vector2.zero, Vector2.zero
		dispersion = Vector2.zero
		lastShot = -math.huge
		state.WeaponFrame, state.Muzzle = nil, nil
	end)
	ContextActionService:BindActionAtPriority("RobostrikeCombat", function(_, inputState, input)
		if inputState == Enum.UserInputState.Cancel then
			release()
			return Enum.ContextActionResult.Sink
		end
		local pressed = inputState == Enum.UserInputState.Begin
		if player:GetAttribute("SessionBlocked") or player:GetAttribute("TeamMenuOpen") or player:GetAttribute("SettingsOpen") or player:GetAttribute("HUDCursorFree") then release(); return Enum.ContextActionResult.Pass end
		if pressed and UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if pressed and not held then held, queued = true, true
			elseif inputState == Enum.UserInputState.End then held = false end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			aiming = pressed
		elseif pressed and input.KeyCode == Enum.KeyCode.R then
			reload:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 1,
		Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.KeyCode.R)

	effects.OnClientEvent:Connect(function(shooter: number, slot: number, muzzle: Vector3, target: Vector3,
		normal: Vector3?, material: Enum.Material?, hit: Instance?, flesh: boolean, character: Model?)
		if shooter == player.UserId then
			if flesh then hitUntil = os.clock() + 0.12 end
		else
			local delta = target - muzzle
			local direction = if delta.Magnitude > 0.001 then delta.Unit else Vector3.new(0, 0, -1)
			local definition = Weapons[slot]
			local muzzleFrame = Effects.worldFlash(character, slot, definition, muzzle, direction)
			Effects.tracer(muzzleFrame.Position, target)
			if definition then
				Effects.sound(muzzleFrame.Position, definition)
				Effects.casing(muzzleFrame * CFrame.new(-definition.Muzzle), definition)
			end
		end
		if normal and material then Effects.impact(target, normal, material, hit, flesh) end
	end)

	-- Remove only our presentation rotation before Roblox processes mouse look.
	-- Otherwise last frame's camera kick feeds back and gets applied twice.
	RunService:BindToRenderStep("RobostrikeRecoilCamera", Enum.RenderPriority.Camera.Value - 1, function()
		if recoilCamera and recoilCamera == workspace.CurrentCamera then
			recoilCamera.CFrame *= cameraRotation:Inverse()
		end
		recoilCamera = nil
		cameraRotation = CFrame.identity
	end)

	-- Resolve this frame's gun pose BEFORE drawing the reticle or firing.
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
		local head = if character then character:FindFirstChild("Head") :: BasePart? else nil
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
			and not player:GetAttribute("SessionBlocked") and not player:GetAttribute("TeamMenuOpen") and not player:GetAttribute("SettingsOpen")
		state.Active = active
		state.ADS += ((if active and aiming and tool and not tool:GetAttribute("Reloading") then 1 else 0) - state.ADS) * (1 - math.exp(-dt * 16))
		camera.FieldOfView = defaultFov + (55 - defaultFov) * state.ADS
		crosshair.Visible, status.Visible = active, active
		local flinchLift, aimDrop = hitFeedback()
		if not active or not tool or not humanoid or not head then
			state.Aim = camera.CFrame * CFrame.Angles(-aimDrop, 0, 0)
			cameraRotation = CFrame.Angles(flinchLift, 0, 0)
			recoilCamera = camera
			camera.CFrame *= cameraRotation
			-- Freeze blocks firing, not the camera-local presentation. Never leave
			-- hands pointing at identity/last round's world-space weapon frame.
			state.WeaponFrame = if definition and definition.FireInterval then state.Aim * definition.View else nil
			state.Muzzle = nil
			held, aiming, queued = false, false, false
			if humanoid and humanoid.Health > 0 and not tool then
				status.Visible = true
				status.Text = "Пустой слот — подойди к оружию"
				-- Recover if Roblox clears/replaces the Backpack during spawn.
				-- Request the real server Tool; never draw a fake gun without one.
				if os.clock() - lastEquipRequest >= 1 then
					lastEquipRequest = os.clock()
					equip:FireServer(player:GetAttribute("SelectedSlot") or 1)
				end
			end
			return
		end
		local speed = if root then (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude else 0
		local amount = math.clamp(speed / 22, 0, 1)
		if humanoid.FloorMaterial == Enum.Material.Air then amount = math.max(amount, 0.8) end
		movement += (amount - movement) * (1 - math.exp(-dt * 12))
		phase += dt * (6 + speed * 0.34)
		local now = os.clock()
		local age = now - lastShot
		local reloading = tool:GetAttribute("Reloading") == true
		local ammo = tool:GetAttribute("Ammo") or 0
		local shooting = Ballistics.trigger(definition.Automatic == true, held, queued) and not reloading and ammo > 0 and now >= nextShot
		if shooting then
			-- Resolve randomness BEFORE pose, reticle and ray, including shot #1.
			dispersion = Ballistics.dispersion(index + 1, age, random:NextNumber(), random:NextNumber())
		end
		local rise = math.clamp(age / 0.035, 0, 1)
		rise = rise * rise * (3 - 2 * rise)
		local recoil = (carry + impulse * rise) * Ballistics.recoilWeight(age, definition.FireInterval)
		local spreadScale = Ballistics.spreadScale(definition.SpreadMultiplier, state.ADS, character:GetAttribute("Crouching") == true)
		local dispersionWeight = if shooting then 1 else Ballistics.recoilWeight(age, definition.FireInterval)
		-- Scale the whole current offset, not just the next impulse: entering
		-- ADS halves even an already accumulated burst; crouching adds x0.8.
		local offset = (recoil + Ballistics.sway(phase, movement, 0) + dispersion * dispersionWeight) * spreadScale
		-- Incoming head trauma is independent of ADS, crouch and shot cadence.
		-- It changes the actual gun/ballistic frame, not just the HUD position.
		offset -= Vector2.new(0, aimDrop)
		local basePitch, yaw, roll = camera.CFrame:ToOrientation()
		local pitch, cameraLift = Ballistics.elevation(basePitch, offset.Y)
		cameraRotation = CFrame.Angles(cameraLift + math.min(flinchLift, math.pi / 2 - basePitch - cameraLift), 0, 0)
		recoilCamera = camera
		camera.CFrame *= cameraRotation
		state.Aim = CFrame.new(camera.CFrame.Position) * CFrame.fromOrientation(pitch, yaw - offset.X, roll)
		state.Kick = math.max(0, 1 - age / 0.12)
		local aim = state.Aim
		local filter = RaycastParams.new()
		filter.FilterDescendantsInstances = { character :: Model, camera }
		filter.IgnoreWater = true
		-- Converge the sights at distance, never twist the bore towards a nearby
		-- camera hit. Close cover is resolved by the actual barrel ray below.
		local sightHit = workspace:Raycast(aim.Position, aim.LookVector * definition.Range, filter)
		local sightDistance = if sightHit then (sightHit.Position - aim.Position).Magnitude else definition.Range
		local sightTarget = aim.Position + aim.LookVector * math.max(50, sightDistance)
		local ads = definition.ADS.Position
		local translation = definition.View.Position:Lerp(Vector3.new(ads.X, ads.Y * SCALE, ads.Z), state.ADS)
		local position = aim:PointToWorldSpace(translation)
		local rotation = CFrame.lookAt(position + aim.UpVector * definition.SightHeight * SCALE, sightTarget, aim.UpVector).Rotation
		local weaponFrame = CFrame.new(position) * rotation * CFrame.new(0, 0, state.Kick * 0.21)
		weaponFrame *= WeaponAnimation.fromTool(tool, workspace:GetServerTimeNow()).Weapon
		local muzzle = weaponFrame:PointToWorldSpace(definition.Muzzle * SCALE)
		local reach = muzzle - head.Position
		local cover = if reach.Magnitude > 0.001 then workspace:Raycast(head.Position, reach, filter) else nil
		if cover then
			-- Pull the whole gun in front of cover without bending its barrel.
			local safeMuzzle = cover.Position - reach.Unit * 0.2
			weaponFrame += safeMuzzle - muzzle
			muzzle = safeMuzzle
		end
		state.WeaponFrame, state.Muzzle = weaponFrame, muzzle
		local direction = weaponFrame.LookVector
		local barrelHit = workspace:Raycast(muzzle, direction * definition.Range, filter)
		local target = if barrelHit then barrelHit.Position else muzzle + direction * definition.Range
		local point = camera:WorldToViewportPoint(target)
		crosshair.Position = UDim2.fromOffset(point.X, point.Y)
		for n, line in lines do
			-- Keep a tiny dot in ADS as a verifiable ballistic reference; the
			-- remaining cross arms fade so iron sights do not get covered by UI.
			line.BackgroundTransparency = if n == 5 then state.ADS * 0.65 else state.ADS
			line.BackgroundColor3 = if os.clock() < hitUntil then Color3.fromRGB(255, 111, 92) else Color3.new(0.9, 1, 0.94)
			local stroke = line:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Transparency = 0.4 + state.ADS * 0.6 end
		end
		status.Text = string.format("%s   %d / %d\n%s", definition.ModelName, ammo, tool:GetAttribute("ReserveAmmo") or 0,
			if reloading then "Перезарядка…"
			elseif definition.Automatic then "ЛКМ — огонь  ·  ПКМ — прицел  ·  R — перезарядка"
			else "ЛКМ — одиночный  ·  ПКМ — прицел  ·  R — перезарядка")
		status.TextSize = 15
		if shooting then
			queued = false
			nextShot = Ballistics.nextShot(now, nextShot, definition.FireInterval, dt)
			-- Head-relative positions are independent of character replication lag.
			fire:FireServer(muzzle - head.Position, direction)
			Effects.flash(muzzle, true, direction)
			Effects.casing(weaponFrame, definition, SCALE)
			Effects.tracer(muzzle, target)
			Effects.sound(muzzle, definition)
			index += 1
			carry = recoil
			impulse = Ballistics.kick(index, now - lastShot, 1)
			lastShot = now
			state.ShotTime = workspace:GetServerTimeNow()
		end
	end)
	return state
end

return Combat
