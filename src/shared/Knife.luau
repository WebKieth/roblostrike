--!strict

local Knife = {
	MetresPerStud = 0.28,
	Slash = table.freeze({ Duration = 0.3, HitStart = 0.1, HitEnd = 0.2, Reach = 0.2 / 0.28, DamageMultiplier = 0.6 }),
	Stab = table.freeze({ Duration = 0.8, HitStart = 0.3, HitEnd = 0.5, Reach = 0.3 / 0.28, DamageMultiplier = 3 }),
}

function Knife.active(attack: any, age: number): boolean
	return age >= attack.HitStart and age <= attack.HitEnd
end

-- The same normalized stroke drives presentation and the server's cutting arc.
function Knife.stroke(attack: any, age: number): number
	return math.clamp((age - attack.HitStart) / (attack.HitEnd - attack.HitStart), 0, 1)
end

function Knife.pose(mode: string, age: number): CFrame
	local attack = if mode == "Slash" then Knife.Slash else Knife.Stab
	if age < 0 or age >= attack.Duration then return CFrame.identity end
	local stroke = Knife.stroke(attack, age)
	local weight = if age < attack.HitStart then age / attack.HitStart
		elseif age <= attack.HitEnd then 1
		else (attack.Duration - age) / (attack.Duration - attack.HitEnd)
	if mode == "Slash" then
		return CFrame.new((0.35 - stroke * 0.9) * weight, 0.12 * weight, -0.15 * weight)
			* CFrame.Angles(0, math.rad(45 - 90 * stroke) * weight, math.rad(30 - 60 * stroke) * weight)
	end
	local extension = if age < attack.HitStart then 0.25 * weight else -0.65 * math.sin(math.pi * stroke)
	return CFrame.new(0, 0.08 * weight, extension) * CFrame.Angles(math.rad(20) * weight, 0, 0)
end

return table.freeze(Knife)
