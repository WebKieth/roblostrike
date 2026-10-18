--!strict

local WeaponParts = {}
type Entry = { Part: BasePart, Rest: CFrame, Weld: Weld?, Transparency: number }

function WeaponParts.bind(handle: BasePart, scale: number)
	local entries: { Entry } = {}
	for _, child in handle:GetChildren() do
		if child:IsA("BasePart") then
			local weld = child:FindFirstChild("AnimationWeld")
			local authored = child:GetAttribute("AnimationRest")
			local rest = if typeof(authored) == "CFrame" then CFrame.new(authored.Position * scale) * authored.Rotation
				else handle.CFrame:ToObjectSpace(child.CFrame)
			table.insert(entries, { Part = child, Rest = rest,
				Weld = if weld and weld:IsA("Weld") then weld else nil,
				Transparency = if typeof(authored) == "CFrame" then 0 else child.Transparency })
		end
	end
	return function(pose: any, slot: number, scale: number)
		for _, entry in entries do
			local name = entry.Part.Name
			local offset = CFrame.identity
			local magazine = name == "CurvedMagazine" or name == "AKCurvedMagazine"
				or name == "MagazineBase" or name == "GlockMagazine"
			if magazine then offset = CFrame.new(0, -pose.Magazine * 0.95 * scale, 0) end
			if name == "FeedCover" or (slot == 7 and name == "RearSightWing") then
				local hinge = CFrame.new(0, 0.23 * scale, -0.605 * scale)
				offset = hinge * CFrame.Angles(math.rad(-100) * pose.Cover, 0, 0) * hinge:Inverse()
			elseif name == "BeltRound" then offset = CFrame.new(-pose.Belt * 0.3 * scale, pose.Belt * 0.7 * scale, 0)
			elseif name == "ChargingHandle" or name == "Bolt" or (slot == 2 and (
				name == "GlockSlide" or name == "SlideSerration" or name == "EjectionPort"
				or string.find(name, "Sight") ~= nil)) then
				offset = CFrame.new(0, 0, pose.Bolt * 0.32 * scale)
			end
			entry.Part.Transparency = if magazine and pose.MagazineHidden then 1 else entry.Transparency
			if entry.Weld then entry.Weld.C0 = offset * entry.Rest
			else entry.Part.CFrame = handle.CFrame * offset * entry.Rest end
		end
	end
end

return WeaponParts
