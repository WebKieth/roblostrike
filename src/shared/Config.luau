--!strict

-- Общие настройки доступны и серверу, и клиенту. Не храните здесь секреты.
return table.freeze({
	GameName = "Robostrike",
	Version = "0.2.0",
	RunSpeed = 22,
	WalkSpeed = 10,
	CrouchSpeed = 6,
	CrouchDepth = 0.9,
	RespawnDelay = 3,
	WeaponHUDDuration = 2,
	-- Blue-tiled room: floor Y=0, underside of ceiling Y=10.
	-- This is the HumanoidRootPart position, NOT a SpawnLocation surface.
	SpawnCFrame = CFrame.new(-12.3125, 3.1, -9.8125) * CFrame.Angles(0, math.pi, 0),
})
