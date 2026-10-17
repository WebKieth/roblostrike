--!strict

local Players = game:GetService("Players")
local TrainingDummy = {}

function TrainingDummy.spawn()
	task.spawn(function()
		local description = Instance.new("HumanoidDescription")
		local ok, result = pcall(function()
			return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)
		end)
		description:Destroy()
		if not ok then warn("[Robostrike] Training dummy: " .. tostring(result)); return end
		local model = result :: Model
		model.Name = "Бессмертный манекен"
		model:SetAttribute("Immortal", true)
		model:SetAttribute("Armor", 0)
		model:SetAttribute("Helmet", false)
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.MaxHealth, humanoid.Health = 100, 100
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
		root.Anchored = true
		model:PivotTo(CFrame.new(-12, 3.1, 1) * root.CFrame:Inverse() * model:GetPivot())
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part ~= root then
				part.Color = Color3.fromRGB(218, 147, 60)
				part.Material = Enum.Material.SmoothPlastic
			end
		end
		local label = Instance.new("BillboardGui")
		label.Size = UDim2.fromOffset(210, 32)
		label.StudsOffset = Vector3.new(0, 2, 0)
		label.MaxDistance = 65
		label.Parent = model:FindFirstChild("Head")
		local caption = Instance.new("TextLabel")
		caption.Size = UDim2.fromScale(1, 1)
		caption.BackgroundTransparency = 1
		caption.Text = "МАНЕКЕН · ∞ HP"
		caption.TextColor3 = Color3.fromRGB(255, 210, 110)
		caption.TextStrokeTransparency = 0.25
		caption.TextSize = 16
		caption.Parent = label
		model.Parent = workspace
	end)
end

return TrainingDummy
