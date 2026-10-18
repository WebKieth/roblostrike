--!strict
local RunService = game:GetService("RunService")
local Visibility = {}

function Visibility.start(player: Player)
	local character: Model? = nil
	local parts: { [BasePart]: number } = {}
	local added: RBXScriptConnection? = nil
	local function clear()
		if added then added:Disconnect(); added = nil end
		for part, original in parts do
			if part.Parent then part.LocalTransparencyModifier = original end
		end
		table.clear(parts)
		character = nil
	end
	local function bind(model: Model)
		clear()
		character = model
		local function hide(instance: Instance)
			if instance:IsA("BasePart") then
				if parts[instance] == nil then parts[instance] = instance.LocalTransparencyModifier end
				instance.LocalTransparencyModifier = 1
			end
		end
		added = model.DescendantAdded:Connect(hide)
		for _, instance in model:GetDescendants() do hide(instance) end
	end
	player.CharacterAdded:Connect(bind)
	player.CharacterRemoving:Connect(function(model)
		if model == character then clear() end
	end)
	if player.Character then bind(player.Character) end
	-- Roblox's camera transparency controller does not handle all custom shells.
	-- Run after it and hide the entire world rig, never the camera's viewmodel.
	RunService:BindToRenderStep("RobostrikeHideBody", Enum.RenderPriority.Camera.Value + 3, function()
		for part, original in parts do
			if part.Parent and character and part:IsDescendantOf(character) then
				part.LocalTransparencyModifier = 1
			else
				-- Dropped tools leave the rig but must become visible in the world.
				if part.Parent then part.LocalTransparencyModifier = original end
				parts[part] = nil
			end
		end
	end)
end

return Visibility
