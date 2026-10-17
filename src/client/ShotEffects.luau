--!strict

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ShotEffects = {}
local random = Random.new()

local folder = Instance.new("Folder")
folder.Name = "LocalBulletEffects"
folder.Parent = workspace
local marks: { Instance } = {}
local muzzleFlashes: { Part } = {}
local soundEmitters: { Part } = {}

local function part(name: string, size: Vector3, frame: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, frame, color
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CastShadow = false
	p.Parent = folder
	return p
end

function ShotEffects.flash(position: Vector3, followMuzzle: boolean?)
	local flash = part("MuzzleFlash", Vector3.new(0.17, 0.17, 0.17), CFrame.new(position), Color3.fromRGB(255, 219, 130))
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = flash.Color, 2, 7
	light.Parent = flash
	Debris:AddItem(flash, 0.035)
	if followMuzzle then table.insert(muzzleFlashes, flash) end
end

function ShotEffects.sound(position: Vector3, definition: any)
	if not definition.ShotSound then return end
	for i = #soundEmitters, 1, -1 do
		if not soundEmitters[i].Parent then table.remove(soundEmitters, i) end
	end
	if #soundEmitters >= 32 then table.remove(soundEmitters, 1):Destroy() end
	local emitter = part("ShotSoundEmitter", Vector3.new(0.1, 0.1, 0.1), CFrame.new(position), Color3.new(0, 0, 0))
	emitter.Transparency = 1
	table.insert(soundEmitters, emitter)
	-- Separate instances allow rapid shots to overlap instead of restarting
	-- one shared sound. A world emitter gives other players spatial audio.
	local sound = Instance.new("Sound")
	sound.Name = "Gunshot"
	sound.SoundId = definition.ShotSound
	sound.Volume = definition.ShotVolume or 0.7
	sound.PlaybackSpeed = definition.ShotPlaybackSpeed or 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 180
	sound.Parent = emitter
	sound.Ended:Once(function() emitter:Destroy() end)
	Debris:AddItem(emitter, 5)
	sound:Play()
end

-- A local flash lives for several frames: keep it on the moving gun, not
-- suspended at the previous frame's world position while the player runs.
function ShotEffects.updateMuzzle(position: Vector3)
	for i = #muzzleFlashes, 1, -1 do
		local flash = muzzleFlashes[i]
		if flash.Parent then
			flash.CFrame = CFrame.new(position)
		else
			table.remove(muzzleFlashes, i)
		end
	end
end

local function response(material: Enum.Material): (string, Color3, number)
	if material == Enum.Material.Metal or material == Enum.Material.CorrodedMetal
		or material == Enum.Material.DiamondPlate or material == Enum.Material.Foil then
		return "Metal", Color3.fromRGB(255, 199, 82), 9
	elseif material == Enum.Material.Wood or material == Enum.Material.WoodPlanks then
		return "Wood", Color3.fromRGB(140, 99, 57), 5
	elseif material == Enum.Material.Glass or material == Enum.Material.Ice then
		return "Glass", Color3.fromRGB(187, 225, 234), 7
	elseif material == Enum.Material.Water then
		return "Water", Color3.fromRGB(173, 219, 235), 7
	end
	return "Stone", Color3.fromRGB(164, 159, 145), 6
end

function ShotEffects.impact(position: Vector3, normal: Vector3, material: Enum.Material, hit: Instance?, flesh: boolean)
	local kind, color, count = response(material)
	if flesh then
		kind, color, count = "Armor", Color3.fromRGB(190, 194, 201), 3
	end
	local frame = CFrame.lookAt(position + normal * 0.012, position + normal)
	-- Bounded cosmetic marks, never extra server geometry or collidable debris.
	if not flesh and kind ~= "Water" then
		local mark = part("BulletMark", Vector3.new(0.11, 0.11, 0.012), frame, Color3.fromRGB(30, 29, 27))
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = mark
		if hit and hit:IsA("BasePart") and not hit.Anchored then
			mark.Anchored = false
			mark.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1, weld.Parent = hit, mark, mark
		end
		table.insert(marks, mark)
		if #marks > 100 then table.remove(marks, 1):Destroy() end
		Debris:AddItem(mark, 12)
		if kind == "Glass" then
			for i = 1, 5 do
				local angle = i * math.pi * 2 / 5
				local crack = part("GlassCrack", Vector3.new(0.012, 0.2, 0.008),
					frame * CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.1, 0.012), color)
				Debris:AddItem(crack, 3)
			end
		end
	end
	for _ = 1, count do
		local tangent = frame:VectorToWorldSpace(Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), 0))
		local speed = if kind == "Metal" then 8 else 3
		local velocity = (normal + tangent * 0.9).Unit * random:NextNumber(speed * 0.5, speed)
		local size = if kind == "Metal" then Vector3.new(0.025, 0.025, 0.14)
			elseif kind == "Wood" then Vector3.new(0.035, 0.035, 0.13)
			else Vector3.new(0.055, 0.055, 0.055)
		local chip = part(kind .. "Particle", size, CFrame.new(position + normal * 0.03), color)
		chip.Material = if kind == "Metal" then Enum.Material.Neon else Enum.Material.SmoothPlastic
		chip.Transparency = if kind == "Glass" then 0.3 else 0
		local duration = random:NextNumber(0.15, 0.35)
		TweenService:Create(chip, TweenInfo.new(duration), {
			CFrame = CFrame.lookAt(position + velocity * duration + Vector3.new(0, -0.5 * 18 * duration ^ 2, 0), position + velocity),
			Transparency = 1,
		}):Play()
		Debris:AddItem(chip, duration)
	end
	if kind == "Stone" or kind == "Wood" then
		local dust = part("ImpactDust", Vector3.one * 0.12, CFrame.new(position + normal * 0.06), color)
		dust.Shape = Enum.PartType.Ball
		dust.Transparency = 0.55
		TweenService:Create(dust, TweenInfo.new(0.3), { Size = Vector3.one * 0.55, Transparency = 1 }):Play()
		Debris:AddItem(dust, 0.3)
	end
end

function ShotEffects.tracer(origin: Vector3, target: Vector3)
	local distance = (target - origin).Magnitude
	if distance < 0.01 then return end
	local tracer = part("BulletTracer", Vector3.new(0.018, 0.018, distance),
		CFrame.lookAt((origin + target) * 0.5, target), Color3.fromRGB(255, 224, 162))
	tracer.Material = Enum.Material.Neon
	tracer.Transparency = 0.35
	TweenService:Create(tracer, TweenInfo.new(0.065), { Transparency = 1 }):Play()
	Debris:AddItem(tracer, 0.07)
end

return ShotEffects
