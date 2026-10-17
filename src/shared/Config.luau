--!strict

-- Общие настройки доступны и серверу, и клиенту. Не храните здесь секреты.
return table.freeze({
	GameName = "Robostrike",
	Version = "0.2.0",
	RunSpeed = 19.8,
	WalkSpeed = 9,
	CrouchSpeed = 5.4,
	BotSpeed = 14.4,
	CrouchDepth = 0.9,
	RespawnDelay = 3,
	WeaponHUDDuration = 2,
	CharacterScale = 0.9,
	ViewmodelScale = 0.9,
	-- Blue-tiled room: floor Y=0, underside of ceiling Y=10.
	-- This is the HumanoidRootPart position, NOT a SpawnLocation surface.
	SpawnCFrame = CFrame.new(-14, 3.1, 4) * CFrame.Angles(0, math.pi, 0),
})
