--!strict
local Rules = {
	TeamSize = 5,
	FreezeSeconds = 3,
	IntermissionSeconds = 4,
	-- 0 uses the individual experience owner. Set explicitly for group games.
	AdminUserId = 0,
	WilhelmSoundId = "rbxassetid://160718677",
	Colors = { Red = Color3.fromRGB(226, 65, 70), Blue = Color3.fromRGB(65, 145, 245) },
}

function Rules.friendly(source: Model?, target: Model): boolean
	local team = if source then source:GetAttribute("TeamId") else nil
	return team ~= nil and team == target:GetAttribute("TeamId")
end

function Rules.blocked(player: Player): boolean
	return player:GetAttribute("SessionBlocked") == true or player:GetAttribute("TeamMenuOpen") == true
end

function Rules.spawn(team: string, index: number): CFrame
	-- Five separated positions inside the tiled rooms, behind the dividing walls.
	local x = -25 + (index - 1) * 3
	return CFrame.new(x, 3.1, if team == "Blue" then -9.8125 else -68)
		* CFrame.Angles(0, if team == "Blue" then math.pi else 0, 0)
end

return table.freeze(Rules)
