--!strict

local Ballistics = {}
Ballistics.Recovery = 0.5

-- Exact compact support: never an exponential tail after the requested .5s.
function Ballistics.recovery(age: number): number
	local t = math.clamp(age / Ballistics.Recovery, 0, 1)
	return (1 - t) ^ 2
end

function Ballistics.kick(index: number, interval: number, scale: number): Vector2
	local rapid = 1 - math.clamp(interval / Ballistics.Recovery, 0, 1)
	-- Deterministic two-axis pattern; NO randomness is applied to the bullet.
	local horizontal = math.sin(index * 2.39996) * (0.18 + rapid * 0.28)
	return Vector2.new(horizontal, 0.48 + rapid * 0.58) * math.rad(scale)
end

function Ballistics.sway(phase: number, movement: number, ads: number): Vector2
	local amplitude = math.rad(0.85) * movement * (1 - ads * 0.65)
	return Vector2.new(math.sin(phase) * amplitude, -math.abs(math.cos(phase)) * amplitude * 0.65)
end

function Ballistics.nextShot(now: number, due: number, interval: number, dt: number): number
	-- Keep fractional frame remainder without banking shots during an idle gap.
	if now - due > math.max(dt * 2, 0.05) then
		return now + interval
	end
	return due + interval
end

return Ballistics
