--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local SessionRules = require(ReplicatedStorage.Shared.SessionRules)
local HUD = require(script.WeaponHUD)
local Viewmodel = require(script.Viewmodel)
local Animation = require(script.CharacterAnimation)
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local equip = remotes:WaitForChild("EquipWeapon") :: RemoteEvent
local movement = remotes:WaitForChild("SetMovement") :: RemoteEvent
local drop = remotes:WaitForChild("DropWeapon") :: RemoteEvent

require(script.MovementInput).start(player)
require(script.SettingsUI).start(player)
require(script.FirstPersonVisibility).start(player)
-- The selectable arenas currently have neither pools nor mirrors.

local hud = HUD.new(player:WaitForChild("PlayerGui") :: PlayerGui)
player.CameraMode = Enum.CameraMode.LockFirstPerson
UserInputService.MouseIconEnabled = false

-- CoreGui may not be ready on the first frame. Do not leave a second hotbar.
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		if ok then
			return
		end
		task.wait(0.25)
	end
end)

local walkingKeys: { [Enum.KeyCode]: boolean } = {}
local crouchKeys: { [Enum.KeyCode]: boolean } = {}
local crouching = false
local selectedSlot = player:GetAttribute("SelectedSlot") or 1
local lastSelection = 0

local function sendMovement()
	movement:FireServer(next(walkingKeys) ~= nil, crouching)
end

local function resetMovement()
	table.clear(walkingKeys)
	table.clear(crouchKeys)
	crouching = false
	sendMovement()
end
player:GetAttributeChangedSignal("SettingsOpen"):Connect(function()
	if player:GetAttribute("SettingsOpen") then resetMovement() end
end)

local function hasGrenades(): boolean
	for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		if not container then continue end
		for _, tool in container:GetChildren() do
			if tool:IsA("Tool") then
				local id = tool:GetAttribute("WeaponSlot")
				if (id == 4 or id == 5) and (tool:GetAttribute("Ammo") or 0) > 0 then return true end
			end
		end
	end
	return false
end

local function selectSlot(slot: number)
	if SessionRules.blocked(player) then return end
	if slot == 4 and not hasGrenades() then return end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 or (slot == selectedSlot and slot ~= 4) then
		return
	end
	if os.clock() - lastSelection < 0.08 then
		return
	end
	lastSelection = os.clock()
	selectedSlot = slot
	hud:show(slot)
	equip:FireServer(slot)
end

ContextActionService:BindActionAtPriority("RobostrikeStance", function(_, state, input)
	if state == Enum.UserInputState.Cancel then
		resetMovement()
		return Enum.ContextActionResult.Sink
	end
	local pressed = state == Enum.UserInputState.Begin
	if pressed and player:GetAttribute("SettingsOpen") then return Enum.ContextActionResult.Pass end
	if not pressed and state ~= Enum.UserInputState.End then
		return Enum.ContextActionResult.Sink
	end
	if pressed and UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl
		or input.KeyCode == Enum.KeyCode.RightControl then
		crouchKeys[input.KeyCode] = if pressed then true else nil
		crouching = next(crouchKeys) ~= nil
	else
		walkingKeys[input.KeyCode] = if pressed then true else nil
	end
	sendMovement()
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift,
	Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl)

local slotKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
ContextActionService:BindAction("RobostrikeDrop", function(_, state)
	if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin and not SessionRules.blocked(player) then drop:FireServer() end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.G)

ContextActionService:BindActionAtPriority("RobostrikeWeapons", function(_, state, input)
	if UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		local slot = table.find(slotKeys, input.KeyCode)
		if slot then
			selectSlot(slot)
		end
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, table.unpack(slotKeys))

UserInputService.InputChanged:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseWheel and input.Position.Z ~= 0 then
		local direction = if input.Position.Z > 0 then -1 else 1
		local slot = (selectedSlot - 1 + direction) % #slotKeys + 1
		if slot == 4 and not hasGrenades() then slot = (slot - 1 + direction) % #slotKeys + 1 end
		selectSlot(slot)
	end
end)
UserInputService.WindowFocusReleased:Connect(resetMovement)
UserInputService.TextBoxFocused:Connect(resetMovement)
player:GetAttributeChangedSignal("SelectedSlot"):Connect(function()
	selectedSlot = player:GetAttribute("SelectedSlot") or 1
	hud:highlight(selectedSlot)
end)

local function onCharacter(character: Model)
	hud:hide()
	selectedSlot = player:GetAttribute("SelectedSlot") or 1
	resetMovement()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if player.Character ~= character then
		return
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraSubject = humanoid
	end
	Animation.start(character)
	humanoid.Died:Once(function()
		hud:hide()
		resetMovement()
	end)
end
player.CharacterAdded:Connect(onCharacter)
-- Procedural poses are local to each observer, including other human players.
local function watchAnimations(other: Player)
	if other == player then return end
	local function start(character: Model)
		character:WaitForChild("Humanoid")
		character:WaitForChild("Torso")
		character:WaitForChild("HumanoidRootPart")
		if character.Parent then Animation.start(character) end
	end
	other.CharacterAdded:Connect(start)
	if other.Character then task.spawn(start, other.Character) end
end
Players.PlayerAdded:Connect(watchAnimations)
for _, other in Players:GetPlayers() do watchAnimations(other) end
if player.Character then
	task.spawn(onCharacter, player.Character)
end
local combat = require(script.Combat).start(player)
require(script.Knife).start(player, combat)
require(script.Grenades).start(player)
require(script.DamageNumbers).start()
Viewmodel.start(player, combat)
task.spawn(require(script.SessionHUD).start, player)

print(string.format("[%s] First-person client ready", Config.GameName))
