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
		p:SetAttribute("AnimationRest", frame)
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
			local weld = Instance.new("Weld")
			weld.Name = "AnimationWeld"
			weld.C0 = frame
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
	elseif slot == 6 then
		-- AK-47: wooden furniture, stamped receiver and a strongly curved magazine.
		local wood = Color3.fromRGB(126, 68, 34)
		block("AKReceiver", Vector3.new(0.34, 0.32, 1.05), CFrame.new(0, -0.04, 0), metal)
		barrel("DustCover", 0.17, 0.85, 0.05, black)
		block("EjectionPort", Vector3.new(0.015, 0.12, 0.36), CFrame.new(0.18, 0.07, -0.12), black)
		block("ChargingHandle", Vector3.new(0.2, 0.05, 0.08), CFrame.new(0.24, 0.07, 0), steel)
		block("WoodStock", Vector3.new(0.29, 0.4, 0.88), CFrame.new(0, -0.14, 0.95), wood)
		block("Buttplate", Vector3.new(0.31, 0.45, 0.07), CFrame.new(0, -0.14, 1.42), black)
		block("WoodGrip", Vector3.new(0.23, 0.5, 0.25), CFrame.new(0, -0.37, 0.42) * CFrame.Angles(math.rad(-18), 0, 0), wood)
		block("TriggerGuard", Vector3.new(0.12, 0.045, 0.35), CFrame.new(0, -0.34, 0.13), black)
		block("Trigger", Vector3.new(0.045, 0.16, 0.045), CFrame.new(0, -0.26, 0.15), steel)
		for i = 0, 4 do
			block("AKCurvedMagazine", Vector3.new(0.25, 0.19, 0.34),
				CFrame.new(0, -0.28 - i * 0.15, -0.24 - i * i * 0.018)
				* CFrame.Angles(math.rad(i * 10), 0, 0), black)
		end
		block("WoodHandguard", Vector3.new(0.33, 0.31, 0.78), CFrame.new(0, -0.06, -0.96), wood)
		block("UpperHandguard", Vector3.new(0.26, 0.14, 0.62), CFrame.new(0, 0.13, -0.92), wood)
		barrel("Barrel", 0.06, 0.84, -1.74, metal)
		block("GasTube", Vector3.new(0.13, 0.12, 0.7), CFrame.new(0, 0.13, -1.35), metal)
		barrel("MuzzleBrake", 0.085, 0.18, -2.13, black)
		barrel("Bore", 0.05, 0.012, -2.226, Color3.new(0, 0, 0))
		-- Low tangent leaf on a solid receiver-mounted block, not floating ears.
		block("AKSightBlock", Vector3.new(0.28, 0.1, 0.36), CFrame.new(0, 0.16, -0.48), metal)
		block("AKSightLeaf", Vector3.new(0.28, 0.03, 0.32), CFrame.new(0, 0.225, -0.48), black)
		for _, side in { -1, 1 } do
			block("AKRearSightPlate", Vector3.new(0.095, 0.04, 0.06), CFrame.new(side * 0.0925, 0.26, -0.35), black)
			-- Wedges rise outward from the notch floor (Y=.24) to Y=.28.
			-- Their sloping edges form a real V-shaped opening, with no center post.
			local slope = block("AKRearSightNotch", Vector3.new(0.06, 0.04, 0.045),
				CFrame.new(side * 0.0225, 0.26, -0.35) * CFrame.Angles(0, side * math.pi / 2, 0), black)
			local wedge = Instance.new("SpecialMesh")
			wedge.MeshType = Enum.MeshType.Wedge
			wedge.Parent = slope
		end
		block("FrontSightTower", Vector3.new(0.08, 0.2, 0.1), CFrame.new(0, 0.11, -1.94), metal)
		block("FrontSightPost", Vector3.new(0.025, 0.12, 0.035), CFrame.new(0, 0.22, -1.94), black)
	elseif slot == 7 then
		-- M249: box-fed belt, broad top cover, carry handle and folded bipod.
		local olive = Color3.fromRGB(73, 82, 48)
		block("M249Receiver", Vector3.new(0.5, 0.4, 1.2), CFrame.new(0, -0.04, -0.05), metal)
		block("FeedCover", Vector3.new(0.52, 0.13, 1.05), CFrame.new(0, 0.23, -0.08), black)
		block("ChargingHandle", Vector3.new(0.22, 0.07, 0.12), CFrame.new(0.32, 0.07, 0), steel)
		block("EjectionPort", Vector3.new(0.015, 0.16, 0.35), CFrame.new(0.26, 0.04, -0.12), black)
		block("AmmoBox", Vector3.new(0.7, 0.62, 0.62), CFrame.new(-0.1, -0.53, -0.3), olive)
		for i = 0, 5 do
			block("BeltRound", Vector3.new(0.09, 0.1, 0.28), CFrame.new(-0.55 + i * 0.1, 0.05, -0.35), Color3.fromRGB(185, 145, 61))
		end
		block("PistolGrip", Vector3.new(0.25, 0.55, 0.28), CFrame.new(0, -0.41, 0.42) * CFrame.Angles(math.rad(-15), 0, 0), black)
		block("Trigger", Vector3.new(0.05, 0.17, 0.05), CFrame.new(0, -0.29, 0.17), steel)
		block("TriggerGuard", Vector3.new(0.13, 0.05, 0.35), CFrame.new(0, -0.4, 0.15), black)
		block("Stock", Vector3.new(0.35, 0.4, 0.94), CFrame.new(0, -0.1, 1.03), olive)
		block("Buttplate", Vector3.new(0.4, 0.56, 0.1), CFrame.new(0, -0.15, 1.53), black)
		block("Handguard", Vector3.new(0.42, 0.33, 0.9), CFrame.new(0, -0.09, -1.08), olive)
		for i = 0, 5 do
			for _, side in { -1, 1 } do
				block("CoolingVent", Vector3.new(0.015, 0.12, 0.06), CFrame.new(side * 0.215, -0.07, -0.74 - i * 0.13), black)
			end
		end
		barrel("HeavyBarrel", 0.085, 0.94, -1.98, metal)
		barrel("FlashHider", 0.11, 0.2, -2.51, black)
		barrel("Bore", 0.05, 0.012, -2.616, Color3.new(0, 0, 0))
		for _, side in { -1, 1 } do
			block("FoldedBipod", Vector3.new(0.065, 0.075, 0.86), CFrame.new(side * 0.17, -0.19, -1.92), steel)
			block("RearSightWing", Vector3.new(0.05, 0.13, 0.12), CFrame.new(side * 0.12, 0.335, 0.31), black)
		end
		block("CarryHandleStem", Vector3.new(0.06, 0.18, 0.07), CFrame.new(0.3, 0.3, -0.9), steel)
		block("CarryHandle", Vector3.new(0.1, 0.09, 0.42), CFrame.new(0.3, 0.4, -0.77), black)
		block("FrontSightTower", Vector3.new(0.1, 0.26, 0.1), CFrame.new(0, 0.13, -2.13), metal)
		block("FrontSightPost", Vector3.new(0.025, 0.14, 0.035), CFrame.new(0, 0.27, -2.13), black)
	elseif slot == 8 then
		local olive = Color3.fromRGB(79, 91, 52)
		block("AWPChassis", Vector3.new(0.4, 0.28, 2.05), CFrame.new(0, -0.17, -0.35), olive)
		block("AWPReceiver", Vector3.new(0.32, 0.25, 1.05), CFrame.new(0, 0.02, 0.05), metal)
		block("EjectionPort", Vector3.new(0.014, 0.13, 0.4), CFrame.new(0.17, 0.08, 0.12), black)
		block("Bolt", Vector3.new(0.09, 0.09, 0.5), CFrame.new(0.15, 0.08, 0.15), steel)
		block("ChargingHandle", Vector3.new(0.26, 0.07, 0.08), CFrame.new(0.29, 0.07, 0.34), steel)
		block("BoltKnob", Vector3.new(0.13, 0.16, 0.14), CFrame.new(0.43, 0.02, 0.34), black)
		block("AWPStock", Vector3.new(0.34, 0.42, 1.05), CFrame.new(0, -0.12, 1.05), olive)
		block("CheekRest", Vector3.new(0.36, 0.14, 0.65), CFrame.new(0, 0.16, 1.05), black)
		block("Buttplate", Vector3.new(0.4, 0.6, 0.1), CFrame.new(0, -0.14, 1.62), black)
		block("PistolGrip", Vector3.new(0.23, 0.52, 0.25), CFrame.new(0, -0.36, 0.42), olive)
		block("TriggerGuard", Vector3.new(0.13, 0.05, 0.35), CFrame.new(0, -0.37, 0.12), black)
		block("Trigger", Vector3.new(0.045, 0.17, 0.045), CFrame.new(0, -0.27, 0.15), steel)
		block("AWPMagazine", Vector3.new(0.27, 0.43, 0.4), CFrame.new(0, -0.46, -0.25), black)
		-- Continuous barrel from the receiver, through the fore-end, to the crown.
		barrel("BarrelShank", 0.1, 1.1, -1, metal)
		barrel("HeavyBarrel", 0.075, 2.1, -2.35, metal)
		barrel("MuzzleCrown", 0.09, 0.1, -3.4, black)
		barrel("Bore", 0.05, 0.012, -3.456, Color3.new(0, 0, 0))
		for _, z in { -0.35, 0.3 } do
			block("ScopeMount", Vector3.new(0.26, 0.2, 0.1), CFrame.new(0, 0.27, z), metal)
		end
		block("ScopeTube", Vector3.new(1.3, 0.24, 0.24), CFrame.new(0, 0.48, -0.05) * CFrame.Angles(0, math.pi / 2, 0), black, true)
		for _, z in { -0.76, 0.64 } do
			local outward = if z > 0 then 1 else -1
			-- Close the annular gap at the tube end of each bell. Overlapping
			-- steps form an opaque shoulder, while leaving the outer lens exposed.
			for step = 0, 4 do
				local radius = 0.125 + 0.075 * step / 4
				local center = z - outward * (0.285 - step * 0.04)
				block("ScopeShoulder", Vector3.new(0.045, radius * 2, radius * 2),
					CFrame.new(0, 0.48, center) * CFrame.Angles(0, math.pi / 2, 0), black, true)
			end
			-- An actual open annulus, not a solid cylinder with glass stuck on it.
			local segments, inner, outer = 32, 0.175, 0.2
			for i = 0, segments - 1 do
				local angle = i * math.pi * 2 / segments
				local radius = (inner + outer) / 2
				block("ScopeRim", Vector3.new(outer - inner, 2 * outer * math.tan(math.pi / segments), 0.25),
					CFrame.new(radius * math.cos(angle), 0.48 + radius * math.sin(angle), z)
						* CFrame.Angles(0, 0, angle), black)
			end
			local face = z + outward * 0.125
			local lens = block("ScopeLens", Vector3.new(0.354, 0.354, 0.05),
				CFrame.new(0, 0.48, face - outward * 0.02), Color3.fromRGB(53, 94, 105))
			-- Ball Parts render as a ball rather than the required optical profile.
			-- A sphere mesh keeps the full aperture and flattens only its depth.
			local glass = Instance.new("SpecialMesh")
			glass.MeshType = Enum.MeshType.Sphere
			glass.Scale = Vector3.new(1, 1, 0.4)
			glass.Parent = lens
			lens.Material = Enum.Material.Glass
			lens.Transparency = 0.18
			lens.Reflectance = 0.22
			lens:SetAttribute("AnimationTransparency", lens.Transparency)
		end
		-- Elevation and windage turrets break up the otherwise featureless tube.
		block("ElevationTurret", Vector3.new(0.12, 0.16, 0.16),
			CFrame.new(0, 0.62, -0.05) * CFrame.Angles(0, 0, math.pi / 2), metal, true)
		block("ElevationDial", Vector3.new(0.055, 0.21, 0.21),
			CFrame.new(0, 0.7, -0.05) * CFrame.Angles(0, 0, math.pi / 2), black, true)
		block("WindageDial", Vector3.new(0.09, 0.18, 0.18), CFrame.new(0.18, 0.48, -0.05), black, true)
		for _, side in { -1, 1 } do
			block("FoldedBipod", Vector3.new(0.065, 0.075, 0.8), CFrame.new(side * 0.2, -0.25, -1.1), steel)
		end
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
		block("GlockMagazine", Vector3.new(0.23, 0.6, 0.28), grip, steel)
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
	elseif slot == 3 then
		-- Explicit blade axis (-Z) and grip at the wrist; no catalog mesh pivot ambiguity.
		block("KnifeHandle", Vector3.new(0.18, 0.2, 0.65), CFrame.new(0, -0.3, 0.3), black)
		block("KnifeGuard", Vector3.new(0.42, 0.12, 0.09), CFrame.new(0, -0.3, -0.06), metal)
		block("KnifeBlade", Vector3.new(0.23, 0.045, 0.85), CFrame.new(0, -0.3, -0.52), steel)
		local tip = block("KnifeTip", Vector3.new(0.23, 0.045, 0.28), CFrame.new(0, -0.3, -1.08), steel)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Wedge
		mesh.Parent = tip
	end
end

return GunModel
