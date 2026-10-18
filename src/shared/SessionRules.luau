--!strict
local Rules = {
	TeamSize = 3,
	MaxBotsPerTeam = 32,
	-- Halfway between the original fixed spread (2) and the softened 2.5 + distance * 0.07.
	BotAimBase = 2.25,
	BotAimDistance = 0.035,
	BotThinkBudget = 16,
	BotSightCandidates = 6,
	BotStationarySeconds = 5,
	BotProgressDistance = 3,
	MinimapInterval = 0.25,
	MinimapSightRange = 300,
	MinimapSightDot = 0.5, -- 120-degree field of view.
	FreezeSeconds = 1,
	IntermissionSeconds = 4,
	WilhelmSoundId = "rbxassetid://160718677",
	WilhelmEveryDeaths = 100,
	DeathSoundId = "rbxasset://sounds/uuhhh.mp3",
	-- assets/audio/shiza.mp3; the experience must have permission to use this audio.
	SessionMusicSoundId = "rbxassetid://82769481359031",
	SessionMusicVolume = 0.35,
	Colors = { Red = Color3.fromRGB(226, 65, 70), Blue = Color3.fromRGB(65, 145, 245) },
}

function Rules.friendly(source: Model?, target: Model): boolean
	local team = if source then source:GetAttribute("TeamId") else nil
	return team ~= nil and team == target:GetAttribute("TeamId")
end

function Rules.blocked(player: Player): boolean
	return player:GetAttribute("SessionBlocked") == true or player:GetAttribute("TeamMenuOpen") == true
		or player:GetAttribute("SettingsOpen") == true
end

-- DesertCity bases sit on opposite edges of the open town square.
local spawns = {
	Blue = { { -86, 3.1, -9 }, { -86, 3.1, 0 }, { -86, 3.1, 9 } },
	Red = { { 86, 3.1, -9 }, { 86, 3.1, 0 }, { 86, 3.1, 9 } },
}
local mapSpawns: { [string]: { CFrame } }? = nil
local activeMap: Model? = nil

-- Find additional floor-level spawn positions without stacking rigs or spawning in walls.
function Rules.prepareSpawns(count: number): boolean
	local frames, map = mapSpawns, activeMap
	if count <= Rules.TeamSize then return true end
	if not frames or not map then return false end
	local bounds, size = map:GetBoundingBox()
	local filter = RaycastParams.new()
	filter.FilterType, filter.FilterDescendantsInstances = Enum.RaycastFilterType.Include, { map }
	filter.RespectCanCollide = true
	local overlap = OverlapParams.new()
	overlap.FilterType, overlap.FilterDescendantsInstances = Enum.RaycastFilterType.Include, { map }
	overlap.RespectCanCollide, overlap.MaxParts = true, 1
	local occupied: { Vector3 } = {}
	for _, team in { "Blue", "Red" } do
		for _, frame in frames[team] do table.insert(occupied, frame.Position) end
	end
	for _, team in { "Blue", "Red" } do
		if #frames[team] >= count then continue end
		local base = frames[team][1]
		local enemyBase = frames[if team == "Blue" then "Red" else "Blue"][1]
		local candidates: { Vector3 } = {}
		for x = bounds.Position.X - size.X / 2, bounds.Position.X + size.X / 2, 6 do
			for z = bounds.Position.Z - size.Z / 2, bounds.Position.Z + size.Z / 2, 6 do
				local point = Vector3.new(x, base.Position.Y, z)
				if (point - base.Position).Magnitude + 4 < (point - enemyBase.Position).Magnitude then
					table.insert(candidates, point)
				end
			end
		end
		table.sort(candidates, function(a, b) return (a - base.Position).Magnitude < (b - base.Position).Magnitude end)
		for _, point in candidates do
			if #frames[team] >= count then break end
			local close = false
			for _, other in occupied do if (point - other).Magnitude < 5 then close = true; break end end
			if close then continue end
			-- Four feet corners must all have floor on the same level as the original spawn.
			local supported = true
			for _, offset in { Vector3.new(-1.5, 0, -1.5), Vector3.new(1.5, 0, -1.5), Vector3.new(-1.5, 0, 1.5), Vector3.new(1.5, 0, 1.5) } do
				local hit = workspace:Raycast(point + offset, Vector3.new(0, -4, 0), filter)
				if not hit or math.abs(hit.Position.Y - (base.Position.Y - 3.1)) > 0.1 then supported = false; break end
			end
			if not supported then continue end
			if #workspace:GetPartBoundsInBox(CFrame.new(point + Vector3.new(0, -0.5, 0)), Vector3.new(3.6, 4.96, 3.6), overlap) > 0 then continue end
			table.insert(frames[team], CFrame.new(point) * base.Rotation)
			table.insert(occupied, point)
		end
		if #frames[team] < count then return false end
	end
	return true
end

function Rules.setMap(map: Instance)
	local folder = map:FindFirstChild("TeamSpawns")
	assert(folder, "Map has no TeamSpawns")
	local frames: { [string]: { CFrame } } = { Blue = {}, Red = {} }
	for _, team in { "Blue", "Red" } do
		for index = 1, Rules.TeamSize do
			local marker = folder:FindFirstChild(team .. index)
			assert(marker and marker:IsA("BasePart"), "Missing spawn: " .. team .. index)
			frames[team][index] = CFrame.new(marker.Position.X, 3.1, marker.Position.Z)
				* CFrame.Angles(0, if team == "Blue" then -math.pi / 2 else math.pi / 2, 0)
		end
	end
	mapSpawns = frames
	activeMap = if map:IsA("Model") then map else nil
end

function Rules.spawn(team: string, index: number): CFrame
	if mapSpawns then return mapSpawns[team][index] end
	local position = spawns[team][index]
	return CFrame.new(position[1], position[2], position[3])
		* CFrame.Angles(0, if team == "Blue" then math.pi else 0, 0)
end

return table.freeze(Rules)
