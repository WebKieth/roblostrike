--!strict

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Rules = require(ReplicatedStorage.Shared.Knife)
local Knife = {}

function Knife.start(player: Player, combat: any)
	local action = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("KnifeAction") :: RemoteEvent
	local current: Tool? = nil
	local mode: string? = nil
	local started, due, lastAim = 0, 0, 0
	local slashHeld, stabHeld = false, false
	local function equipped(): Tool?
		if player:GetAttribute("SessionBlocked") or player:GetAttribute("TeamMenuOpen") or player:GetAttribute("SettingsOpen") then return nil end
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local tool = if character then character:FindFirstChildOfClass("Tool") else nil
		local slot = if tool then tool:GetAttribute("WeaponSlot") else nil
		local definition = if typeof(slot) == "number" then Weapons[slot] else nil
		return if humanoid and humanoid.Health > 0 and definition and definition.Knife then tool else nil
	end
	local function cancel()
		if mode then action:FireServer("Cancel") end
		mode = nil
		slashHeld, stabHeld = false, false
		combat.KnifePose = CFrame.identity
	end
	UserInputService.WindowFocusReleased:Connect(cancel)
	UserInputService.TextBoxFocused:Connect(cancel)
	GuiService.MenuOpened:Connect(cancel)
	player:GetAttributeChangedSignal("SettingsOpen"):Connect(cancel)
	player.CharacterRemoving:Connect(cancel)
	local function begin(kind: string)
		local camera = workspace.CurrentCamera
		local now = os.clock()
		if not camera or now < due then return end
		mode, started, due, lastAim = kind, now, now + Rules[kind].Duration, now
		action:FireServer(kind, camera.CFrame.LookVector)
	end
	ContextActionService:BindActionAtPriority("RobostrikeKnife", function(_, state, input)
		local tool = equipped()
		if tool ~= current then cancel(); current = tool end
		if not tool then return Enum.ContextActionResult.Pass end
		if state == Enum.UserInputState.Cancel then cancel(); return Enum.ContextActionResult.Sink end
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		local pressed = state == Enum.UserInputState.Begin
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			slashHeld = pressed
			if pressed then begin("Slash") end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			stabHeld = pressed
			if pressed then begin("Stab") end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 3,
		Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2)
	RunService:BindToRenderStep("RobostrikeKnife", Enum.RenderPriority.Camera.Value + 1, function()
		local tool = equipped()
		if tool ~= current then cancel(); current = tool end
		if not tool then return end
		local now = os.clock()
		if now >= due then
			mode = nil
			if stabHeld then begin("Stab") elseif slashHeld then begin("Slash") end
		end
		combat.KnifePose = if mode then Rules.pose(mode, now - started) else CFrame.identity
		local camera = workspace.CurrentCamera
		if mode and camera and now - lastAim >= 1 / 30 then
			lastAim = now
			action:FireServer("Aim", camera.CFrame.LookVector)
		end
	end)
end

return Knife
