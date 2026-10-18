--!strict

local Survival = {
	MaxHealth = 100,
	MaxArmor = 100,
	ArmorWear = 20,
	SpareMagazines = 3,
	LootRespawn = 60,
	PickupRadius = 3.5,
	DropDistance = 3.57, -- Approximately one metre (Roblox: 0.28 m/stud).
	ReferenceDamage = table.freeze({ Leg = 20, Arm = 30, Torso = 70, Head = 150 }),
}

function Survival.zone(partName: string): string
	if partName == "Head" then return "Head" end
	if string.find(partName, "Leg") or string.find(partName, "Foot") then return "Leg" end
	if string.find(partName, "Arm") or string.find(partName, "Hand") then return "Arm" end
	return "Torso"
end

function Survival.damage(partName: string, armor: number, helmet: boolean, multiplier: number?): (number, number)
	local zone = Survival.zone(partName)
	local damage = Survival.ReferenceDamage[zone]
	damage *= multiplier or 1
	if armor > 0 and (zone == "Torso" or (zone == "Head" and helmet)) then
		return math.round(damage / 2), math.max(0, armor - Survival.ArmorWear)
	end
	return math.round(damage), armor
end

return table.freeze(Survival)
