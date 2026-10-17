--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local HUD = require(script.WeaponHUD)
local Viewmodel = require(script.Viewmodel)
local Animation = require(script.CharacterAnimation)
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local equip = remotes:WaitForChild("EquipWeapon") :: RemoteEvent
local movement = remotes:WaitForChild("SetMovement") :: RemoteEvent

local hud = HUD.new(player:WaitForChild("PlayerGui") :: PlayerGui)
player.CameraMode = Enum.CameraMode.LockFirstPerson
UserInputService.MouseIconEnabled = false

-- CoreGui may not be ready on the first frame. Do not leave a second hotbar.
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then
			return
		end
		task.wait(0.25)
	end
end)

local walkingKeys: { [Enum.KeyCode]: boolean } = {}
local crouching = false
local selectedSlot = player:GetAttribute("SelectedSlot") or 1
local lastSelection = 0

local function sendMovement()
	movement:FireServer(next(walkingKeys) ~= nil, crouching)
end

local function resetMovement()
	table.clear(walkingKeys)
	crouching = false
	sendMovement()
end

local function selectSlot(slot: number)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 or slot == selectedSlot then
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
	if not pressed and state ~= Enum.UserInputState.End then
		return Enum.ContextActionResult.Sink
	end
	if pressed and UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	if input.KeyCode == Enum.KeyCode.RightControl then
		crouching = pressed
	else
		walkingKeys[input.KeyCode] = if pressed then true else nil
	end
	sendMovement()
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift,
	Enum.KeyCode.RightControl)

local slotKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
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
		selectSlot((selectedSlot - 1 + direction) % 4 + 1)
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
if player.Character then
	task.spawn(onCharacter, player.Character)
end
Viewmodel.start(player)

task.spawn(function()
	local folder = workspace:WaitForChild("FyPoolDay"):WaitForChild("Water")
	local Water = require(ReplicatedStorage.Shared.Water)
	local pools = Water.pools(folder)
	require(script.WaterSurface).start(folder, pools)
	require(script.Swimming).start(player, pools)
end)

print(string.format("[%s] First-person client ready", Config.GameName))
