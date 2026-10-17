--!strict

local Water = {}
Water.Settings = table.freeze({
	WaveHeight = 0.055,
	WaveLength = 2.8,
	EdgeFade = 0.85,
	SinkSpeed = 35 / 4,
	RiseSpeed = 9,
	SurfaceOffset = -1.15,
	BobHeight = 0.09,
	GridSize = 1.5,
})

export type Pool = { minX: number, maxX: number, minZ: number, maxZ: number, y: number }

-- Merge the BSP's coplanar rectangles, not the two separate pools. Internal
-- BSP seams must not damp waves or count as a pool wall.
function Water.pools(folder: Instance): { Pool }
	local pools: { Pool } = {}
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") then
			table.insert(pools, {
				minX = part.Position.X - part.Size.X / 2, maxX = part.Position.X + part.Size.X / 2,
				minZ = part.Position.Z - part.Size.Z / 2, maxZ = part.Position.Z + part.Size.Z / 2,
				y = part.Position.Y + part.Size.Y / 2,
			})
		end
	end
	local changed = true
	while changed do
		changed = false
		for i = 1, #pools do
			for j = i + 1, #pools do
				local a, b = pools[i], pools[j]
				local sameX = a.minX == b.minX and a.maxX == b.maxX
				local sameZ = a.minZ == b.minZ and a.maxZ == b.maxZ
				if math.abs(a.y - b.y) < 0.001 and (
					(sameX and (a.maxZ == b.minZ or b.maxZ == a.minZ))
					or (sameZ and (a.maxX == b.minX or b.maxX == a.minX))) then
					a.minX, a.maxX = math.min(a.minX, b.minX), math.max(a.maxX, b.maxX)
					a.minZ, a.maxZ = math.min(a.minZ, b.minZ), math.max(a.maxZ, b.maxZ)
					table.remove(pools, j)
					changed = true
					break
				end
			end
			if changed then break end
		end
	end
	return pools
end

function Water.contains(pool: Pool, position: Vector3): boolean
	return position.X >= pool.minX and position.X <= pool.maxX
		and position.Z >= pool.minZ and position.Z <= pool.maxZ
end

function Water.height(pool: Pool, x: number, z: number, time: number): number
	local edge = math.min(x - pool.minX, pool.maxX - x, z - pool.minZ, pool.maxZ - z)
	local fade = math.clamp(edge / Water.Settings.EdgeFade, 0, 1)
	fade = fade * fade * (3 - 2 * fade)
	local k = 2 * math.pi / Water.Settings.WaveLength
	return pool.y + fade * Water.Settings.WaveHeight
		* (math.sin(x * k + z * k * 0.35 - time * 2.3)
			+ 0.4 * math.sin(z * k * 1.3 - x * k * 0.2 + time * 1.8)) / 1.4
end

return Water
