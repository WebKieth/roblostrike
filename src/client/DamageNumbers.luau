--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local DamageNumbers = {}

function DamageNumbers.start()
	local event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DamageNumber") :: RemoteEvent
	local active: { BasePart } = {}
	event.OnClientEvent:Connect(function(position: Vector3, damage: number)
		local anchor = Instance.new("Part")
		anchor.Name = "DamageNumber"
		anchor.Size = Vector3.one * 0.1
		anchor.Anchored = true
		anchor.Transparency = 1
		anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
		anchor.Position = position + Vector3.new(math.random(-35, 35) / 100, 1, 0)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(100, 45)
		gui.MaxDistance = 150
		gui.Parent = anchor
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = tostring(damage)
		text.Font = Enum.Font.GothamBold
		text.TextSize = 28
		text.TextColor3 = Color3.fromRGB(255, 203, 95)
		text.TextStrokeTransparency = 0.25
		text.Parent = gui
		anchor.Parent = workspace
		local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(anchor, info, { Position = anchor.Position + Vector3.new(0, 3, 0) }):Play()
		TweenService:Create(text, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		Debris:AddItem(anchor, 1.2)
		-- Bound even a busy multiplayer shooting range; discard expired references.
		for index = #active, 1, -1 do
			if not active[index].Parent then table.remove(active, index) end
		end
		table.insert(active, anchor)
		if #active > 100 then table.remove(active, 1):Destroy() end
	end)
end

return DamageNumbers
