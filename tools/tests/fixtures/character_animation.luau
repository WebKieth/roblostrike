-- Symbolic frames test pose selection/lifecycle, not Roblox joint geometry.
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
local CFrame = {}
local frameMeta = {}
local function frame(pitch, roll, position)
	return setmetatable({pitch=pitch or 0, roll=roll or 0, Position=position or Vector3.new(0,0,0)}, frameMeta)
end
frameMeta.__index = function(f, key)
	if key == "Rotation" then return frame(f.pitch, f.roll) end
	if key == "Inverse" then return function() return frame(-f.pitch,-f.roll) end end
	if key == "VectorToObjectSpace" or key == "PointToWorldSpace" then return function(_, v) return v end end
end
frameMeta.__mul = function(a,b) return frame(a.pitch+b.pitch,a.roll+b.roll) end
CFrame.identity = frame()
CFrame.Angles = function(x, _, z) return frame(x,z) end
CFrame.lookAt = function(p) return frame(0,0,p) end
local callback, connections, disconnected = nil, 0, false
local simulation = {Connect=function(_, f)
	callback=f; connections+=1
	return {Disconnect=function() disconnected=true end}
end}
local services = {RunService={PreSimulation=simulation}, ReplicatedStorage={Shared={Weapons="weapons"}}}
local game = {GetService=function(_, name) return assert(services[name]) end}
local require = function() return {{Procedural=true, LeftHand=Vector3.new(0,0,-1)}} end
local Enum = {Material={Air="air"}}
local animation = (function()
-- ANIMATION_MODULE_HERE
end)()
local joints = {}
local gripKind = "Weld"
for _, name in {"Left Hip", "Right Hip", "Left Shoulder", "Right Shoulder"} do
	local arm = {Size=Vector3.new(1,2,1)}
	function arm:FindFirstChild()
		return {C0=frame(), C1=frame(), IsA=function(_, kind) return kind==gripKind end}
	end
	joints[name] = {Name=name, C0=frame(), C1=frame(), Transform=frame(), Part1=arm,
		IsA=function(_, kind) return kind=="Motor6D" end}
end
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
tool={GetAttribute=function() return 1 end}
callback(1/60)
assert(joints["Left Shoulder"].Transform.pitch>1, "support arm uses Weld grip")
gripKind="Motor6D"
callback(1/60)
assert(joints["Left Shoulder"].Transform.pitch>1, "also support motor grips")
tool=nil
root.AssemblyLinearVelocity=Vector3.new(0,0,0)
for _=1,120 do callback(1/60) end
assert(math.abs(joints["Left Hip"].Transform.pitch)<0.001, "idle stops stepping")
humanoid.Health=0
callback(1/60)
assert(disconnected, "death disconnects the simulation loop")
for _, joint in joints do assert(joint.Transform==CFrame.identity) end
print("Character animation lifecycle OK")
