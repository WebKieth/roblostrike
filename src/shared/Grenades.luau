--!strict

local Grenades = {}
Grenades.StudsPerMeter = 1 / 0.28
Grenades.ShoulderRange = 15 * Grenades.StudsPerMeter
Grenades.HipRange = 5 * Grenades.StudsPerMeter
Grenades.BlastRadius = 10 * Grenades.StudsPerMeter
Grenades.MaxDamage = 150
Grenades.Fuse = 5
Grenades.Radius = 0.25
Grenades.ReticleRadius = 24 -- Three times the firearm reticle's 8 px radius.

function Grenades.damage(distance: number): number
	return Grenades.MaxDamage * math.clamp(1 - distance / Grenades.BlastRadius, 0, 1)
end

-- Compensate release height so the flat-ground maximum stays at 45 degrees,
-- not the slightly lower optimum of an uncompensated elevated projectile.
function Grenades.velocity(direction: Vector3, hip: boolean, gravity: number, height: number?): Vector3
	local range = if hip then Grenades.HipRange else Grenades.ShoulderRange
	local unit = direction.Unit
	local pitch = math.asin(math.clamp(unit.Y, -1, 1))
	local cosine = math.cos(pitch)
	if cosine < 0.0001 then return unit * math.sqrt(gravity * range) end
	local h = math.max(height or 0.01, 0.01)
	local baseline = math.min(0.8, math.sqrt(2 * h / range))
	local distance: number
	if pitch >= 0 then
		local sine = math.sin(2 * pitch)
		distance = range * (sine + baseline * (1 - sine) * cosine * cosine)
	else
		local vertical = math.sin(pitch)
		distance = range * baseline * cosine * (vertical + math.sqrt(vertical * vertical + 2 * h / range)) / math.sqrt(2 * h / range)
	end
	local speedSquared = gravity * distance * distance / (2 * cosine * cosine * (h + distance * math.tan(pitch)))
	return unit * math.sqrt(math.max(0, speedSquared))
end

-- Server-owned hand position, independent of client viewmodel/claimed origin.
function Grenades.hand(head: CFrame, hip: boolean): Vector3
	return head:PointToWorldSpace(Vector3.new(0.65, if hip then -1.6 else -0.65, -0.8))
end

return table.freeze(Grenades)
