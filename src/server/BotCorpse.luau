--!strict
local BotCorpse = {}

function BotCorpse.prepare(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	-- Keep the R6 together until our constrained ragdoll takes over.
	humanoid.BreakJointsOnDeath = false
	humanoid.Died:Once(function()
		if not model.Parent then return end
		humanoid:Move(Vector3.zero)
		humanoid.WalkSpeed, humanoid.JumpPower, humanoid.AutoRotate = 0, 0, false
		-- Dead Humanoids otherwise keep rewriting limb collisions during simulation.
		humanoid.EvaluateStateMachine = false
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do track:Stop(0) end
		end
		for _, joint in model:GetDescendants() do
			if not joint:IsA("Motor6D") or not joint.Part0 or not joint.Part1 or joint.Name == "RootJoint" then continue end
			if joint.Part0.Parent ~= model or joint.Part1.Parent ~= model then continue end
			local first, second = Instance.new("Attachment"), Instance.new("Attachment")
			-- Start with coincident anchors, including any pose present at death.
			first.CFrame, first.Parent = joint.Part0.CFrame:ToObjectSpace(joint.Part1.CFrame * joint.C1), joint.Part0
			second.CFrame, second.Parent = joint.C1, joint.Part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0, socket.Attachment1 = first, second
			socket.LimitsEnabled, socket.UpperAngle = true, 55
			socket.TwistLimitsEnabled, socket.TwistLowerAngle, socket.TwistUpperAngle = true, -35, 35
			socket.Parent = joint.Parent
			joint.Enabled = false
		end
		local parts: { BasePart } = {}
		for _, part in model:GetDescendants() do
			if not part:IsA("BasePart") then continue end
			table.insert(parts, part)
			part.Anchored = false
			part.AssemblyLinearVelocity, part.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
			part.CanTouch, part.CanQuery = false, false
			part.CanCollide = part.Parent == model and part.Name ~= "HumanoidRootPart"
			part:SetNetworkOwner(nil)
		end
		local torso = model:FindFirstChild("Torso") :: BasePart?
		local floor = RaycastParams.new()
		floor.FilterDescendantsInstances = { model }
		floor.RespectCanCollide, floor.IgnoreWater = true, true
		floor.CollisionGroup = "Characters"
		if torso then
			-- Small, bounded topple, never inherit running speed or launch the body.
			torso.AssemblyAngularVelocity = torso.CFrame.RightVector * 2
		end
		-- Freeze only a settled body; one bounded coroutine per dead bot.
		task.spawn(function()
			local still = 0
			for _ = 1, 100 do
				task.wait(0.1)
				if not model.Parent or not torso then return end
				local settled = workspace:Raycast(torso.Position, Vector3.new(0, -torso.Size.Magnitude / 2 - 0.25, 0), floor) ~= nil
				for _, part in parts do
					if part.AssemblyLinearVelocity.Magnitude >= 0.3 or part.AssemblyAngularVelocity.Magnitude >= 0.3 then
						settled = false
						break
					end
				end
				if settled then
					still += 1
				else still = 0 end
				if still < 10 then continue end
				for _, part in parts do part.Anchored = true end
				return
			end
		end)
	end)
end

return BotCorpse
