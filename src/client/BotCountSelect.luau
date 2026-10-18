--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.SessionRules)
local BotCountSelect = {}

function BotCountSelect.new(parent: Instance, changed: (number) -> ())
	local button = Instance.new("TextButton")
	button.Name, button.Position, button.Size = "BotCountSelect", UDim2.new(0.05, 0, 0, 32), UDim2.new(0.9, 0, 0, 32)
	button.BackgroundColor3, button.TextColor3 = Color3.fromRGB(37, 49, 65), Color3.new(1, 1, 1)
	button.Font, button.TextSize, button.ZIndex = Enum.Font.GothamMedium, 15, 15
	button.Parent = parent
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)
	local list = Instance.new("ScrollingFrame")
	list.Name, list.Position, list.Size = "BotCountOptions", UDim2.fromOffset(0, 34), UDim2.new(1, 0, 0, 180)
	list.CanvasSize, list.ScrollBarThickness = UDim2.fromOffset(0, (Rules.MaxBotsPerTeam + 1) * 30), 5
	list.BackgroundColor3, list.BorderSizePixel = Color3.fromRGB(28, 37, 51), 0
	list.Visible, list.ZIndex, list.Parent = false, 16, button
	local options: { TextButton } = {}
	local function set(count: number, enabled: boolean)
		button.Text = (if count == 0 then "Без ботов" else string.format("До %d ботов на сторону", count)) .. (if enabled then "  ▾" else "")
		button.Interactable = enabled
		for _, option in options do option.Interactable = enabled end
		if not enabled then list.Visible = false end
	end
	for count = 0, Rules.MaxBotsPerTeam do
		local option = Instance.new("TextButton")
		option.Name, option.Text = "Bots" .. count, if count == 0 then "Без ботов" else string.format("%d × %d", count, count)
		option.Position, option.Size = UDim2.fromOffset(0, count * 30), UDim2.new(1, -6, 0, 30)
		option.Font, option.TextSize, option.ZIndex = Enum.Font.GothamMedium, 15, 17
		option.BackgroundColor3, option.TextColor3, option.Parent = Color3.fromRGB(37, 49, 65), Color3.new(1, 1, 1), list
		table.insert(options, option)
		option.Activated:Connect(function()
			if not button.Interactable then return end
			set(count, true)
			list.Visible = false
			changed(count)
		end)
	end
	button.Activated:Connect(function() if button.Interactable then list.Visible = not list.Visible end end)
	set(Rules.TeamSize, true)
	return { Set = set, Close = function() list.Visible = false end }
end

return BotCountSelect
