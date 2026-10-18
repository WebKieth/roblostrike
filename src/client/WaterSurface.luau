--!strict

-- Native Glass facets: no Terrain voxels spilling into the tiles, uploaded
-- normal maps or EditableMesh permissions. Shared vertices keep the skin sealed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Water = require(ReplicatedStorage.Shared.Water)
local Surface = {}

function Surface.start(folder: Instance, pools: { Water.Pool })
	local skin = Instance.new("Folder")
	skin.Name = "LocalWaterSurface"
	skin.Parent = workspace
	local function wedge(): WedgePart
		local part = Instance.new("WedgePart")
		part.Anchored = true
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.CastShadow = false
		part.Material = Enum.Material.Glass
		part.Color = Color3.fromRGB(37, 167, 191)
		part.Transparency = 0.48
		part.Reflectance = 0.12
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Parent = skin
		return part
	end
	local triangles = {}
	local function triangle(a: number, b: number, c: number)
		table.insert(triangles, { a = a, b = b, c = c, left = wedge(), right = wedge() })
	end
	local vertices: { { pool: Water.Pool, x: number, z: number } } = {}
	local points: { Vector3 } = {}
	for _, pool in pools do
		local nx = math.ceil((pool.maxX - pool.minX) / Water.Settings.GridSize)
		local nz = math.ceil((pool.maxZ - pool.minZ) / Water.Settings.GridSize)
		local offset = #vertices + 1
		for z = 0, nz do
			for x = 0, nx do
				table.insert(vertices, { pool = pool,
					x = pool.minX + (pool.maxX - pool.minX) * x / nx,
					z = pool.minZ + (pool.maxZ - pool.minZ) * z / nz })
			end
		end
		for z = 0, nz - 1 do
			for x = 0, nx - 1 do
				local a = offset + z * (nx + 1) + x
				triangle(a, a + nx + 1, a + 1)
				triangle(a + 1, a + nx + 1, a + nx + 2)
			end
		end
	end
	local function update()
		local time = workspace:GetServerTimeNow()
		for i, vertex in vertices do
			points[i] = Vector3.new(vertex.x, Water.height(vertex.pool, vertex.x, vertex.z, time), vertex.z)
		end
		for _, tri in triangles do
			local a, b, c = points[tri.a], points[tri.b], points[tri.c]
			local ab, ac, bc = b - a, c - a, c - b
			if ab:Dot(ab) > math.max(ac:Dot(ac), bc:Dot(bc)) then
				c, a = a, c
			elseif ac:Dot(ac) > math.max(ab:Dot(ab), bc:Dot(bc)) then
				a, b = b, a
			end
			ab, ac, bc = b - a, c - a, c - b
			local right = ac:Cross(ab).Unit
			local back = bc.Unit
			local up = bc:Cross(right).Unit
			local height = math.abs(ab:Dot(up))
			tri.left.Size = Vector3.new(0.001, height, math.abs(ab:Dot(back)))
			tri.right.Size = Vector3.new(0.001, height, math.abs(ac:Dot(back)))
			-- Offset the thin solid inward so the top stays on the wave, including at the rim.
			tri.left.CFrame = CFrame.fromMatrix((a + b) / 2 - Vector3.yAxis * 0.0005, right, up, back)
			tri.right.CFrame = CFrame.fromMatrix((a + c) / 2 - Vector3.yAxis * 0.0005, -right, up, -back)
		end
	end
	update()
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") then part.LocalTransparencyModifier = 1 end
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 1 / 30 then
			elapsed %= 1 / 30
			update()
		end
	end)
end

return Surface
