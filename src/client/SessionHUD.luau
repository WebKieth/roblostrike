--!strict
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Rules = require(ReplicatedStorage.Shared.SessionRules)
local Animation = require(script.Parent.CharacterAnimation)
local Audio = require(script.Parent.AudioSettings)
local SessionMusic = require(script.Parent.SessionMusic)
local SessionHUD = {}

function SessionHUD.start(player: Player)
	local state = ReplicatedStorage:WaitForChild("SessionState")
	SessionMusic.start(state)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	require(script.Parent.ServerBrowser).start(player, remotes)
	local choose = remotes:WaitForChild("ChooseTeam") :: RemoteEvent
	local menu = remotes:WaitForChild("TeamMenu") :: RemoteEvent
	local setup = remotes:WaitForChild("SessionSetup") :: RemoteEvent
	local pose = remotes:WaitForChild("SpectatorPose") :: RemoteEvent
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.DisplayOrder = "SessionHUD", false, true, 20
	gui.Parent = player:WaitForChild("PlayerGui")
	local function label(parent: Instance, size: UDim2, position: UDim2, textSize: number): TextLabel
		local text = Instance.new("TextLabel")
		text.Size, text.Position, text.BackgroundTransparency = size, position, 1
		text.Font, text.TextSize = Enum.Font.GothamBold, textSize
		text.TextColor3, text.TextStrokeTransparency = Color3.fromRGB(238, 243, 250), 0.65
		text.Text, text.Parent = "", parent
		return text
	end
	local score = label(gui, UDim2.fromOffset(270, 52), UDim2.new(1, -294, 0, 64), 22)
	score.BackgroundColor3, score.BackgroundTransparency = Color3.fromRGB(15, 20, 30), 0.2
	score.RichText = true
	Instance.new("UICorner", score).CornerRadius = UDim.new(0, 8)
	local banner = label(gui, UDim2.new(1, 0, 0, 72), UDim2.new(0, 0, 0, 100), 26)
	local spectator = label(gui, UDim2.new(1, -40, 0, 50), UDim2.new(0, 20, 1, -115), 18)
	local hint = label(gui, UDim2.fromOffset(270, 28), UDim2.new(1, -294, 0, 118), 13)
	hint.Text = "M — выбор команды"
	local overlay = Instance.new("Frame")
	overlay.Size, overlay.BackgroundColor3, overlay.BackgroundTransparency = UDim2.fromScale(1, 1), Color3.fromRGB(6, 10, 19), 0.25
	overlay.Parent = gui
	local panel = Instance.new("Frame")
	panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.new(0.9, 0, 0, 310)
	panel.BackgroundColor3, panel.Parent = Color3.fromRGB(20, 27, 40), overlay
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize, constraint.Parent = Vector2.new(640, 310), panel
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
	local title = label(panel, UDim2.new(1, -24, 0, 50), UDim2.fromOffset(12, 22), 30)
	title.Text = "ROBOSTRIKE"
	local subtitle = label(panel, UDim2.new(1, -24, 0, 40), UDim2.fromOffset(12, 74), 16)
	local footnote = label(panel, UDim2.new(1, -32, 0, 70), UDim2.new(0, 16, 1, -82), 14)
	footnote.TextWrapped = true
	local buttons: { [string]: TextButton } = {}
	for index, id in { "Red", "Blue" } do
		local button = Instance.new("TextButton")
		button.Position, button.Size = UDim2.new(if index == 1 then 0.05 else 0.525, 0, 0, 132), UDim2.new(0.425, 0, 0, 78)
		button.BackgroundColor3, button.TextColor3 = Rules.Colors[id], Color3.new(1, 1, 1)
		button.Font, button.TextSize, button.Modal = Enum.Font.GothamBold, 20, true
		button.Parent = panel
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
		button.Activated:Connect(function() choose:FireServer(id) end)
		buttons[id] = button
	end
	local setupPanel = Instance.new("Frame")
	setupPanel.Name, setupPanel.Size, setupPanel.Position = "SessionSetup", UDim2.new(1, 0, 0, 142), UDim2.fromOffset(0, 222)
	setupPanel.BackgroundTransparency, setupPanel.Parent = 1, panel
	local botCount = label(setupPanel, UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 0), 15)
	local botButtons: { [number]: TextButton } = {}
	for count = 0, Rules.TeamSize do
		local b = Instance.new("TextButton")
		b.Size, b.Position = UDim2.new(0.2, 0, 0, 32), UDim2.new(0.05 + count * 0.225, 0, 0, 32)
		b.Text, b.Font, b.TextSize = if count == 0 then "Без ботов" else tostring(count), Enum.Font.GothamMedium, 15
		b.TextColor3, b.Parent = Color3.fromRGB(235, 242, 250), setupPanel
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
		b.Activated:Connect(function() setup:FireServer("Bots", count) end)
		botButtons[count] = b
	end
	local start = Instance.new("TextButton")
	start.Size, start.Position = UDim2.new(0.9, 0, 0, 40), UDim2.new(0.05, 0, 0, 82)
	start.Font, start.TextSize = Enum.Font.GothamBold, 17
	start.BackgroundColor3, start.TextColor3, start.Parent = Color3.fromRGB(49, 130, 93), Color3.new(1, 1, 1), setupPanel
	Instance.new("UICorner", start).CornerRadius = UDim.new(0, 8)
	start.Activated:Connect(function() setup:FireServer(if state:GetAttribute("Started") then "Restart" else "Start") end)
	local leave = Instance.new("TextButton")
	leave.Size, leave.Position = UDim2.fromOffset(180, 30), UDim2.new(0.5, -90, 1, 8)
	leave.Text, leave.Font, leave.TextSize = "Выйти с сервера", Enum.Font.GothamMedium, 14
	leave.BackgroundColor3, leave.TextColor3, leave.Parent = Color3.fromRGB(80, 43, 48), Color3.new(1, 1, 1), panel
	local leaving = false
	leave.Activated:Connect(function()
		if leaving then return end
		leaving = true
		local ok, result = pcall(function() return (remotes:WaitForChild("ServerDirectory") :: RemoteFunction):InvokeServer("Leave") end)
		if not ok or (result and result.error) then leave.Text = "Повторить выход" end
		leaving = false
	end)
	ContextActionService:BindActionAtPriority("RobostrikeTeamMenu", function(_, inputState)
		if player:GetAttribute("SettingsOpen") then return Enum.ContextActionResult.Sink end
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if inputState == Enum.UserInputState.Begin then menu:FireServer(not player:GetAttribute("TeamMenuOpen")) end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.M)

	local function mute(instance: Instance)
		if instance:IsA("Sound") and instance.Name == "Died" then
			instance.Volume = 0
			instance:GetPropertyChangedSignal("Volume"):Connect(function() if instance.Volume ~= 0 then instance.Volume = 0 end end)
		end
	end
	workspace.DescendantAdded:Connect(mute)
	for _, instance in workspace:GetDescendants() do mute(instance) end
	(remotes:WaitForChild("SessionDeath") :: RemoteEvent).OnClientEvent:Connect(function(position: Vector3)
		local emitter = Instance.new("Part")
		emitter.Anchored, emitter.CanCollide, emitter.CanTouch, emitter.CanQuery, emitter.Transparency = true, false, false, false, 1
		emitter.Position, emitter.Parent = position, workspace
		local sound = Instance.new("Sound")
		sound.SoundId, sound.Volume, sound.RollOffMaxDistance = Rules.WilhelmSoundId, 0.64, 110
		Audio.assign(sound, "Characters")
		sound.Parent = emitter
		sound:Play()
		Debris:AddItem(emitter, 8)
	end)
	local actors = workspace:WaitForChild("SessionActors")
	local function animateBot(instance: Instance)
		if instance:IsA("Model") then
			task.spawn(function()
				local humanoid = instance:WaitForChild("Humanoid", 10)
				if humanoid and humanoid:WaitForChild("Animator", 10) and instance.Parent then Animation.start(instance) end
			end)
		end
	end
	actors.ChildAdded:Connect(animateBot)
	for _, model in actors:GetChildren() do animateBot(model) end
	local poses: { [Model]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
	pose.OnClientEvent:Connect(function(model: Model, frame: CFrame) poses[model] = frame end)
	local target: Model? = nil
	local hidden: { [BasePart]: number } = {}
	local function restore()
		for part, transparency in hidden do if part.Parent then part.LocalTransparencyModifier = transparency end end
		table.clear(hidden)
		local tag = if target then target:FindFirstChild("PlayerNickname", true) else nil
		if tag and tag:IsA("BillboardGui") then tag.Enabled = true end
	end
	local function living(model: Model?): boolean
		local h = if model then model:FindFirstChildOfClass("Humanoid") else nil
		return model ~= nil and model.Parent ~= nil and h ~= nil and h.Health > 0
	end
	local function pickTarget(): Model?
		local id = player:GetAttribute("TeamId")
		if not id then return nil end
		local humans = Players:GetPlayers()
		table.sort(humans, function(a, b) return a.UserId < b.UserId end)
		local own = table.find(humans, player) or 1
		for offset = 1, #humans do
			local other = humans[(own + offset - 1) % #humans + 1]
			if other ~= player and other:GetAttribute("TeamId") == id and living(other.Character) then return other.Character end
		end
		for _, bot in actors:GetChildren() do
			if bot:IsA("Model") and bot:GetAttribute("TeamId") == id and living(bot) then return bot end
		end
		return nil
	end
	local sentAt = 0
	RunService:BindToRenderStep("RobostrikeSessionHUD", Enum.RenderPriority.Camera.Value + 5, function()
		local current = state:GetAttribute("Phase")
		local browsing = player:GetAttribute("InSession") ~= true
		local configuring = not browsing and current == "Lobby" and state:GetAttribute("Started") ~= true
		local admin = player:GetAttribute("SessionAdmin") == true
		local bots = state:GetAttribute("BotsPerTeam") or Rules.TeamSize
		local open = (player:GetAttribute("TeamMenuOpen") == true or configuring) and not browsing
		local restarting = admin and open and not configuring and state:GetAttribute("Started") == true
		local editable = (configuring or restarting) and current ~= "Preparing"
		if restarting then bots = state:GetAttribute("PendingBotsPerTeam") or bots end
		local height = if configuring or restarting then 460 else 310
		panel.Size, constraint.MaxSize = UDim2.new(0.9, 0, 0, height), Vector2.new(640, height)
		setupPanel.Visible = configuring or restarting
		botCount.Text = if bots == 0 then "Без ботов · бесконечная сессия" else string.format("До %d ботов на команду · до %d участников на сторону", bots, Rules.TeamSize)
		botCount.TextScaled = true
		for count, b in botButtons do
			b.Interactable = admin and editable
			b.BackgroundColor3 = if count == bots then Color3.fromRGB(51, 130, 191) else Color3.fromRGB(37, 49, 65)
		end
		start.Interactable = admin and editable
		start.Text = if restarting then "ПЕРЕЗАПУСТИТЬ СЕССИЮ" elseif admin then "НАЧАТЬ СЕССИЮ" else "ОЖИДАНИЕ СОЗДАТЕЛЯ"
		overlay.Visible, hint.Visible, score.Visible, banner.Visible = open, not browsing, not browsing, not browsing
		UserInputService.MouseIconEnabled = open or browsing
		if open or browsing then UserInputService.MouseBehavior = Enum.MouseBehavior.Default end
		score.Text = string.format('<font color="#E24146">КРАСНЫЕ  %d</font>  :  <font color="#4191F5">%d  СИНИЕ</font>', state:GetAttribute("RedWins") or 0, state:GetAttribute("BlueWins") or 0)
		subtitle.Text = string.format("%s · бой %d × %d", state:GetAttribute("ServerName") or "Выбери команду", Rules.TeamSize, Rules.TeamSize)
		footnote.Text = player:GetAttribute("TeamMenuError") or state:GetAttribute("SetupError") or (if configuring then (if bots == 0 then "Выбери команду — можно играть одному. Другие игроки смогут найти сервер и подключиться позже."
				else "Выберите команды. Боты займут свободные места. Количество ботов задаёт создатель сервера.")
			elseif restarting then "Выбери команду и количество ботов. Перезапуск сбросит счёт и вернёт всех на спавн.\nБез перезапуска новые настройки не применяются. M — закрыть."
			elseif player:GetAttribute("TeamId") then "Выбор любой команды = смерть и наблюдение до нового раунда.\nM — закрыть меню. Пока меню открыто, тебя могут убить."
			elseif bots == 0 then "Выбери свободную команду, чтобы сразу подключиться к игре."
			else "Ты займёшь место бота. Если он погиб — вступишь в следующем раунде.")
		for id, button in buttons do
			local count = 0
			for _, other in Players:GetPlayers() do if other:GetAttribute("TeamId") == id then count += 1 end end
			button.Visible = true
			button.Interactable = current ~= "Preparing" and (count < Rules.TeamSize or player:GetAttribute("TeamId") == id)
			button.Text = string.format("%s\n%d / %d игроков", if id == "Red" then "КРАСНЫЕ" else "СИНИЕ", count, Rules.TeamSize)
		end
		local remaining = math.max(0, math.ceil((state:GetAttribute("Deadline") or 0) - workspace:GetServerTimeNow()))
		banner.Text = if current == "Freeze" then "БОЙ ЧЕРЕЗ " .. remaining
			elseif current == "Preparing" then "Подготовка раунда…"
			elseif current == "Intermission" then (if state:GetAttribute("Winner") == "Draw" then "НИЧЬЯ" elseif state:GetAttribute("Winner") == "Red" then "ПОБЕДА КРАСНЫХ" else "ПОБЕДА СИНИХ") .. " · " .. remaining
			elseif current == "Lobby" then (if configuring then "Настройка сессии · выберите команды" else "Ожидание игроков в обеих командах") else ""
		local camera = workspace.CurrentCamera
		if not camera then return end
		for _, other in Players:GetPlayers() do
			local tag = if other.Character then other.Character:FindFirstChild("PlayerNickname", true) else nil
			if tag and tag:IsA("BillboardGui") then tag.Enabled = other ~= player and other.Character ~= target end
		end
		if living(player.Character) then
			if target then restore(); target = nil end
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
			spectator.Text = ""
			if os.clock() - sentAt > 0.08 then sentAt = os.clock(); pose:FireServer(camera.CFrame) end
			return
		end
		local nextTarget = pickTarget()
		if nextTarget ~= target then restore(); target = nextTarget end
		if target then
			local head = target:FindFirstChild("Head") :: BasePart?
			if head then
				camera.CameraType = Enum.CameraType.Scriptable
				camera.CFrame = poses[target] or CFrame.new(head.Position) * (target:FindFirstChild("HumanoidRootPart") :: BasePart).CFrame.Rotation
				for _, descendant in target:GetDescendants() do
					if descendant:IsA("BasePart") and (descendant.Name == "Head" or descendant:FindFirstAncestorOfClass("Accessory") or descendant.Name == "PoliceCap" or descendant.Position.Y > head.Position.Y - 0.5) then
						if hidden[descendant] == nil then hidden[descendant] = descendant.LocalTransparencyModifier end
						descendant.LocalTransparencyModifier = 1
					end
				end
			end
			spectator.Text = "НАБЛЮДЕНИЕ · " .. target.Name .. " · M — команда"
		else
			spectator.Text = if not player:GetAttribute("TeamId") then ""
				elseif state:GetAttribute("BotsPerTeam") == 0 then "Нет живых союзников · M — меню перезапуска сессии"
				else "Нет живых союзников · ожидание нового раунда"
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(Vector3.new(-12, 28, -37), Vector3.new(-12, 0, -37))
		end
	end)
end

return SessionHUD
