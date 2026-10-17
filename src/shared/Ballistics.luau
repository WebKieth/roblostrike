--!strict

local Ballistics = {}
Ballistics.Recovery = 0.5
Ballistics.MaxMuzzleOffset = 6
Ballistics.CameraFollowAngle = math.rad(6)
-- 1 is the existing hardcore recoil pattern (future AK/heavy MG baseline).
Ballistics.SpreadStrength = 1

function Ballistics.spreadScale(weaponMultiplier: number, ads: number): number
	return Ballistics.SpreadStrength * weaponMultiplier * (1 - math.clamp(ads, 0, 1) * 0.5)
end

-- Exact compact support: never an exponential tail after the requested .5s.
function Ballistics.recovery(age: number): number
	local t = math.clamp(age / Ballistics.Recovery, 0, 1)
	return (1 - t) ^ 2
end

-- Do not decay the accumulated burst between successive shots. Recovery
-- starts only after the firing cadence has stopped, and still ends at .5s.
function Ballistics.recoilWeight(age: number, interval: number): number
	local hold = math.min(interval * 2, Ballistics.Recovery * 0.5)
	return Ballistics.recovery(math.max(0, age - hold) * Ballistics.Recovery / (Ballistics.Recovery - hold))
end

-- Split vertical recoil into a small on-screen rise and camera follow.
-- The only absolute ceiling is the world zenith, not a burst equilibrium.
function Ballistics.elevation(basePitch: number, recoilPitch: number): (number, number)
	local pitch = math.clamp(basePitch + recoilPitch, -math.pi / 2, math.pi / 2)
	local cameraLift = math.max(0, pitch - basePitch - Ballistics.CameraFollowAngle)
	return pitch, cameraLift
end

function Ballistics.kick(index: number, interval: number, scale: number): Vector2
	local rapid = 1 - math.clamp(interval / Ballistics.Recovery, 0, 1)
	-- Deterministic accumulated recoil; per-shot dispersion uses this same
	-- cadence-dependent angular strength, rather than an unrelated large cone.
	local horizontal = math.sin(index * 2.39996) * (0.18 + rapid * 0.28)
	return Vector2.new(horizontal, 0.48 + rapid * 0.58) * math.rad(scale * 3)
end

-- Uniform disk, not a square or an unbounded Gaussian. Sample even on the
-- first shot after recovery; randomness changes direction, not the bound.
-- Inputs are samples in [0, 1], keeping this math independently testable.
function Ballistics.dispersion(index: number, interval: number, radiusSample: number, angleSample: number): Vector2
	local reference = Ballistics.kick(index, interval, 1)
	local radius = math.sqrt(reference.X ^ 2 + reference.Y ^ 2) * math.sqrt(math.clamp(radiusSample, 0, 1))
	local angle = angleSample * math.pi * 2
	return Vector2.new(math.cos(angle) * radius, math.sin(angle) * radius)
end

function Ballistics.sway(phase: number, movement: number, ads: number): Vector2
	local amplitude = math.rad(2.55) * movement * (1 - ads * 0.5)
	return Vector2.new(math.sin(phase) * amplitude, -math.abs(math.cos(phase)) * amplitude * 0.65)
end

function Ballistics.nextShot(now: number, due: number, interval: number, dt: number): number
	-- Keep fractional frame remainder without banking shots during an idle gap.
	if now - due > math.max(dt * 2, 0.05) then
		return now + interval
	end
	return due + interval
end

function Ballistics.trigger(automatic: boolean, held: boolean, queued: boolean): boolean
	return queued or (automatic and held)
end

return Ballistics
