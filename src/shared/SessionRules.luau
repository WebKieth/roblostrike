--!strict
local Rules = {
	TeamSize = 3,
	FreezeSeconds = 3,
	IntermissionSeconds = 4,
	-- 0 uses the individual experience owner. Set explicitly for group games.
	AdminUserId = 0,
	WilhelmSoundId = "rbxassetid://160718677",
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

-- Stay behind the solid middle wall: the outer room edges face the doorways.
-- Cover takes priority over using the full width of the room.
local spawns = {
	Blue = { { -14, 3.1, 4 }, { -7, 3.1, 2 }, { 0, 3.1, 4 } },
	Red = { { -14, 3.1, -68 }, { -7, 3.1, -70 }, { 0, 3.1, -68 } },
}

function Rules.spawn(team: string, index: number): CFrame
	local position = spawns[team][index]
	return CFrame.new(position[1], position[2], position[3])
		* CFrame.Angles(0, if team == "Blue" then math.pi else 0, 0)
end

return table.freeze(Rules)
