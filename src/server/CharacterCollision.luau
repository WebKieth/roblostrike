--!strict
local CharacterCollision = {}

function CharacterCollision.apply(model: Model)
	local function assign(instance: Instance)
		if instance:IsA("BasePart") then
			instance.CollisionGroup = "Characters"
		end
	end
	-- Tools, accessories and decorations can arrive after the initial rig.
	model.DescendantAdded:Connect(assign)
	for _, instance in model:GetDescendants() do assign(instance) end
end

return CharacterCollision
