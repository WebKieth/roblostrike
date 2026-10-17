--!strict

-- Visuals from Roblox's classic catalog gear. Only mesh/texture references;
-- none of the original gear scripts, damage code or remote loaders are used.
-- Sources and upstream revision: assets/stock/README.md.
-- View is camera-local (+X right, -Z forward). Positive yaw turns the muzzle
-- inward from the right shoulder. Hand positions are in rendered mesh space.
-- First-person scale is separate from the world Tool's scale and grip.
return table.freeze({
	table.freeze({
		Name = "Основное оружие",
		ModelName = "M1 Garand",
		AssetId = 94233286,
		MeshId = "rbxassetid://94287666",
		TextureId = "rbxassetid://94287792",
		Icon = "rbxassetid://94295062",
		Scale = Vector3.new(1.3, 1.3, 1.3),
		Size = Vector3.new(0.51, 1.18, 4.35),
		Grip = CFrame.new(0.0645, -0.3971, 0.6851,
			0.86533, -0.02256, 0.50070, 0.10475, 0.98507, -0.13665, -0.49014, 0.17069, 0.85477),
		ViewScale = Vector3.new(0.9, 0.9, 0.9),
		View = CFrame.new(0.8, -0.8, -1.6) * CFrame.Angles(0, math.rad(12), 0),
		RightHand = Vector3.new(0, -0.2, 0.65),
		LeftHand = Vector3.new(-0.12, 0.03, -0.95),
	}),
	table.freeze({
		Name = "Пистолет",
		ModelName = "Luger Pistol",
		AssetId = 95354288,
		MeshId = "rbxassetid://95356090",
		TextureId = "rbxassetid://95387789",
		Icon = "rbxassetid://95356596",
		Scale = Vector3.new(1.8, 1.8, 1.8),
		Size = Vector3.new(0.51, 1.18, 1.35),
		Grip = CFrame.new(0.09395, -0.20621, 0.56036,
			0.83795, -0.02724, 0.54507, -0.02568, 0.99568, 0.08924, -0.54515, -0.08878, 0.83363),
		View = CFrame.new(0.65, -0.8, -1) * CFrame.Angles(0, math.rad(10), 0),
		RightHand = Vector3.new(0, -0.4, 0.3),
	}),
	table.freeze({
		Name = "Нож",
		ModelName = "Mad Murderer Knife",
		AssetId = 170897263,
		MeshId = "rbxassetid://165710339",
		TextureId = "rbxassetid://165710383",
		Icon = "rbxassetid://165710403",
		Scale = Vector3.new(0.5, 0.5, 0.5),
		Size = Vector3.new(0.4, 1.12, 2.6),
		Grip = CFrame.new(0, 0.35, 0.75) * CFrame.Angles(math.rad(-109.3), 0, 0),
		View = CFrame.new(0.65, -0.8, -1.4) * CFrame.Angles(math.rad(-20), 0, 0),
		RightHand = Vector3.new(0, -0.3, 0.3),
	}),
	table.freeze({
		Name = "Граната",
		ModelName = "Grenade",
		AssetId = 232522034,
		MeshId = "rbxassetid://232379763",
		TextureId = "rbxassetid://232379808",
		Icon = "rbxassetid://232379856",
		Scale = Vector3.new(1.5, 1.5, 1.5),
		Size = Vector3.new(0.5, 1, 0.5),
		Grip = CFrame.new(-0.05, -0.25, 0),
		View = CFrame.new(0.6, -0.8, -1.2),
		RightHand = Vector3.new(0, -0.35, 0),
	}),
})
