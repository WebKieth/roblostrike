local clock = 10
local os = {clock = function() return clock end}
local function signal()
	return {Connect = function(self, callback)
		self.callback = callback
		return {Disconnect = function() self.callback = nil end}
	end}
end
local mt = {}
mt.__index = function(v, key)
	if key == "Magnitude" then return math.sqrt(v.X^2 + v.Y^2 + v.Z^2) end
	if key == "Unit" then return v / v.Magnitude end
end
local function V(x,y,z) return setmetatable({X=x,Y=y,Z=z}, mt) end
mt.__add = function(a,b) return V(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
mt.__mul = function(a,b) return V(a.X*b,a.Y*b,a.Z*b) end
mt.__div = function(a,b) return V(a.X/b,a.Y/b,a.Z/b) end
local function typeof(v) return if getmetatable(v) == mt then "Vector3" else type(v) end
local frame = {LookVector=V(0,0,-1), VectorToObjectSpace=function(_,v) return v end}
local CFrame = {lookAt=function() return frame end, Angles=function() return frame end}
setmetatable(frame, {__mul=function() return frame end})
local Enum = {RaycastFilterType={Exclude=1}}
local RaycastParams = {new=function() return {} end}
local rules = (function()
-- RULES_MODULE_HERE
end)()
local survival = (function()
-- SURVIVAL_MODULE_HERE
end)()
local players, run = {PlayerRemoving=signal()}, {Heartbeat=signal()}
local game = {GetService=function(_,name)
	return if name == "Players" then players elseif name == "RunService" then run
		else {Shared={Weapons="weapons",Knife="rules",Survival="survival",SessionRules="session"}}
end}
local script = {Parent={Combat="combat"}}
local combat
local session = (function()
	local Color3 = {fromRGB=function(...) return {...} end}
-- SESSION_RULES_HERE
end)()
local require = function(name)
	if name == "session" then return session end
	if name == "rules" then return rules end
	if name == "survival" then return survival end
	if name == "combat" then return combat end
	return {{Knife=true}}
end
local event
local Instance = {new=function()
	event = {OnServerEvent=signal()}
	return event
end}
local numbers = {FireAllClients=function(self,_,damage) self.damage=damage; self.count=(self.count or 0)+1 end}
function numbers:FireClient(_, position, damage) self:FireAllClients(position, damage) end
local remotes = {WaitForChild=function() return numbers end}
local tool = {GetAttribute=function() return 1 end,AncestryChanged=signal()}
local alive = {Health=100}
local head = {Position=V(0,0,0),Size=V(2,1,1),CFrame=frame}
local character = {
	GetPivot=function() return {Position=head.Position} end,
	GetAttribute=function() return nil end,
	FindFirstChildOfClass=function(_,name) return if name == "Tool" then tool else alive end,
	FindFirstChild=function() return head end,
}
tool.Parent = character
local player = {Character=character,GetAttribute=function() return nil end}
players.GetPlayerFromCharacter = function(_, model) return if model == character then player else nil end
local attrs = {Armor=100,Helmet=true}
local victim = {Health=1000,TakeDamage=function(self,n) self.Health-=n end}
local body = {
	IsA=function(_,name) return name == "Model" end,
	FindFirstChildOfClass=function() return victim end,
	FindFirstChild=function() return head end,
	GetAttribute=function(_,name) return attrs[name] end,
	SetAttribute=function(_,name,v) attrs[name]=v end,
}
victim.Parent = body
local part = {Name="Torso",Parent=body,IsA=function() return false end}
local distance, blocked, rays = 1, false, 0
local wall = {Name="Wall",IsA=function() return false end}
local workspace = {Raycast=function(_,origin,direction,params)
	rays+=1
	assert(params.FilterDescendantsInstances[1] == character)
	if blocked then return {Instance=wall,Position=origin} end
	if distance <= direction.Magnitude then return {Instance=part,Position=origin} end
	return nil
end}
combat = (function()
-- COMBAT_MODULE_HERE
end)()
local knife = (function()
-- KNIFE_MODULE_HERE
end)()
knife.start(remotes)
local action = event.OnServerEvent.callback
local function tick(age) clock=10+age; run.Heartbeat.callback() end
local dir = V(0,0,-1)
action(player,"Slash",dir)
tick(.099); assert(rays == 0)
tick(.10001); assert(numbers.damage == 21 and attrs.Armor == 80)
tick(.15); assert(numbers.count == 1, "one contact per attack")
action(player,"Stab",dir)
tick(.3); assert(numbers.count == 1, "mixed attacks share cooldown")
clock=11; action(player,"Stab",dir)
clock=11.299; run.Heartbeat.callback(); assert(numbers.count == 1)
clock=11.4; run.Heartbeat.callback(); assert(numbers.damage == 105 and attrs.Armor == 60)
clock=12; action(player,"Slash",dir)
distance = .5 + rules.Slash.Reach + .001
clock=12.15; run.Heartbeat.callback(); assert(numbers.count == 2, "outside reach")
clock=12.201; distance=1; run.Heartbeat.callback(); assert(numbers.count == 2, "late entry misses")
clock=13; action(player,"Stab",dir)
distance = .5 + rules.Stab.Reach - .001
clock=13.4; run.Heartbeat.callback(); assert(numbers.count == 3, "longer stab reach")
clock=14; action(player,"Slash",dir); blocked=true
clock=14.15; run.Heartbeat.callback(); assert(numbers.count == 3, "wall blocks blade")
clock=15; action(player,"Slash",dir); blocked=false; distance=1
tool.Parent={}; tool.AncestryChanged.callback(); tool.Parent=character
clock=15.15; run.Heartbeat.callback(); assert(numbers.count == 3, "unequip cancels even after re-equip")
clock=16; action(player,"Stab",dir); action(player,"Cancel")
clock=16.4; run.Heartbeat.callback(); assert(numbers.count == 3)
action(player,"Slash",dir); run.Heartbeat.callback(); assert(numbers.count == 3, "cancel preserves cooldown")
clock=17; action(player,"Slash",V(0/0,0,-1)); tick(7.15); assert(numbers.count == 3)
alive.Health=0; clock=18; action(player,"Slash",dir); tick(8.15); assert(numbers.count == 3)
for _,attack in {rules.Slash,rules.Stab} do
	assert(not rules.active(attack,attack.HitStart-.001))
	assert(rules.active(attack,attack.HitStart) and rules.active(attack,attack.HitEnd))
	assert(not rules.active(attack,attack.HitEnd+.001))
end
for _,name in {"Head","Torso","Left Arm","Right Leg"} do
	local base = survival.ReferenceDamage[survival.zone(name)]
	assert(survival.damage(name,0,false,.6) == math.round(base*.6))
	assert(survival.damage(name,0,false,3) == base*3)
end
print("Knife: server windows, reach, cooldown, armor, walls and cancellation OK")
