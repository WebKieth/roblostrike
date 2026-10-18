--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.MapCatalog)
local MapSelect = {}

function MapSelect.new(parent: Instance, position: UDim2, changed: (string) -> ())
	local selected = Catalog.DefaultId
	local button = Instance.new("TextButton")
	button.Name = "MapSelect"
	button.Position, button.Size = position, UDim2.new(0.9, 0, 0, 36)
	button.BackgroundColor3, button.TextColor3 = Color3.fromRGB(37, 49, 65), Color3.new(1, 1, 1)
	button.Font, button.TextSize, button.ZIndex = Enum.Font.GothamMedium, 16, 10
	button.Parent = parent
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)
	local list = Instance.new("Frame")
	list.Name, list.Position, list.Size = "MapOptions", UDim2.fromOffset(0, 38), UDim2.new(1, 0, 0, #Catalog.Entries * 36)
	list.BackgroundColor3, list.Visible, list.ZIndex, list.Parent = Color3.fromRGB(28, 37, 51), false, 11, button
	local function set(id: string, enabled: boolean)
		local entry = Catalog.find(id) or Catalog.Entries[1]
		selected = entry.Id
		button.Text = "Карта: " .. entry.Name .. (if enabled then "  ▾" else "")
		button.Interactable = enabled
		if not enabled then list.Visible = false end
	end
	for index, entry in Catalog.Entries do
		local option = Instance.new("TextButton")
		option.Name, option.Text = entry.Id, entry.Name
		option.Position, option.Size = UDim2.fromOffset(0, (index - 1) * 36), UDim2.new(1, 0, 0, 36)
		option.Font, option.TextSize, option.ZIndex = Enum.Font.GothamMedium, 16, 12
		option.BackgroundColor3, option.TextColor3, option.Parent = Color3.fromRGB(37, 49, 65), Color3.new(1, 1, 1), list
		option.Activated:Connect(function()
			if not button.Interactable then return end
			set(entry.Id, true)
			list.Visible = false
			changed(selected)
		end)
	end
	button.Activated:Connect(function() if button.Interactable then list.Visible = not list.Visible end end)
	set(selected, true)
	return { Set = set, Close = function() list.Visible = false end }
end

return MapSelect
