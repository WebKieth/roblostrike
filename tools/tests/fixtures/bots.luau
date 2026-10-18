local clock = 10
local os = {clock = function() return clock end}
local mt = {}
local function V(x, y, z) return setmetatable({X=x, Y=y, Z=z}, mt) end
mt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X^2 + v.Y^2 + v.Z^2) end
	if k == "Unit" then return v / v.Magnitude end
	if k == "Dot" then return function(a, b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end end
end
mt.__add = function(a,b) return V(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
mt.__sub = function(a,b) return V(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
mt.__mul = function(a,b) return V(a.X*b, a.Y*b, a.Z*b) end
mt.__div = function(a,b) return V(a.X/b, a.Y/b, a.Z/b) end
local Vector3 = {new=V}
local CFrame = {new=function(p) return {Position=p} end, lookAt=function(p) return {Position=p} end}
local RaycastParams = {new=function() return {} end}
local Random = {new=function() return {NextNumber=function(_, a, b) return (a+b)/2 end} end}
local wall = {IsDescendantOf=function() return false end}
local hidden, blocked, gap, cover = false, false, false, false
local sightCalls = 0
local workspace = {}
function workspace:Blockcast() return if blocked then {} else nil end
function workspace:Raycast(origin, delta, params)
	if params.RespectCanCollide then
		if delta.X == 0 and delta.Z == 0 and delta.Y < 0 then
			return if gap then nil else {Position=V(origin.X, 0, origin.Z), Normal=V(0,1,0)}
		end
		-- The left half of the test arena is hidden behind cover.
		local endpoint = origin + delta
		if cover and math.min(origin.X, endpoint.X) < -3 then return {Instance=wall} end
		return nil
	end
	sightCalls += 1
	return if hidden then {Instance=wall} else nil
end
local Tactics = (function()
-- TACTICS_MODULE_HERE
end)()
assert(Tactics.mode(100, false, false, 1, 2) == "Engage")
assert(Tactics.mode(35, false, false, 1, 2) == "Retreat", "low HP")
assert(Tactics.mode(100, true, false, 1, 2) == "Retreat", "reload")
assert(Tactics.mode(100, false, true, 1, 2) == "Retreat", "recent damage")
assert(Tactics.mode(100, false, false, 3, 1) == "Retreat", "outnumbered")
assert(Tactics.score(48,8,0,0,true,false,true,0) > Tactics.score(48,0,1,0,false,true,true,0), "cover beats exposed retreat")
assert(Tactics.score(34,8,1,0,false,true,false,0) > Tactics.score(34,8,1,6,false,true,false,0), "spread out")
local origin, threat = V(0,2.7,0), V(0,4.2,-34)
local rig = {Head={Position=origin+V(0,1.5,0)}}
local geometry = {RespectCanCollide=true}
local right = Tactics.choose(rig, origin, threat, {threat}, {}, false, 1, geometry, false)
local left = Tactics.choose(rig, origin, threat, {threat}, {}, false, -1, geometry, false)
assert(right.X > 0 and left.X < 0, "roles take opposite flanks")
local pressure = Tactics.choose(rig, origin, threat, {threat}, {}, false, 0, geometry, false)
assert(pressure.Z < origin.Z, "centre role presses toward contact")
assert(Tactics.score(24,0,0,0,false,true,false,0) > Tactics.score(34,0,0,0,false,true,false,0), "healthy bots favour closer pressure")
local crowded = Tactics.choose(rig, origin, threat, {threat}, {origin, origin+V(0,0,-4)}, false, 1, geometry, false)
assert((crowded-origin).Magnitude > 10, "spread beyond the old eight-stud crowd radius")
blocked = true
assert(Tactics.choose(rig, origin, threat, {threat}, {}, false, 1, geometry, false) == origin, "no movement through walls")
assert(Tactics.choose(rig, origin, threat, {}, {}, true, 1, geometry, false, true) == origin, "forced movement still respects walls")
blocked, gap = false, true
assert(Tactics.choose(rig, origin, threat, {threat}, {}, false, 1, geometry, false) == origin, "no movement into gaps/pool")
gap, cover = false, true
local safe = Tactics.choose(rig, origin, threat, {threat}, {}, true, 1, geometry, false)
assert(safe.X < -3, "reload selects actual cover")
local coverRig = {Head={Position=safe+V(0,1.5,0)}}
local peek = Tactics.choose(coverRig, safe, threat, {}, {}, false, 1, geometry, true)
assert(peek.X >= -3, "healthy bot leaves cover for a firing angle")
cover = false
local forced = Tactics.choose(rig, origin, threat, {}, {}, true, 0, geometry, false, true)
assert((forced-origin).Magnitude>=8, "forced replan cannot select the current cover point")

local heartbeat = {Connect=function(self, callback) self.callback=callback end}
local pathFails, deferred, pathCount = false, false, 0
local jobs = {}
local task = {spawn=function(callback)
	if deferred then table.insert(jobs, callback) else callback() end
end}
local paths = {CreatePath=function()
	pathCount += 1
	return {
		Status=if pathFails then "Failed" else "Success",
		ComputeAsync=function(self, start, goal) self.start, self.goal = start, goal end,
		GetWaypoints=function(self) return {{Position=self.start}, {Position=self.goal}} end,
	}
end}
local Weapons = {{ReloadTime=2.3, Magazine=30, Range=300, DamageMultiplier=1}}
local Rules = {TeamSize=3, BotAimBase=2.25, BotAimDistance=0.035, BotThinkBudget=16, BotSightCandidates=6, spawn=function(_, index) return {Position=V(index*10,2.7,-70)} end}
Rules.BotStationarySeconds, Rules.BotProgressDistance = 5, 3
local game = {GetService=function(_, name)
	if name == "PathfindingService" then return paths end
	if name == "RunService" then return {Heartbeat=heartbeat} end
	return {Shared={Weapons=Weapons, SessionRules=Rules}}
end}
local script = {Parent={Combat={damage=function() error("no damage expected") end}, BotTactics=Tactics}}
local require = function(module) return module end
local Enum = {PathStatus={Success="Success"}, PathWaypointAction={Jump="Jump"}}
local function actor(position)
	local model = {Parent=true, attributes={}}
	model.HumanoidRootPart = {Position=position, SetNetworkOwner=function() end}
	model.Head = {Position=position+V(0,1.5,0)}
	model.h = {Health=100, MoveTo=function(self, goal) self.goal=goal end}
	model.tool = {Ammo=30, GetAttribute=function(self, k) return self[k] end, SetAttribute=function(self,k,v) self[k]=v end}
	function model:FindFirstChildOfClass(class) return if class == "Humanoid" then self.h else self.tool end
	function model:FindFirstChild(name) return self[name] end
	function model:SetAttribute(k,v) self.attributes[k]=v end
	return model
end
local Bots = (function()
-- BOTS_MODULE_HERE
end)()
local bot, enemy = actor(origin), actor(V(0,2.7,-34))
local slots = {Blue={{model=bot}}, Red={{model=enemy, player=true}}}
local phase = "Combat"
local state = {GetAttribute=function() return phase end}
local shots = 0
local remotes = {ShotEffect={FireAllClients=function() shots += 1 end}}
local function tick(dt) clock += dt; heartbeat.callback(dt) end
Bots.start(slots, state, remotes)
hidden = true
tick(.1)
assert(bot.attributes.BotTactic == "Patrol", "unseen opponent must not be tracked")
assert(bot.h.goal.X == 10 and bot.h.goal.Z == -70, "patrol known map objective, not hidden enemy")
hidden = false
tick(.1)
assert(bot.attributes.BotTactic == "Engage")
assert(shots == 0, "reaction delay retained")
tick(1.7)
assert(shots == 1, "normal visible burst")
hidden = true
enemy.HumanoidRootPart.Position = V(200,2.7,200)
enemy.Head.Position = V(200,4.2,200)
tick(.2)
assert(bot.attributes.BotTactic == "Search")
assert(bot.h.goal.X < 50 and bot.h.goal.Z < 50, "search remembers old position")
assert(shots == 1, "no shots through walls")
bot.tool.Ammo = 0
tick(.1)
assert(bot.attributes.BotTactic == "Retreat" and bot.tool.Reloading, "reload changes tactics")
tick(2.4)
assert(bot.tool.Ammo == 30 and not bot.tool.Reloading, "reload completes behind cover")
tick(8)
assert(bot.attributes.BotTactic == "Patrol", "contact memory expires")
hidden = false
bot.h.Health = 90
tick(.1)
assert(bot.attributes.BotTactic == "Retreat", "taking damage triggers a short retreat even above low HP")
bot.h.Health = 30
tick(.1)
assert(bot.attributes.BotTactic == "Retreat", "wounded bot does not charge")
bot.h.Health = 100
hidden = true
tick(8)
pathFails = true
blocked = true
tick(2)
assert(bot.attributes.PathFailed and bot.h.goal == origin, "failed paths stop instead of blind rushing")
pathFails, deferred = false, true
tick(2)
assert(#jobs > 0)
phase = "Intermission"
heartbeat.callback(.1)
for _, job in jobs do job() end
assert(bot.attributes.PathFailed, "late path must not be applied outside combat")
local before = shots
tick(5)
assert(shots == before, "round freeze")
-- Large sessions spread perception work across heartbeats instead of one 64-rig spike.
phase,hidden,deferred = "Combat",true,false
local large={Blue={},Red={}}
for index=1,32 do
	large.Blue[index]={model=actor(V(index*12,2.7,0))}
	large.Red[index]={model=actor(V(index*12,2.7,-80)),player=true}
end
Bots.start(large,state,remotes)
sightCalls=0
tick(.1)
local processed=0
for _,slot in large.Blue do if slot.model.attributes.BotTactic then processed+=1 end end
assert(processed==Rules.BotThinkBudget and sightCalls<=Rules.BotThinkBudget*Rules.BotSightCandidates, "bounded perception work")
tick(.1)
for _,slot in large.Blue do assert(slot.model.attributes.BotTactic=="Patrol", "round robin must not starve later bots") end
-- Deterministic camping decision: ordinary replans insist on holding cover.
local originalChoose=Tactics.choose
local forcedPlans=0
Tactics.choose=function(model,position,threat,enemies,allies,retreat,side,geometry,peek,force)
	if force then forcedPlans+=1; return originalChoose(model,position,threat,enemies,allies,retreat,side,geometry,peek,true) end
	return position
end
blocked,hidden=false,false
local camper=actor(origin)
Bots.start({Blue={{model=camper}},Red={{model=actor(threat),player=true}}},state,remotes)
tick(.1); tick(4.9)
assert(forcedPlans==0 and camper.h.goal==origin,"do not force a move before five seconds")
tick(.11)
assert(forcedPlans==1 and (camper.h.goal-origin).Magnitude>=3,"stationary camper gets a real escape destination")
camper.HumanoidRootPart.Position=camper.h.goal
camper.Head.Position=camper.h.goal+V(0,1.5,0)
tick(.1)
assert(forcedPlans==1,"actual movement resets stationary timer")
phase="Intermission"; tick(20); phase="Combat"; tick(.1)
assert(forcedPlans==1,"round freeze does not count as camping")
print("Bot tactics and lifecycle OK")
