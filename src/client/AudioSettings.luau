--!strict
local SoundService = game:GetService("SoundService")
local Audio = {}
local groups: { [string]: SoundGroup } = {}
local values: { [string]: number } = { Master = 1, Characters = 1, Gunfire = 1 }
local started = false

local function init()
	if groups.Master then return end
	for _, name in { "Master", "Characters", "Gunfire" } do
		local group = Instance.new("SoundGroup")
		group.Name, group.Volume = "Robostrike" .. name, values[name]
		group.Parent = if name == "Master" then SoundService else groups.Master
		groups[name] = group
	end
end

function Audio.get(channel: string): number
	return values[channel] or 0
end

function Audio.set(channel: string, volume: number)
	if values[channel] == nil or volume ~= volume then return end
	init()
	values[channel] = math.clamp(volume, 0, 1)
	groups[channel].Volume = values[channel]
end

function Audio.assign(sound: Sound, channel: string)
	init()
	sound.SoundGroup = groups[channel]
end

function Audio.start()
	if started then return end
	started = true
	init()
	local function route(instance: Instance)
		if not instance:IsA("Sound") or instance.SoundGroup then return end
		local ancestor = instance.Parent
		while ancestor and ancestor ~= workspace do
			if ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then
				Audio.assign(instance, "Characters")
				return
			end
			ancestor = ancestor.Parent
		end
	end
	workspace.DescendantAdded:Connect(route)
	for _, instance in workspace:GetDescendants() do route(instance) end
end

return Audio
