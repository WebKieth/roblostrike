--!strict

-- Original multi-part models in studs. Forward is -Z; the sight line is
-- exactly parallel to the bore. Used on both sides, with no catalog scripts.
local GunModel = {}

function GunModel.build(handle: BasePart, slot: number, anchored: boolean)
	local metal = Color3.fromRGB(58, 63, 68)
	local black = Color3.fromRGB(25, 29, 32)
	local steel = Color3.fromRGB(103, 109, 115)
	handle.Transparency = 1
	local function block(name: string, size: Vector3, frame: CFrame, color: Color3, cylinder: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = if color == black then Enum.Material.SmoothPlastic else Enum.Material.Metal
		p.Anchored = anchored
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		p.Massless = true
		p.CastShadow = not anchored
		if cylinder then
			p.Shape = Enum.PartType.Cylinder
		end
		p.CFrame = handle.CFrame * frame
		p.Parent = handle
		if not anchored then
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = handle, p
			weld.Parent = p
		end
		return p
	end
	local function barrel(name: string, radius: number, length: number, z: number, color: Color3)
		block(name, Vector3.new(length, radius * 2, radius * 2),
			CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi / 2, 0), color, true)
	end
	if slot == 1 then
		block("LowerReceiver", Vector3.new(0.28, 0.27, 0.85), CFrame.new(0, -0.1, 0.05), metal)
		block("UpperReceiver", Vector3.new(0.3, 0.22, 0.92), CFrame.new(0, 0.1, 0), metal)
		block("EjectionPort", Vector3.new(0.012, 0.1, 0.3), CFrame.new(0.155, 0.1, -0.02), black)
		block("Bolt", Vector3.new(0.015, 0.035, 0.18), CFrame.new(0.164, 0.1, -0.02), steel)
		block("ChargingHandle", Vector3.new(0.4, 0.055, 0.1), CFrame.new(0, 0.15, 0.5), black)
		block("PistolGrip", Vector3.new(0.2, 0.52, 0.22), CFrame.new(0, -0.38, 0.42) * CFrame.Angles(math.rad(-18), 0, 0), black)
		block("TriggerGuard", Vector3.new(0.08, 0.045, 0.35), CFrame.new(0, -0.33, 0.16), metal)
		block("Trigger", Vector3.new(0.045, 0.15, 0.045), CFrame.new(0, -0.24, 0.17) * CFrame.Angles(math.rad(-15), 0, 0), steel)
		block("MagazineWell", Vector3.new(0.3, 0.23, 0.31), CFrame.new(0, -0.23, -0.22), metal)
		for i = 0, 2 do
			block("CurvedMagazine", Vector3.new(0.22, 0.23, 0.28), CFrame.new(0, -0.39 - i * 0.18, -0.22 - i * 0.035)
				* CFrame.Angles(math.rad(i * 7), 0, 0), metal)
		end
		barrel("BufferTube", 0.1, 0.68, 0.75, metal)
		block("AdjustableStock", Vector3.new(0.29, 0.37, 0.64), CFrame.new(0, -0.08, 1), black)
		block("RubberButtplate", Vector3.new(0.34, 0.52, 0.1), CFrame.new(0, -0.16, 1.34), black)
		barrel("Handguard", 0.185, 0.88, -0.91, black)
		for i = 0, 7 do
			local z = -0.53 - i * 0.105
			block("TopRail", Vector3.new(0.31, 0.065, 0.045), CFrame.new(0, 0.2, z), metal)
			block("BottomRail", Vector3.new(0.25, 0.045, 0.045), CFrame.new(0, -0.2, z), metal)
			for _, side in { -1, 1 } do
				block("HandguardVent", Vector3.new(0.025, 0.09, 0.055), CFrame.new(side * 0.18, 0, z), steel)
			end
		end
		barrel("Barrel", 0.055, 0.68, -1.67, metal)
		barrel("FlashHider", 0.085, 0.22, -2.04, black)
		barrel("Bore", 0.048, 0.012, -2.157, Color3.new(0, 0, 0))
		-- Open rear notch and a narrow front post: the center at Y=.28 is
		-- unobstructed, not a solid cube pretending to be an iron sight.
		for _, x in { -0.105, 0.105 } do
			block("RearSightWing", Vector3.new(0.045, 0.14, 0.09), CFrame.new(x, 0.27, 0.37), black)
		end
		block("RearSightBase", Vector3.new(0.25, 0.055, 0.12), CFrame.new(0, 0.19, 0.37), metal)
		block("FrontSightTower", Vector3.new(0.08, 0.21, 0.09), CFrame.new(0, 0.105, -1.45), metal)
		block("FrontSightPost", Vector3.new(0.025, 0.12, 0.035), CFrame.new(0, 0.22, -1.45), black)
	elseif slot == 2 then
		-- Glock 17: squared steel slide over a polymer frame, no exposed
		-- Luger barrel/toggle. All parts share the same authored bore axis.
		block("GlockSlide", Vector3.new(0.3, 0.28, 1.34), CFrame.new(0, 0.04, -0.28), metal)
		block("PolymerFrame", Vector3.new(0.32, 0.16, 1.14), CFrame.new(0, -0.17, -0.19), black)
		block("DustCover", Vector3.new(0.27, 0.12, 0.5), CFrame.new(0, -0.26, -0.58), black)
		barrel("BarrelCrown", 0.075, 0.035, -0.96, steel)
		barrel("Bore", 0.047, 0.012, -0.985, Color3.new(0, 0, 0))
		block("EjectionPort", Vector3.new(0.012, 0.12, 0.27), CFrame.new(0.155, 0.07, -0.18), black)
		block("Chamber", Vector3.new(0.014, 0.07, 0.19), CFrame.new(0.163, 0.07, -0.18), steel)
		local grip = CFrame.new(0, -0.48, 0.23) * CFrame.Angles(math.rad(-18), 0, 0)
		block("PolymerGrip", Vector3.new(0.29, 0.65, 0.35), grip, black)
		block("MagazineBase", Vector3.new(0.33, 0.07, 0.39), grip * CFrame.new(0, -0.34, 0), black)
		for _, side in { -1, 1 } do
			for i = 0, 5 do
				block("SlideSerration", Vector3.new(0.012, 0.19, 0.018), CFrame.new(side * 0.155, 0.035, 0.12 + i * 0.04), black)
			end
			block("RearSightWing", Vector3.new(0.045, 0.09, 0.08), CFrame.new(side * 0.085, 0.225, 0.27), black)
			block("RearSightMark", Vector3.new(0.025, 0.04, 0.012), CFrame.new(side * 0.085, 0.235, 0.315), Color3.fromRGB(235, 235, 225))
			block("TriggerGuardSide", Vector3.new(0.045, 0.05, 0.39), CFrame.new(side * 0.12, -0.45, -0.09), black)
		end
		block("RearSightBase", Vector3.new(0.22, 0.04, 0.09), CFrame.new(0, 0.19, 0.27), black)
		block("FrontSightPost", Vector3.new(0.035, 0.1, 0.055), CFrame.new(0, 0.22, -0.83), black)
		block("FrontSightMark", Vector3.new(0.022, 0.035, 0.008), CFrame.new(0, 0.24, -0.799), Color3.fromRGB(235, 235, 225))
		block("Trigger", Vector3.new(0.045, 0.18, 0.055), CFrame.new(0, -0.32, -0.05), black)
		block("TriggerSafety", Vector3.new(0.018, 0.12, 0.012), CFrame.new(0, -0.32, -0.084), steel)
		block("TriggerGuardFront", Vector3.new(0.27, 0.22, 0.045), CFrame.new(0, -0.36, -0.29), black)
	end
end

return GunModel
