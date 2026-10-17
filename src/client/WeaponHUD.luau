--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local HUD = {}

function HUD.new(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "RobostrikeHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = playerGui
	local vitals = Instance.new("TextLabel")
	vitals.Name = "Vitals"
	vitals.Position = UDim2.new(0, 16, 1, -55)
	vitals.Size = UDim2.fromOffset(320, 35)
	vitals.BackgroundTransparency = 1
	vitals.TextColor3 = Color3.fromRGB(232, 239, 244)
	vitals.TextStrokeTransparency = 0.4
	vitals.TextXAlignment = Enum.TextXAlignment.Left
	vitals.Font = Enum.Font.GothamMedium
	vitals.TextSize = 18
	vitals.Parent = gui
	local player = game:GetService("Players").LocalPlayer
	game:GetService("RunService").Heartbeat:Connect(function()
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		vitals.Visible = humanoid ~= nil and humanoid.Health > 0
		if humanoid and character then
			vitals.Text = string.format("HP %d   БРОНЯ %d%s", math.ceil(humanoid.Health),
				character:GetAttribute("Armor") or 0, if character:GetAttribute("Helmet") then " + КАСКА" else "")
		end
	end)

	local panel = Instance.new("Frame")
	panel.Name = "WeaponSelector"
	panel.Position = UDim2.fromOffset(16, 16)
	panel.Size = UDim2.fromOffset(270, 212)
	panel.BackgroundColor3 = Color3.fromRGB(16, 22, 28)
	panel.BackgroundTransparency = 0.12
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local rows: { TextLabel } = {}
	for slot, definition in Weapons do
		if slot > 4 then continue end
		local row = Instance.new("TextLabel")
		row.Name = "Slot" .. slot
		row.Position = UDim2.fromOffset(8, 8 + (slot - 1) * 50)
		row.Size = UDim2.new(1, -16, 0, 46)
		row.BorderSizePixel = 0
		row.Font = Enum.Font.GothamMedium
		row.TextSize = 16
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = string.format("  %d    %s", slot, if slot == 4 then "Гранаты 38 / 69" else definition.ModelName)
		row.Parent = panel
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 4)
		rowCorner.Parent = row
		rows[slot] = row
	end

	local generation = 0
	local controller = {}
	function controller:highlight(slot: number)
		for index, row in rows do
			local selected = index == slot
			row.BackgroundTransparency = if selected then 0 else 1
			row.BackgroundColor3 = Color3.fromRGB(46, 91, 108)
			row.TextColor3 = if selected then Color3.fromRGB(240, 252, 255) else Color3.fromRGB(157, 171, 180)
		end
	end
	function controller:hide()
		generation += 1
		panel.Visible = false
	end
	function controller:show(slot: number)
		generation += 1
		local current = generation
		self:highlight(slot)
		panel.Visible = true
		task.delay(Config.WeaponHUDDuration, function()
			if current == generation then
				panel.Visible = false
			end
		end)
	end
	return controller
end

return HUD
