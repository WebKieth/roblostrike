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
		local row = Instance.new("TextLabel")
		row.Name = "Slot" .. slot
		row.Position = UDim2.fromOffset(8, 8 + (slot - 1) * 50)
		row.Size = UDim2.new(1, -16, 0, 46)
		row.BorderSizePixel = 0
		row.Font = Enum.Font.GothamMedium
		row.TextSize = 16
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = string.format("  %d    %s", slot, definition.Name)
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
