local vector = {}
vector.__index = function(v, key)
	if key == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
	if key == "Unit" then return v / v.Magnitude end
	if key == "Dot" then return function(a,b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end end
end
local function V(x,y,z) return setmetatable({X=x,Y=y,Z=z}, vector) end
vector.__add = function(a,b) return V(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vector.__sub = function(a,b) return V(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vector.__mul = function(a,b) return V(a.X*b,a.Y*b,a.Z*b) end
vector.__div = function(a,b) return V(a.X/b,a.Y/b,a.Z/b) end
local Vector3 = {new=V}
local CFrame = {lookAt=function() return {} end}
local RaycastParams = {new=function() return {} end}
local Random = {new=function() return {NextNumber=function(_,a) return a end} end}
local heartbeat
local run = {Heartbeat={Connect=function(_,callback) heartbeat=callback end}}
local obstacle=false
local workspace = {Raycast=function(_,_,_,filter)
	if filter.RespectCanCollide and obstacle then return {} end
	return nil
end}
local replicated = {Shared={Weapons="weapons"}}
local game = {GetService=function(_, name)
	return ({RunService=run,ReplicatedStorage=replicated,PathfindingService={}})[name]
end}
local script = {Parent={Combat="combat"}}
local require = function() return {} end
local bots = (function()
-- BOTS_MODULE_HERE
end)()
local function actor(x,z)
	local humanoid = {Health=100,MoveTo=function(self,position) self.destination=position end}
	local root = {Position=V(x,3.1,z),SetNetworkOwner=function() end}
	return {Parent=true,FindFirstChildOfClass=function() return humanoid end,
		FindFirstChild=function(_,name) return root end}, humanoid, root
end
local bot,h,root = actor(0,0)
local human,_,humanRoot = actor(3,0)
local enemy = actor(100,0)
bots.start({Blue={{model=bot},{player=true,model=human}},Red={{player=true,model=enemy}}},
	{GetAttribute=function() return "Combat" end}, {})
heartbeat(.1)
assert(h.destination.X < 0, "bot retreats instead of crowding a nearby human")
obstacle=true
heartbeat(.1)
assert(h.destination.X == 0, "blocked retreat stops; never moves into a wall")
obstacle=false
humanRoot.Position=V(5.5,3.1,0)
heartbeat(.1)
assert(h.destination.X == 0, "bot yields before approaching a human")
humanRoot.Position=V(20,3.1,0)
heartbeat(.1)
assert(h.destination.X == 100, "clear route still advances toward the enemy")
humanRoot.Position=root.Position
heartbeat(.1)
assert(h.destination.X == 0, "overlap does not normalize a zero vector")
print("Bot spacing: retreat, wall clearance, yielding and normal movement OK")
