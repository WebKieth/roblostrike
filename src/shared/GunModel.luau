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
	else
		block("LugerReceiver", Vector3.new(0.23, 0.24, 0.54), CFrame.new(0, 0, 0.1), metal)
		barrel("LugerBarrel", 0.065, 0.83, -0.62, metal)
		barrel("LugerMuzzle", 0.085, 0.1, -1.04, metal)
		barrel("Bore", 0.045, 0.012, -1.096, Color3.new(0, 0, 0))
		block("Grip", Vector3.new(0.23, 0.65, 0.3), CFrame.new(0, -0.36, 0.28) * CFrame.Angles(math.rad(-25), 0, 0), black)
		for _, x in { -0.126, 0.126 } do
			block("WoodGripPanel", Vector3.new(0.025, 0.48, 0.22), CFrame.new(x, -0.35, 0.28) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(89, 57, 38))
			block("ToggleKnob", Vector3.new(0.07, 0.13, 0.13), CFrame.new(x, 0.12, 0.18), metal, true)
			block("RearNotch", Vector3.new(0.04, 0.09, 0.07), CFrame.new(x * 0.65, 0.2, 0.33), black)
		end
		block("Toggle", Vector3.new(0.15, 0.12, 0.32), CFrame.new(0, 0.11, 0.06), metal)
		block("FrontPost", Vector3.new(0.025, 0.13, 0.06), CFrame.new(0, 0.155, -0.97), black)
		block("Trigger", Vector3.new(0.04, 0.16, 0.05), CFrame.new(0, -0.21, -0.06), steel)
		block("TriggerGuard", Vector3.new(0.06, 0.04, 0.32), CFrame.new(0, -0.31, 0.03), metal)
	end
end

return GunModel
