--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local Rules = require(ReplicatedStorage.Shared.SessionRules)
local PoliceSkin = require(script.Parent.PoliceSkin)
local Loadout = require(script.Parent.Loadout)
local CharacterCollision = require(script.Parent.CharacterCollision)
local Session = {}

function Session.start(remotes: Folder, spawnPlayer: (Player, CFrame) -> Model?)
	local choose = Instance.new("RemoteEvent")
	choose.Name, choose.Parent = "ChooseTeam", remotes
	local menu = Instance.new("RemoteEvent")
	menu.Name, menu.Parent = "TeamMenu", remotes
	local death = Instance.new("RemoteEvent")
	death.Name, death.Parent = "SessionDeath", remotes
	local pose = Instance.new("RemoteEvent")
	pose.Name, pose.Parent = "SpectatorPose", remotes
	local lastPose: { [Player]: number } = {}
	pose.OnServerEvent:Connect(function(player, frame)
		if typeof(frame) ~= "CFrame" then return end
		local now = os.clock()
		if now - (lastPose[player] or 0) < 0.06 then return end
		lastPose[player] = now
		local model = player.Character
		local head = if model then model:FindFirstChild("Head") :: BasePart? else nil
		local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
		local id = player:GetAttribute("TeamId")
		if not head or not humanoid or humanoid.Health <= 0 or not id then return end
		for _, value in { frame:GetComponents() } do
			if value ~= value or math.abs(value) > 1e6 then return end
		end
		if (frame.Position - head.Position).Magnitude > 4 then return end
		for _, other in Players:GetPlayers() do
			if other ~= player and other:GetAttribute("TeamId") == id then pose:FireClient(other, model, frame) end
		end
	end)
	local state = Instance.new("Folder")
	state.Name, state.Parent = "SessionState", ReplicatedStorage
	local actors = Instance.new("Folder")
	actors.Name, actors.Parent = "SessionActors", workspace
	local slots: any = { Red = {}, Blue = {} }
	local teams: any = {}
	local generation, round = 0, 0
	local active, starting, mutating = false, false, false
	local template: Model? = nil
	local requests: { [Player]: number } = {}
	for _, id in { "Red", "Blue" } do
		local team = Instance.new("Team")
		team.Name, team.AutoAssignable = id, false
		team.TeamColor = BrickColor.new(Rules.Colors[id])
		team.Parent = Teams
		teams[id] = team
		state:SetAttribute(id .. "Wins", 0)
		for i = 1, Rules.TeamSize do slots[id][i] = {} end
	end
	state:SetAttribute("Phase", "WaitingAdmin")

	local function isAdmin(player: Player): boolean
		local id = if Rules.AdminUserId ~= 0 then Rules.AdminUserId else game.CreatorId
		local studioHost = RunService:IsStudio() and Rules.AdminUserId == 0
			and (game.CreatorId == 0 or player.UserId <= 0) and Players:GetPlayers()[1] == player
		return player.UserId == id or studioHost
	end
	local function adminPresent(): boolean
		for _, player in Players:GetPlayers() do if isAdmin(player) then return true end end
		return false
	end
	local function alive(model: Model?): boolean
		local h = if model then model:FindFirstChildOfClass("Humanoid") else nil
		return model ~= nil and model.Parent ~= nil and h ~= nil and h.Health > 0
	end
	local function lock(player: Player)
		local blocked = state:GetAttribute("Phase") ~= "Combat" or player:GetAttribute("TeamMenuOpen") == true
		player:SetAttribute("SessionBlocked", state:GetAttribute("Phase") ~= "Combat")
		local model = player.Character
		local root = if model then model:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if root and alive(model) then
			root.Anchored = blocked
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end
	local function phase(value: string, duration: number?)
		state:SetAttribute("Phase", value)
		state:SetAttribute("Deadline", workspace:GetServerTimeNow() + (duration or 0))
		for _, player in Players:GetPlayers() do lock(player) end
		for _, roster in slots do
			for _, slot in roster do
				if not slot.player and alive(slot.model) then
					local root = slot.model:FindFirstChild("HumanoidRootPart")
					if root then root.Anchored = value ~= "Combat" end
				end
			end
		end
	end
	local function decorate(model: Model, id: string, index: number, bot: boolean)
		model:SetAttribute("TeamId", id)
		model:SetAttribute("RosterIndex", index)
		model:SetAttribute("SessionActor", true)
		model:SetAttribute("Bot", bot)
		if not bot then
			local owner = Players:GetPlayerFromCharacter(model)
			local head = model:FindFirstChild("Head")
			if owner and head then
				local tag = Instance.new("BillboardGui")
				tag.Name, tag.Adornee = "PlayerNickname", head
				tag.Size, tag.StudsOffset = UDim2.fromOffset(140, 22), Vector3.new(0, 1.65, 0)
				tag.MaxDistance, tag.AlwaysOnTop, tag.LightInfluence = 70, false, 0.5
				tag.Parent = head
				local text = Instance.new("TextLabel")
				text.Size, text.BackgroundTransparency = UDim2.fromScale(1, 1), 1
				text.Font, text.TextSize = Enum.Font.GothamMedium, 12
				text.TextColor3, text.TextTransparency = Color3.fromRGB(205, 213, 223), 0.2
				text.TextStrokeTransparency, text.Text = 0.75, owner.Name
				text.Parent = tag
			end
		end
		for _, name in { "Left Arm", "Right Arm" } do
			local arm = model:FindFirstChild(name) :: BasePart?
			if arm then
				local band = Instance.new("Part")
				band.Name, band.Size = "TeamArmband", Vector3.new(1.09, 0.42, 1.09)
				band.Color = Rules.Colors[id]
				band.CanCollide, band.CanTouch, band.CanQuery, band.Massless = false, false, false, true
				band.CFrame, band.Parent = arm.CFrame * CFrame.new(0, 0.55, 0), model
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1, weld.Parent = arm, band, band
			end
		end
		local h = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		h.Died:Once(function()
			local tag = model:FindFirstChild("PlayerNickname", true)
			if tag then tag:Destroy() end
			if model.Parent then
				local head = model:FindFirstChild("Head") :: BasePart?
				if head then death:FireAllClients(head.Position) end
			end
		end)
	end
	local function makeBot(id: string, index: number): Model?
		if not template then return nil end
		local model = template:Clone()
		model.Name = id .. " Bot " .. index
		PoliceSkin.apply(model)
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
		root.Anchored = true
		model:PivotTo(Rules.spawn(id, index) * root.CFrame:Inverse() * model:GetPivot())
		local h = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		h.WalkSpeed, h.JumpPower = 16, 35
		h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		if not h:FindFirstChildOfClass("Animator") then Instance.new("Animator", h) end
		CharacterCollision.apply(model)
		model:SetAttribute("Armor", 0)
		model:SetAttribute("Helmet", false)
		decorate(model, id, index, true)
		model.Parent = actors
		local tool = Loadout.create(1)
		tool.Parent = model
		h:EquipTool(tool)
		return model
	end
	local function clearModels()
		for _, roster in slots do
			for _, slot in roster do
				if slot.model then slot.model:Destroy(); slot.model = nil end
			end
		end
	end
	local function hasHumans(): boolean
		for _, roster in slots do
			for _, slot in roster do if slot.player then return true end end
		end
		return false
	end
	local startRound: () -> ()
	startRound = function()
		if starting or not active or not hasHumans() then return end
		starting = true
		local token = generation
		phase("Preparing")
		clearModels()
		if not template then
			local description = PoliceSkin.description()
			local ok, result = pcall(function()
				return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)
			end)
			description:Destroy()
			if ok then
				template = result :: Model
				local animate = template:FindFirstChild("Animate")
				if animate then animate:Destroy() end
			else
				warn("[Session] Bot character creation failed: " .. tostring(result))
				starting = false
				if token == generation then phase("Lobby"); task.delay(3, startRound) end
				return
			end
		end
		for id, roster in slots do
			for index, slot in roster do
				if token ~= generation or not active then starting = false; return end
				local owner = slot.player
				local model = if owner then spawnPlayer(owner, Rules.spawn(id, index)) else makeBot(id, index)
				if token ~= generation or slot.player ~= owner then
					if model then model:Destroy() end
					starting = false
					if active and token == generation then phase("Lobby"); task.defer(startRound) end
					return
				end
				if not model then
					starting = false
					phase("Lobby")
					task.delay(3, startRound)
					return
				end
				slot.model = model
				if owner then decorate(model, id, index, false); lock(owner) end
			end
		end
		starting = false
		round += 1
		state:SetAttribute("Round", round)
		phase("Freeze", Rules.FreezeSeconds)
	end
	local function stop()
		active = false
		generation += 1
		phase("WaitingAdmin")
		clearModels()
		round = 0
		for id, roster in slots do
			state:SetAttribute(id .. "Wins", 0)
			for _, slot in roster do slot.player = nil end
		end
		for _, player in Players:GetPlayers() do
			player.Team = nil
			player:SetAttribute("TeamId", nil)
			player:SetAttribute("TeamMenuOpen", false)
		end
	end
	local function activate()
		if active or not adminPresent() then return end
		active = true
		phase("Lobby")
		for _, player in Players:GetPlayers() do player:SetAttribute("TeamMenuOpen", true) end
	end
	local function added(player: Player)
		player:SetAttribute("SessionBlocked", true)
		player:SetAttribute("TeamMenuOpen", active)
		activate()
	end
	Players.PlayerAdded:Connect(added)
	Players.PlayerRemoving:Connect(function(player)
		requests[player] = nil
		lastPose[player] = nil
		if isAdmin(player) then stop(); return end
		for id, roster in slots do
			for index, slot in roster do
				if slot.player == player then
					slot.player = nil
					local old = slot.model
					if active and alive(old) then
						local root = old:FindFirstChild("HumanoidRootPart") :: BasePart
						local bot = makeBot(id, index)
						if bot then
							bot:PivotTo(root.CFrame * (bot:FindFirstChild("HumanoidRootPart") :: BasePart).CFrame:Inverse() * bot:GetPivot())
							local h = bot:FindFirstChildOfClass("Humanoid") :: Humanoid
							h.Health = (old:FindFirstChildOfClass("Humanoid") :: Humanoid).Health
							bot:SetAttribute("Armor", old:GetAttribute("Armor") or 0)
							bot:SetAttribute("Helmet", old:GetAttribute("Helmet") == true)
							local botRoot = bot:FindFirstChild("HumanoidRootPart") :: BasePart
							botRoot.Anchored = state:GetAttribute("Phase") ~= "Combat"
						end
						slot.model = bot
					else slot.model = nil end
					if old then old:Destroy() end
				end
			end
		end
	end)
	menu.OnServerEvent:Connect(function(player, open)
		if not active or typeof(open) ~= "boolean" then return end
		if not open and not player:GetAttribute("TeamId") then return end
		player:SetAttribute("TeamMenuOpen", open)
		lock(player)
	end)
	choose.OnServerEvent:Connect(function(player, id)
		if not active or starting or mutating or (id ~= "Red" and id ~= "Blue") then return end
		if not player:GetAttribute("TeamMenuOpen") then return end
		local now = os.clock()
		if now - (requests[player] or -math.huge) < 0.5 then return end
		requests[player] = now
		local previous = player:GetAttribute("TeamId")
		local destination: any = nil
		local index = 0
		for i, slot in slots[id] do
			if slot.player == player then destination, index = slot, i; break end
			if not slot.player and (not destination or alive(slot.model)) then destination, index = slot, i end
		end
		if not destination then player:SetAttribute("TeamMenuError", "Команда заполнена"); return end
		player:SetAttribute("TeamMenuError", nil)
		-- All roster mutations happen before yielding to character creation.
		mutating = true
		local inherited = destination.model
		local canEnter = previous == nil and alive(inherited) and state:GetAttribute("Phase") ~= "Intermission"
		local frame = if canEnter then (inherited:FindFirstChild("HumanoidRootPart") :: BasePart).CFrame else Rules.spawn(id, index)
		local health = if canEnter then (inherited:FindFirstChildOfClass("Humanoid") :: Humanoid).Health else 100
		local armor = if canEnter then inherited:GetAttribute("Armor") or 0 else 0
		local helmet = canEnter and inherited:GetAttribute("Helmet") == true
		local inventory: any = {}
		if canEnter then
			for _, child in inherited:GetChildren() do
				if child:IsA("Tool") then
					inventory[child:GetAttribute("WeaponSlot")] = { Ammo = child:GetAttribute("Ammo"), ReserveAmmo = child:GetAttribute("ReserveAmmo") }
				end
			end
		end
		for _, roster in slots do
			for _, slot in roster do
				if slot.player == player then
					if alive(slot.model) then (slot.model:FindFirstChildOfClass("Humanoid") :: Humanoid).Health = 0 end
					slot.player = nil
				end
			end
		end
		if destination.model then destination.model:Destroy(); destination.model = nil end
		destination.player = player
		player.Team = teams[id]
		player:SetAttribute("TeamId", id)
		player:SetAttribute("TeamMenuOpen", false)
		lock(player)
		local token = generation
		if canEnter then
			local model = spawnPlayer(player, frame)
			if model and token == generation and destination.player == player then
				destination.model = model
				decorate(model, id, index, false)
				local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
				humanoid.Health = health
				model:SetAttribute("Armor", armor)
				model:SetAttribute("Helmet", helmet)
				for weaponSlot, attributes in inventory do
					local tool = Loadout.find(player, weaponSlot)
					if tool then for name, value in attributes do tool:SetAttribute(name, value) end end
				end
				lock(player)
			elseif model then model:Destroy() end
		end
		mutating = false
		if active and state:GetAttribute("Phase") == "Lobby" then task.spawn(startRound) end
	end)
	require(script.Parent.Bots).start(slots, state, remotes)
	RunService.Heartbeat:Connect(function()
		if not active or starting or mutating then return end
		local current = state:GetAttribute("Phase")
		local expired = workspace:GetServerTimeNow() >= (state:GetAttribute("Deadline") or math.huge)
		if current == "Freeze" and expired then phase("Combat") end
		if current == "Intermission" and expired then task.spawn(startRound) end
		if current ~= "Combat" then return end
		local living = { Red = 0, Blue = 0 }
		for id, roster in slots do
			for _, slot in roster do if alive(slot.model) then living[id] += 1 end end
		end
		if living.Red == 0 or living.Blue == 0 then
			local winner = if living.Red == living.Blue then "Draw" elseif living.Red > 0 then "Red" else "Blue"
			state:SetAttribute("Winner", winner)
			if winner ~= "Draw" then state:SetAttribute(winner .. "Wins", state:GetAttribute(winner .. "Wins") + 1) end
			phase("Intermission", Rules.IntermissionSeconds)
		end
	end)
	for _, player in Players:GetPlayers() do added(player) end
end

return Session
