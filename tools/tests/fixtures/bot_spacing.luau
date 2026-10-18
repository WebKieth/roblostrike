local vector = {}
local clock=0
local os={clock=function() return clock end}
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
local CFrame = {lookAt=function() return {} end,new=function(p) return {Position=p} end}
local RaycastParams = {new=function() return {} end}
local Random = {new=function() return {NextNumber=function(_,a) return a end} end}
local heartbeat
local run = {Heartbeat={Connect=function(_,callback) heartbeat=callback end}}
local obstacle=false
local workspace = {Blockcast=function() return if obstacle then {} else nil end, Raycast=function(_,origin,delta,filter)
	if filter.RespectCanCollide and obstacle then return {} end
	if filter.RespectCanCollide and delta.X==0 and delta.Z==0 and delta.Y<0 then
		return {Position=V(origin.X,0,origin.Z),Normal=V(0,1,0)}
	end
	return nil
end}
local tactics = (function()
-- TACTICS_MODULE_HERE
end)()
local replicated = {Shared={Weapons="weapons",SessionRules="rules"}}
local game = {GetService=function(_, name)
	return ({RunService=run,ReplicatedStorage=replicated,PathfindingService={}})[name]
end}
local script = {Parent={Combat="combat",BotTactics="tactics"}}
local require = function(name)
	if name=="weapons" then return {{Range=500,Magazine=30,ReloadTime=2}} end
	if name=="tactics" then return tactics end
	if name=="rules" then return {TeamSize=3,BotAimBase=2.25,BotAimDistance=0.035,BotThinkBudget=16,BotSightCandidates=6,BotStationarySeconds=5,BotProgressDistance=3} end
	return {}
end
local bots = (function()
-- BOTS_MODULE_HERE
end)()
local function actor(x,z)
	local humanoid = {Health=100,MoveTo=function(self,position) self.destination=position end}
	local root = {Position=V(x,3.1,z),SetNetworkOwner=function() end}
	local tool={ammo=30,GetAttribute=function(self) return self.ammo end,SetAttribute=function(self,_,v) self.ammo=v end}
	return {Parent=true,HumanoidRootPart=root,Head=root,SetAttribute=function() end,
		FindFirstChildOfClass=function(_,class) return if class=="Tool" then tool else humanoid end,
		FindFirstChild=function(_,name) return root end}, humanoid, root, tool
end
local bot,h,root,tool = actor(0,0)
local human,_,humanRoot = actor(3,0)
local enemy,enemyHumanoid = actor(100,0)
local shots=0
local roster={Blue={{model=bot},{player=true,model=human}},Red={{player=true,model=enemy}}}
bots.start(roster, {GetAttribute=function() return "Combat" end},
	{ShotEffect={FireAllClients=function() shots+=1 end}})
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
assert(h.destination.X > 0 and h.destination.X <= 16, "clear route advances by a checked tactical step")
humanRoot.Position=root.Position
heartbeat(.1)
assert(h.destination.X == 0, "overlap does not normalize a zero vector")
local function tick(dt) clock+=dt; heartbeat(dt) end
tick(.8)
assert(shots==0, "new target requires reaction time")
tick(.11)
assert(shots==1 and tool.ammo==29)
tick(.23); tick(.23)
assert(shots==3, "short three-shot burst")
tick(.5)
assert(shots==3, "pause after the burst")
tick(.31)
assert(shots==4)
local replacement=actor(90,0)
roster.Red[1].model=replacement
tick(.3)
assert(shots==4, "switching targets restarts reaction time")
tick(.8)
assert(shots==4)
tick(.11)
assert(shots==5)
tick(2)
assert((h.destination-root.Position).Magnitude>=3, "after five seconds even overlapping bots must leave the spot")
print("Bot spacing: retreat, wall clearance, yielding and normal movement OK")
