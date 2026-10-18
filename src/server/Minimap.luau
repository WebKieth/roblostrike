--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.SessionRules)
local Minimap = {}

type Actor = { model: Model, position: Vector3, eye: Vector3, forward: Vector3 }

function Minimap.start(slots: any, state: Folder, remotes: Folder, view: ((Player, Model) -> CFrame?)?)
	local event = Instance.new("RemoteEvent")
	event.Name, event.Parent = "MinimapContacts", remotes
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < Rules.MinimapInterval then return end
		elapsed = 0
		local teams: { [string]: { Actor } } = { Red = {}, Blue = {} }
		local characters: { Instance } = {}
		for id, roster in slots do
			for _, slot in roster do
				local model = slot.model
				local h = if model then model:FindFirstChildOfClass("Humanoid") else nil
				local root = if model then model:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
				local head = if model then model:FindFirstChild("Head") :: BasePart? else nil
				if not model or not model.Parent or not h or h.Health <= 0 or not root or not head then continue end
				table.insert(characters, model)
				local frame = if slot.player and view then view(slot.player, model) else nil
				table.insert(teams[id], { model = model, position = root.Position,
					eye = if frame then frame.Position else head.Position,
					forward = if frame then frame.LookVector else root.CFrame.LookVector })
			end
		end
		local filter = RaycastParams.new()
		filter.FilterDescendantsInstances, filter.IgnoreWater = characters, true
		local packets: { [string]: { any } } = { Red = {}, Blue = {} }
		local phase = state:GetAttribute("Phase")
		if phase == "Combat" or phase == "Freeze" then
			for id, allies in teams do
				local packet = packets[id]
				for _, ally in allies do
					table.insert(packet, { model = ally.model, position = ally.position, enemy = false })
				end
				for _, enemy in teams[if id == "Red" then "Blue" else "Red"] do
					for _, observer in allies do
						local delta = enemy.eye - observer.eye
						if delta.Magnitude > Rules.MinimapSightRange then continue end
						if delta.Magnitude > 0.01 and observer.forward:Dot(delta.Unit) < Rules.MinimapSightDot then continue end
						if workspace:Raycast(observer.eye, delta, filter) then continue end
						table.insert(packet, { model = enemy.model, position = enemy.position, enemy = true })
						break
					end
				end
			end
		end
		for _, player in Players:GetPlayers() do
			local id = player:GetAttribute("TeamId")
			event:FireClient(player, if player:GetAttribute("InSession") == true then packets[id] or {} else {})
		end
	end)
end

return Minimap
