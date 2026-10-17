-- Numeric rigid transforms: test the bore after composing BOTH R6 joints.
local Vector3 = {}
local vectorMeta = {}
function Vector3.new(x, y, z) return setmetatable({X=x, Y=y, Z=z}, vectorMeta) end
vectorMeta.__index = function(v, key)
	if key == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
	if key == "Unit" then return v / v.Magnitude end
end
vectorMeta.__add = function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMeta.__sub = function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMeta.__mul = function(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
vectorMeta.__div = function(a,b) return a*(1/b) end
function vectorMeta:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
function vectorMeta:Cross(b) return Vector3.new(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X) end
local oldIndex = vectorMeta.__index
vectorMeta.__index = function(v,k) return vectorMeta[k] or oldIndex(v,k) end
local CFrame = {}
local frameMeta = {}
local function frame(position, rotation)
	return setmetatable({Position=position or Vector3.new(0,0,0), r=rotation or {1,0,0,0,1,0,0,0,1}}, frameMeta)
end
local function rotate(r,v)
	return Vector3.new(r[1]*v.X+r[2]*v.Y+r[3]*v.Z,r[4]*v.X+r[5]*v.Y+r[6]*v.Z,r[7]*v.X+r[8]*v.Y+r[9]*v.Z)
end
frameMeta.__index = function(f, key)
	if key == "pitch" then return math.atan2(f.r[8],f.r[9]) end
	if key == "roll" then return math.atan2(f.r[4],f.r[1]) end
	if key == "LookVector" then return Vector3.new(-f.r[3],-f.r[6],-f.r[9]) end
	if key == "Rotation" then return frame(nil,f.r) end
	if key == "Inverse" then return function()
		local r=f.r
		local transposed={r[1],r[4],r[7],r[2],r[5],r[8],r[3],r[6],r[9]}
		return frame(rotate(transposed,f.Position)*-1,transposed)
	end end
	if key == "VectorToObjectSpace" then return function(_,v) return rotate(f:Inverse().r,v) end end
	if key == "PointToWorldSpace" then return function(_,v) return f.Position+rotate(f.r,v) end end
end
frameMeta.__mul = function(a,b)
	local r={}
	for row=0,2 do for col=0,2 do
		r[row*3+col+1]=0
		for k=0,2 do r[row*3+col+1]+=a.r[row*3+k+1]*b.r[k*3+col+1] end
	end end
	return frame(a:PointToWorldSpace(b.Position),r)
end
CFrame.identity = frame()
CFrame.new = function(p,y,z) return frame(if type(p)=="number" then Vector3.new(p,y,z) else p) end
CFrame.Angles = function(x,y,z)
	local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
	return frame(nil,{1,0,0,0,cx,-sx,0,sx,cx}) * frame(nil,{cy,0,sy,0,1,0,-sy,0,cy}) * frame(nil,{cz,-sz,0,sz,cz,0,0,0,1})
end
CFrame.lookAt = function(p,target)
	local back=(p-target).Unit
	local right=Vector3.new(0,1,0):Cross(back).Unit
	local up=back:Cross(right)
	return frame(p,{right.X,up.X,back.X,right.Y,up.Y,back.Y,right.Z,up.Z,back.Z})
end
local callback, connections, disconnected = nil, 0, false
local simulation = {Connect=function(_, f)
	callback=f; connections+=1
	return {Disconnect=function() disconnected=true end}
end}
local services = {RunService={PreSimulation=simulation}, ReplicatedStorage={Shared={Weapons="weapons"}}}
local game = {GetService=function(_, name) return assert(services[name]) end}
local definitions = (function()
-- WEAPONS_HERE
end)()
local require = function() return definitions end
local Enum = {Material={Air="air"}}
local animation = (function()
-- ANIMATION_MODULE_HERE
end)()
local joints = {}
local gripKind = "Weld"
local grip = {C0=CFrame.new(Vector3.new(0,-0.9,0))*CFrame.Angles(-math.pi/2,0,0), C1=CFrame.new(Vector3.new(0,-0.225,0.585))}
function grip:IsA(kind) return kind==gripKind end
for _, name in {"Left Hip", "Right Hip", "Left Shoulder", "Right Shoulder"} do
	local arm = {Size=Vector3.new(1,2,1)}
	function arm:FindFirstChild()
		return grip
	end
	joints[name] = {Name=name, C0=frame(), C1=frame(), Transform=frame(), Part1=arm,
		IsA=function(_, kind) return kind=="Motor6D" end}
end
joints["Right Shoulder"].C0=CFrame.new(Vector3.new(0.9,0.45,0))*CFrame.Angles(0,math.pi/2,0)
joints["Left Shoulder"].C0=CFrame.new(Vector3.new(-0.9,0.45,0))*CFrame.Angles(0,-math.pi/2,0)
joints["Right Shoulder"].C1=CFrame.Angles(0,math.pi/2,0)
joints["Left Shoulder"].C1=CFrame.Angles(0,-math.pi/2,0)
local humanoid = {Health=100, FloorMaterial="ground"} -- Deliberately no MoveDirection.
local root = {AssemblyLinearVelocity=Vector3.new(0,0,-14), IsA=function() return true end}
local torso = {CFrame=frame(), IsA=function() return true end, GetChildren=function()
	local result={}; for _, joint in joints do table.insert(result,joint) end; return result
end}
local attributes, tool = {}, nil
local character = {Parent=true}
function character:FindFirstChildOfClass(kind) return if kind=="Humanoid" then humanoid else tool end
function character:FindFirstChild(name) return if name=="Torso" then torso else root end
function character:GetScale() return 0.9 end
function character:GetAttribute(name) return attributes[name] end
animation.start(character)
animation.start(character)
assert(connections==1, "do not animate twice")
callback(1/60)
assert(joints["Left Hip"].Transform.pitch~=0, "remote/bot velocity animates legs")
assert(joints["Left Hip"].Transform.pitch == -joints["Right Hip"].Transform.pitch)
root.AssemblyLinearVelocity=Vector3.new(14,0,0)
callback(1/60)
assert(joints["Left Hip"].Transform.roll~=0, "strafe animates legs sideways")
for _, kind in {"Weld", "Motor6D"} do
	gripKind=kind
	for _, slot in {1,2,6,7} do
		tool={GetAttribute=function() return slot end}
		callback(1/60)
		local right,left=joints["Right Shoulder"],joints["Left Shoulder"]
		local hand=right.C0*right.Transform*right.C1:Inverse()
		local gun=hand*grip.C0*grip.C1:Inverse()
		assert((gun.LookVector-Vector3.new(0,0,-1)).Magnitude<1e-6, "world bore must point forward, not into the floor")
		assert(math.abs(gun.Position.Y-0.65*0.9)<1e-6, "weapon must stay at shoulder height")
		for _, entry in {{right,definitions[slot].RightHand},{left,definitions[slot].LeftHand}} do
			local joint,anchor=entry[1],entry[2]
			local arm=joint.C0*joint.Transform*joint.C1:Inverse()
			local wrist=arm:PointToWorldSpace(Vector3.new(0,-joint.Part1.Size.Y/2,0))
			assert((wrist-gun:PointToWorldSpace(anchor*0.9)).Magnitude<1e-6, "both hands must follow weapon anchors")
		end
	end
end
tool=nil
root.AssemblyLinearVelocity=Vector3.new(0,0,0)
for _=1,120 do callback(1/60) end
assert(math.abs(joints["Left Hip"].Transform.pitch)<0.001, "idle stops stepping")
humanoid.Health=0
callback(1/60)
assert(disconnected, "death disconnects the simulation loop")
for _, joint in joints do assert(joint.Transform==CFrame.identity) end
print("Character animation lifecycle OK")
