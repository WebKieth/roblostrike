-- Verify ragdoll lifecycle and bounded settling; collision simulation needs Studio.
local zero={Magnitude=0}
local Vector3={zero=zero,new=function(...) return {...} end}
local RaycastParams={new=function() return {} end}
local supported=true
local workspace={Raycast=function() return if supported then {} else nil end}
local frame={RightVector=nil}
function frame:ToObjectSpace(value) return value end
setmetatable(frame,{__mul=function(_,value) return value end})
local direction=setmetatable({}, {__mul=function() return {Magnitude=2} end})
local methods={}
function methods:IsA(class) return self.class==class end
function methods:SetNetworkOwner(owner) self.owner=owner; self.serverOwned=true end
local function object(class, props)
	props=props or {}; props.class=class
	return setmetatable(props,{__index=methods})
end
local created={}
local Instance={new=function(class)
	local result=object(class); table.insert(created,result); return result
end}
local callback
local stopped=false
local animator={GetPlayingAnimationTracks=function() return {{Stop=function(_,fade) assert(fade==0); stopped=true end}} end}
local humanoid={Died={Once=function(_,f) callback=f end},Move=function(_,v) assert(v==zero) end,
	FindFirstChildOfClass=function() return animator end}
local model={Parent=true}
frame.RightVector=direction
local torso=object("BasePart",{Name="Torso",Parent=model,CFrame=frame,Size={Magnitude=3}})
local root=object("BasePart",{Name="HumanoidRootPart",Parent=model})
local head=object("BasePart",{Name="Head",Parent=model,CFrame=frame})
local accessory=object("BasePart",{Name="Handle",Parent={}})
local neck=object("Motor6D",{Name="Neck",Part0=torso,Part1=head,C0="first",C1="second",Enabled=true,Parent=torso})
local rootJoint=object("Motor6D",{Name="RootJoint",Part0=root,Part1=torso,Enabled=true})
local descendants={root,torso,head,accessory,neck,rootJoint}
function model:GetDescendants() return descendants end
function model:FindFirstChildOfClass() return humanoid end
function model:FindFirstChild(name) return if name=="Torso" then torso else nil end
local pending
local waits=0
local task={spawn=function(f) pending=f end,wait=function()
	waits+=1
	assert(not torso.Anchored, "body must not freeze during the fall")
	if waits>=3 then torso.AssemblyAngularVelocity=zero end
	-- A still torso alone must not freeze a moving limb, nor freeze midair.
	head.AssemblyAngularVelocity=if waits<6 then {Magnitude=1} else zero
	supported=waits>=8
end}
local Corpse=(function()
-- CORPSE_MODULE_HERE
end)()
Corpse.prepare(model)
assert(humanoid.BreakJointsOnDeath==false and callback)
callback()
assert(stopped and not humanoid.AutoRotate and humanoid.WalkSpeed==0)
assert(humanoid.EvaluateStateMachine==false, "Humanoid must relinquish corpse collision control")
assert(not neck.Enabled and rootJoint.Enabled, "ragdoll limbs but keep invisible root attached")
assert(#created==3 and created[3].class=="BallSocketConstraint")
assert(created[3].Attachment0.CFrame=="second" and created[3].Attachment1.CFrame=="second")
for _,part in {root,torso,head,accessory} do
	assert(not part.Anchored and part.AssemblyLinearVelocity==zero and part.serverOwned)
	assert(not part.CanTouch and not part.CanQuery)
end
assert(torso.CanCollide and head.CanCollide and not root.CanCollide and not accessory.CanCollide)
assert(torso.AssemblyAngularVelocity.Magnitude==2)
pending()
assert(waits==17 and torso.Anchored and head.Anchored and model.Parent, "wait for all limbs and floor support; retain corpse")
-- Destroyed round models must cancel the pending settling job immediately.
model.Parent=true
callback()
model.Parent=nil
pending()
assert(waits==18)
print("BotCorpse: intact R6, bounded topple, server ownership, settling and round cleanup OK")
