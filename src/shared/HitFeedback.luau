--!strict

local HitFeedback = {
	Recovery = 0.5,
	ArcLifetime = 0.9,
	CameraPitch = math.rad(8),
	AimDrop = math.rad(3),
}

function HitFeedback.weight(age: number, duration: number): number
	return (1 - math.clamp(age / duration, 0, 1)) ^ 2
end

-- Camera-local X/Z: front = top, right = right, rear = bottom.
function HitFeedback.bearing(x: number, z: number): number
	return if x * x + z * z < 1e-8 then 0 else math.atan2(x, -z)
end

return table.freeze(HitFeedback)
