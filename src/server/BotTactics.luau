--!strict
-- Position selection, not aim assistance. All threats supplied here were seen.
local Tactics = {}

function Tactics.mode(health: number, reloading: boolean, hurt: boolean, enemies: number, allies: number): string
	return if reloading or health <= 35 or hurt or enemies > allies then "Retreat" else "Engage"
end

function Tactics.score(distance: number, travel: number, exposure: number, crowded: number,
	covered: boolean, canShoot: boolean, retreat: boolean, flank: number): number
	local ideal = if retreat then 48 else 24
	return -math.abs(distance - ideal) * 0.7 - travel * 0.2 - crowded * 6
		- exposure * (if retreat then 35 else 12)
		+ (if covered then (if retreat then 65 else 15) else 0)
		+ (if canShoot and not retreat then 22 else 0) + (if retreat then 0 else flank * 18)
end

-- Only consider short, walkable steps with body clearance and a supporting floor.
-- Longer travel is handled by the navmesh, never by a blind MoveTo through walls.
function Tactics.choose(model: Model, origin: Vector3, threat: Vector3, enemies: { Vector3 },
	allies: { Vector3 }, retreat: boolean, side: number, geometry: RaycastParams, peek: boolean, forceMove: boolean?): Vector3
	local delta = Vector3.new(threat.X - origin.X, 0, threat.Z - origin.Z)
	local forward = if delta.Magnitude > 0.1 then delta.Unit else Vector3.new(0, 0, -1)
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local eyeOffset = (model.Head :: BasePart).Position - origin
	local best, bestScore = origin, -math.huge
	for index = 0, 16 do
		if index == 0 and forceMove then continue end
		local point = origin
		if index > 0 then
			local angle = (index % 8) * math.pi / 4
			local step = (forward * math.cos(angle) + right * math.sin(angle)) * (if index <= 8 then 8 else 16)
			if workspace:Blockcast(CFrame.new(origin), Vector3.new(3, 4, 3), step, geometry) then continue end
			local floor = workspace:Raycast(origin + step + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), geometry)
			if not floor or floor.Normal.Y < 0.7 then continue end
			point = Vector3.new(origin.X + step.X, floor.Position.Y + 2.7, origin.Z + step.Z)
			if math.abs(point.Y - origin.Y) > 1.5 then continue end
			-- Reject a step over a pool edge or gap even if its far end has a floor.
			local middle = workspace:Raycast(origin + step * 0.5, Vector3.new(0, -4, 0), geometry)
			if not middle or middle.Normal.Y < 0.7 then continue end
		end
		local eye = point + eyeOffset
		local headBlocked = workspace:Raycast(threat, eye - threat, geometry) ~= nil
		local covered = headBlocked and workspace:Raycast(threat, point - threat, geometry) ~= nil
		local canShoot = not headBlocked
		if covered then
			-- Prefer cover with a nearby firing angle rather than a dead-end hiding spot.
			for _, sign in { -1, 1 } do
				local peek = right * sign * 4
				if not workspace:Blockcast(CFrame.new(point), Vector3.new(3, 4, 3), peek, geometry)
					and not workspace:Raycast(eye + peek, threat - eye - peek, geometry) then
					canShoot = true
				end
			end
		end
		local exposure, crowded = 0, 0
		for index, enemy in enemies do
			if index > 4 then break end -- Bound cover probes even in 32-by-32 sessions.
			if not workspace:Raycast(enemy, eye - enemy, geometry) then exposure += 1 end
		end
		for _, ally in allies do
			crowded += math.max(0, 14 - (point - ally).Magnitude)
		end
		local offset = point - origin
		local score = Tactics.score((point - threat).Magnitude, offset.Magnitude, exposure, crowded,
			covered, canShoot, retreat, offset:Dot(right) * side / 16)
		if peek and headBlocked and not retreat then score -= 45 end
		if score > bestScore then best, bestScore = point, score end
	end
	return best
end

return Tactics
