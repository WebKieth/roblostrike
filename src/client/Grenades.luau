--!strict

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Rules = require(ReplicatedStorage.Shared.Grenades)
local Grenades = {}

function Grenades.start(player: Player)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local action = remotes:WaitForChild("GrenadeAction") :: RemoteEvent
	local effects = remotes:WaitForChild("GrenadeExplosion") :: RemoteEvent
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "GrenadeHUD", false, true
	gui.DisplayOrder, gui.Parent = 13, player:WaitForChild("PlayerGui")
	local arc = Instance.new("Frame")
	arc.Name = "ThrowMode"
	arc.AnchorPoint, arc.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	arc.Size, arc.BackgroundTransparency, arc.Visible = UDim2.fromOffset(2, 2), 1, false
	arc.Parent = gui
	local radius = Rules.ReticleRadius
	for index = 0, 31 do
		local angle = math.pi + (index + 0.5) * math.pi / 32
		local segment = Instance.new("Frame")
		segment.AnchorPoint = Vector2.new(0.5, 0.5)
		segment.Position = UDim2.fromOffset(math.cos(angle) * radius, math.sin(angle) * radius)
		segment.Size = UDim2.fromOffset(radius * math.pi / 32 + 0.6, 2)
		segment.Rotation = math.deg(angle) + 90
		segment.BorderSizePixel = 0
		segment.BackgroundColor3 = Color3.fromRGB(230, 255, 240)
		segment.Parent = arc
		local stroke = Instance.new("UIStroke")
		stroke.Transparency, stroke.Parent = 0.5, segment
	end
	local status = Instance.new("TextLabel")
	status.AnchorPoint, status.Position = Vector2.new(1, 1), UDim2.new(1, -28, 1, -28)
	status.Size, status.BackgroundTransparency = UDim2.fromOffset(440, 70), 1
	status.Font, status.TextSize = Enum.Font.GothamMedium, 15
	status.TextColor3, status.TextStrokeTransparency = Color3.fromRGB(232, 239, 244), 0.4
	status.TextXAlignment, status.Visible, status.Parent = Enum.TextXAlignment.Right, false, gui
	local current: Tool? = nil
	local winding = false
	local hip = false
	local rotation = 0
	local tween: Tween? = nil
	local lastAim = 0

	local function equipped(): (Tool?, any)
		if player:GetAttribute("SessionBlocked") or player:GetAttribute("TeamMenuOpen") then return nil, nil end
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local tool = if character then character:FindFirstChildOfClass("Tool") else nil
		local slot = if tool then tool:GetAttribute("WeaponSlot") else nil
		local definition = if typeof(slot) == "number" then Weapons[slot] else nil
		if humanoid and humanoid.Health > 0 and definition and definition.Grenade then return tool, definition end
		return nil, nil
	end
	local function cancel()
		if winding then action:FireServer("Cancel") end
		winding = false
		if current then current:SetAttribute("GrenadeWinding", false) end
	end
	local function sync(tool: Tool?)
		if tool == current then return end
		cancel()
		current, hip, rotation = tool, false, 0
		if tween then tween:Cancel() end
		arc.Rotation = 0
		if tool then tool:SetAttribute("GrenadeHip", false) end
	end
	local function send(command: string)
		local camera = workspace.CurrentCamera
		if camera then action:FireServer(command, camera.CFrame.LookVector, hip) end
	end
	ContextActionService:BindActionAtPriority("RobostrikeGrenades", function(_, state, input)
		local tool = equipped()
		sync(tool)
		if not tool then return Enum.ContextActionResult.Pass end
		if state == Enum.UserInputState.Cancel then cancel(); return Enum.ContextActionResult.Sink end
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if input.UserInputType == Enum.UserInputType.MouseButton2 and state == Enum.UserInputState.Begin then
			hip = not hip
			tool:SetAttribute("GrenadeHip", hip)
			rotation += 180 -- Positive GUI rotation is clockwise, in both directions.
			if tween then tween:Cancel() end
			tween = TweenService:Create(arc, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Rotation = rotation })
			tween:Play()
			if winding then send("Aim") end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			if state == Enum.UserInputState.Begin and not winding and (tool:GetAttribute("Ammo") or 0) > 0 then
				winding = true
				tool:SetAttribute("GrenadeWinding", true)
				send("Prime")
			elseif state == Enum.UserInputState.End and winding then
				winding = false
				tool:SetAttribute("GrenadeWinding", false)
				send("Throw")
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 2, Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2)
	UserInputService.WindowFocusReleased:Connect(cancel)
	UserInputService.TextBoxFocused:Connect(cancel)
	GuiService.MenuOpened:Connect(cancel)
	player.CharacterRemoving:Connect(function() sync(nil) end)
	RunService:BindToRenderStep("RobostrikeGrenades", Enum.RenderPriority.Camera.Value + 1, function()
		local tool, definition = equipped()
		sync(tool)
		arc.Visible, status.Visible = tool ~= nil, tool ~= nil
		if not tool then return end
		status.Text = string.format("%s   ×%d\n%s · %s\nЛКМ держать — замах, отпустить — бросок · ПКМ — режим",
			definition.ModelName, tool:GetAttribute("Ammo") or 0, if hip then "От бедра · 5 м" else "От плеча · 15 м",
			if winding then "Чека снята" else "Готова")
		if winding and os.clock() - lastAim >= 0.1 then lastAim = os.clock(); send("Aim") end
	end)

	effects.OnClientEvent:Connect(function(position: Vector3)
		-- Cosmetic only: never use Roblox Explosion's built-in damage/joint breaking.
		local flash = Instance.new("Part")
		flash.Name, flash.Shape = "GrenadeFlash", Enum.PartType.Ball
		flash.Anchored = true
		flash.CanCollide, flash.CanTouch, flash.CanQuery = false, false, false
		flash.Material, flash.Color = Enum.Material.Neon, Color3.fromRGB(255, 171, 67)
		flash.Size, flash.Position, flash.Parent = Vector3.one, position, workspace
		TweenService:Create(flash, TweenInfo.new(0.3), { Size = Vector3.one * 9, Transparency = 1 }):Play()
		Debris:AddItem(flash, 0.35)
	end)
end

return Grenades
