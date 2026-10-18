--!strict

-- Deterministic, camera-independent poses. Distances are authored GunModel studs.
local Animation = {}
export type Pose = {
	Weapon: CFrame, LeftHand: Vector3?, Magazine: number, MagazineHidden: boolean,
	Cover: number, Belt: number, Bolt: number,
}

local function ramp(t: number, a: number, b: number): number
	local x = math.clamp((t - a) / (b - a), 0, 1)
	return x * x * (3 - 2 * x)
end

function Animation.sample(slot: number, progress: number?, empty: boolean, shotAge: number): Pose
	local pose: Pose = {
		Weapon = CFrame.identity, LeftHand = nil, Magazine = 0, MagazineHidden = false,
		Cover = 0, Belt = 0, Bolt = 0,
	}
	if slot == 2 and shotAge >= 0 and shotAge < 0.11 then
		pose.Bolt = ramp(shotAge, 0, 0.025) * (1 - ramp(shotAge, 0.025, 0.11))
	end
	if progress == nil or progress < 0 or progress >= 1 then return pose end
	local t = progress
	local lift = ramp(t, 0, 0.12) * (1 - ramp(t, 0.88, 1))
	local charge = (empty or slot == 7)
	local reach = if charge then ramp(t, 0.64, 0.72) * (1 - ramp(t, 0.84, 0.93)) else 0
	pose.Bolt = if charge then ramp(t, 0.74, 0.8) * (1 - ramp(t, 0.8, 0.84)) else 0
	local hand: Vector3
	if slot == 7 then
		-- Turn across the chest, hinge the cover forward, lay the belt, close,
		-- then expose the right-side charging handle with a longitudinal roll.
		local turn = lift * (1 - ramp(t, 0.64, 0.73))
		pose.Weapon = CFrame.new(-0.2 * lift, -0.08 * lift, 0.15 * lift)
			* CFrame.Angles(0, math.rad(70) * turn, math.rad(90) * reach)
		pose.Cover = ramp(t, 0.14, 0.24) * (1 - ramp(t, 0.55, 0.64))
		pose.Belt = ramp(t, 0.28, 0.36) * (1 - ramp(t, 0.45, 0.54))
		local hinge = CFrame.new(0, 0.23, -0.605)
		local lid = hinge * CFrame.Angles(math.rad(-100) * pose.Cover, 0, 0) * hinge:Inverse()
		local coverHand = lid:PointToWorldSpace(Vector3.new(-0.2, 0.32, 0.35))
		hand = coverHand:Lerp(Vector3.new(-0.5, 0.15 + pose.Belt * 0.7, -0.35), ramp(t, 0.24, 0.3))
		hand = hand:Lerp(coverHand, ramp(t, 0.54, 0.55))
	else
		pose.Weapon = CFrame.new(-0.12 * lift, 0.08 * lift, 0.12 * lift)
			* CFrame.Angles(math.rad(45) * lift, 0, if slot == 6 then math.rad(90) * reach else 0)
		if slot == 1 then pose.Weapon *= CFrame.new(0, 0, -0.35 * reach) end
		pose.Magazine = ramp(t, 0.23, 0.34) * (1 - ramp(t, 0.47, 0.6))
		pose.MagazineHidden = t > 0.35 and t < 0.46
		local magazine = if slot == 2 then Vector3.new(0, -0.85, 0.3) else Vector3.new(0, -0.65, -0.25)
		hand = magazine + Vector3.new(0, -pose.Magazine * 0.95, 0)
	end
	local handle = if slot == 2 then Vector3.new(-0.18, 0.14, 0.12)
		elseif slot == 1 then Vector3.new(-0.16, 0.15, 0.5)
		else Vector3.new(0.32, 0.07, 0)
	hand = hand:Lerp(handle + Vector3.new(0, 0, pose.Bolt * 0.32), reach)
	-- Enter/leave with the same support anchor, without snapping the wrist.
	local support = if slot == 2 then Vector3.new(-0.2, -0.4, 0.3)
		elseif slot == 7 then Vector3.new(-0.1, -0.2, -1) else Vector3.new(-0.06, -0.13, -0.85)
	pose.LeftHand = support:Lerp(hand, ramp(t, 0.08, 0.19) * (1 - ramp(t, 0.87, 1)))
	return pose
end

function Animation.fromTool(tool: Tool, now: number, shotAge: number?): Pose
	local slot = tool:GetAttribute("WeaponSlot")
	local started = tool:GetAttribute("ReloadStarted")
	local duration = tool:GetAttribute("ReloadDuration")
	local progress = if tool:GetAttribute("Reloading") and typeof(started) == "number"
		and typeof(duration) == "number" and duration > 0 then (now - started) / duration else nil
	return Animation.sample(if typeof(slot) == "number" then slot else 0, progress,
		tool:GetAttribute("ReloadEmpty") == true, shotAge or math.huge)
end

return table.freeze(Animation)
