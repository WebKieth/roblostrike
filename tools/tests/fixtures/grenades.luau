local clock = 10
local os = {clock=function() return clock end}
local mt = {}
local function V(x,y,z) return setmetatable({X=x,Y=y,Z=z},mt) end
mt.__index = function(v,k)
	if k == "Magnitude" then return math.sqrt(v.X^2+v.Y^2+v.Z^2) end
	if k == "Unit" then return v/v.Magnitude end
	if k == "Dot" then return function(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
mt.__add = function(a,b) return V(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
mt.__sub = function(a,b) return V(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
mt.__mul = function(a,b) return V(a.X*b,a.Y*b,a.Z*b) end
mt.__div = function(a,b) return V(a.X/b,a.Y/b,a.Z/b) end
local Vector3 = {new=V, one=V(1,1,1)}
local function typeof(v) return if getmetatable(v)==mt then "Vector3" else type(v) end
local cf = {__mul=function(a) return a end}
local CFrame = {
	new=function(v) return setmetatable({Position=v},cf) end,
	Angles=function() return {} end,
	lookAt=function(origin) return {PointToWorldSpace=function(_,offset) return origin+offset end} end,
}
local function signal()
	local s = {}
	function s:Connect(callback) self.callback=callback; return {Disconnect=function() self.callback=nil end} end
	return s
end
local events = {}
local parts = {}
local Instance = {new=function(class)
	local object = {ClassName=class, Destroy=function(self) self.Destroyed=true end}
	if class=="RemoteEvent" then
		object.OnServerEvent=signal()
		function object:FireAllClients(...) self.count=(self.count or 0)+1; self.last={...} end
		table.insert(events,object)
	elseif class=="Part" then table.insert(parts,object) end
	return object
end}
local Enum = {MeshType={FileMesh=1}}
local Color3 = {fromRGB=function() return {} end}
local RaycastParams = {new=function() return {} end}
local OverlapParams = {new=function() return {} end}
local heartbeat = signal()
local players = {PlayerRemoving=signal()}
local game = {GetService=function(_,name)
	if name=="Players" then return players end
	if name=="RunService" then return {Heartbeat=heartbeat} end
	return {Shared={Weapons="weapons",Grenades="rules",SessionRules="session"},FindFirstChild=function() return nil end}
end}
local rules = (function()
-- RULES_MODULE_HERE
end)()
local definitions = {
	{Grenade="Timed",ModelName="38",Scale=V(1,1,1)},
	{Grenade="Impact",ModelName="69",Scale=V(1,1,1)},
}
local session = (function()
-- SESSION_RULES_HERE
end)()
local script = {Parent={Combat="combat"}}
local require = function(name)
	if name == "combat" then return {feedback=function(event, _, position, damage) event:FireClient("attacker", position, damage) end} end
	return if name=="session" then session elseif name=="rules" then rules else definitions
end
local attributes = {Ammo=3,WeaponSlot=1}
local tool = {
	GetAttribute=function(_,key) return attributes[key] end,
	SetAttribute=function(_,key,value) attributes[key]=value end,
	AncestryChanged=signal(),
}
local humanoid = {Health=100}
local character = {
	GetAttribute=function() return nil end,
	FindFirstChildOfClass=function(_,class) return if class=="Tool" then tool else humanoid end,
	FindFirstChild=function() return {Position=V(0,4,0)} end,
}
tool.Parent=character
local player = {Character=character,GetAttribute=function() return nil end}
local blocked, overlap, projectileHit = false,false,false
local snapshot = {}
local rayCalls = 0
local wall = {IsDescendantOf=function() return false end}
local function hit() return {Position=V(0,4,-1),Normal=V(0,0,1),Instance=wall} end
local workspace = {
	Gravity=196.2,
	GetDescendants=function() return snapshot end,
	GetPartBoundsInRadius=function() return if overlap then {wall} else {} end,
	Spherecast=function(_,origin,radius,travel,filter)
		assert(radius==rules.Radius)
		return if blocked or projectileHit then hit() else nil
	end,
	Raycast=function(_,origin,travel,filter)
		if travel.Y == -256 then return {Position=V(origin.X,0,origin.Z)} end
		rayCalls+=1
		assert(#filter.FilterDescendantsInstances==1, "blast may not exclude any characters")
		if rayCalls==2 then return hit() end -- Back victim is shielded.
		return nil
	end,
}
local damageEvent = {count=0,FireAllClients=function(self) self.count+=1 end}
function damageEvent:FireClient() self.count += 1 end
local server = (function()
-- SERVER_MODULE_HERE
end)()
server.start({WaitForChild=function() return damageEvent end})
local action = events[1].OnServerEvent.callback
local explosion = events[2]
local direction = V(0,0,-1)
local function tick(dt) clock+=dt; heartbeat.callback(dt) end
action(player,"Prime",V(0/0,0,-1),false)
assert(not attributes.Primed, "NaN input rejected")
action(player,"Prime",direction,false)
assert(attributes.Primed and attributes.Ammo==3)
tick(6)
assert(not explosion.count and attributes.Ammo==3, "holding does not start the fuse")
action(player,"Cancel")
assert(not attributes.Primed and attributes.Ammo==3, "cancel preserves grenade")
action(player,"Throw",direction,false)
assert(#parts==0, "throw requires priming")
action(player,"Prime",direction,false)
tool.Parent={}
tool.AncestryChanged.callback()
assert(not attributes.Primed and attributes.Ammo==3, "switch reinserts pin immediately")
tool.Parent=character
tick(.4)
action(player,"Prime",direction,false)
action(player,"Throw",direction,false)
assert(attributes.Ammo==2 and #parts==1 and not attributes.Primed)
tick(4.99)
assert(not explosion.count, "timed grenade must not explode early")
tick(.02)
assert(explosion.count==1 and parts[1].Destroyed, "five seconds after release")
attributes.WeaponSlot=2
action(player,"Prime",direction,false)
overlap=true
tick(.01)
assert(explosion.count==2 and attributes.Ammo==1, "impact grenade explodes in hand on overlap")
overlap=false
tick(.4)
action(player,"Prime",direction,true)
action(player,"Throw",direction,true)
projectileHit=true
tick(.01)
assert(explosion.count==3 and attributes.Ammo==0, "impact projectile explodes at first contact")
tick(.4)
action(player,"Prime",direction,false)
assert(not attributes.Primed, "empty inventory rejected")

-- Visibility is snapshotted before damage, even if the front body dies.
local function victim(position)
	local h = {Health=100, IsA=function(_,class) return class=="Humanoid" end}
	h.Parent={FindFirstChild=function() return {Position=position} end,GetAttribute=function() return false end}
	h.TakeDamage=function(self,damage)
		assert(rayCalls==2, "all occlusion checks must finish before first damage")
		self.Health-=damage
	end
	return h
end
local front,back = victim(V(0,4,-2)),victim(V(0,4,-4))
snapshot={front,back}
attributes.Ammo=1
tick(.4)
action(player,"Prime",direction,false)
blocked=true
tick(.01)
assert(front.Health<0 and back.Health==100, "front body absorbs blast and shields back body")
assert(damageEvent.count==1)
snapshot={}
blocked=false
overlap=true
attributes.Ammo=1
tick(.4)
action(player,"Prime",direction,false)
local count = explosion.count
action(player,"Throw",direction,false)
assert(explosion.count==count+1 and attributes.Ammo==0,
	"quick release cannot bypass contact in an initially overlapping hand")
print("Grenades: fuse, cancel, inventory, impact, overlap and blast occlusion OK")
