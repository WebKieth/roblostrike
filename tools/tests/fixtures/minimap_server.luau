local mt={}
local function V(x,y,z) return setmetatable({X=x,Y=y,Z=z},mt) end
mt.__sub=function(a,b) return V(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
mt.__div=function(a,b) return V(a.X/b,a.Y/b,a.Z/b) end
mt.__index=function(v,k)
	if k=="Magnitude" then return math.sqrt(v.X^2+v.Y^2+v.Z^2) end
	if k=="Unit" then return v/v.Magnitude end
	if k=="Dot" then return function(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
local callback,event
local Instance={new=function()
	event={FireClient=function(self,player,packet) player.packet=packet end}
	return event
end}
local players={}
local Rules={MinimapInterval=.25,MinimapSightRange=300,MinimapSightDot=.5}
local game={GetService=function(_,name)
	if name=="Players" then return {GetPlayers=function() return players end} end
	if name=="RunService" then return {Heartbeat={Connect=function(_,fn) callback=fn end}} end
	return {Shared={SessionRules=Rules}}
end}
local require=function(v) return v end
local RaycastParams={new=function() return {} end}
local blocked=false
local workspace={Raycast=function(_,origin,delta,filter)
	assert(filter.IgnoreWater and #filter.FilterDescendantsInstances>=2)
	return if blocked then {} else nil
end}
local function actor(x,z,forward)
	local h={Health=100}
	local root={Position=V(x,3,z),CFrame={LookVector=forward}}
	local head={Position=V(x,4.5,z)}
	return {Parent=true,h=h,root=root,
		FindFirstChildOfClass=function() return h end,
		FindFirstChild=function(_,name) return if name=="Head" then head else root end}
end
local function player(team)
	local p={attributes={TeamId=team,InSession=true},GetAttribute=function(self,k) return self.attributes[k] end}
	table.insert(players,p)
	return p
end
local blue,red,outsider=player("Blue"),player("Red"),player("Blue")
outsider.attributes.InSession=false
local self=actor(0,0,V(0,0,1))
local ally=actor(10,0,V(0,0,-1))
local enemy=actor(10,-20,V(0,0,1))
local slots={Blue={{model=self,player=blue},{model=ally}},Red={{model=enemy,player=red}}}
local phase="Combat"
local Minimap=(function()
-- SERVER_MINIMAP_HERE
end)()
Minimap.start(slots,{GetAttribute=function() return phase end},{})
callback(.1); assert(not blue.packet,"bounded update frequency")
callback(.15)
assert(#blue.packet==3 and blue.packet[3].enemy,"enemy spotted by ally shared with the player")
assert(#red.packet==3 and #outsider.packet==0,"separate team packets; no contacts outside session")
blocked=true; callback(.25)
assert(#blue.packet==2 and #red.packet==1,"walls hide enemies but not allies")
blocked=false; ally.root.CFrame.LookVector=V(0,0,1); callback(.25)
assert(#blue.packet==2,"opponent behind all observers is hidden")
ally.root.CFrame.LookVector=V(0,0,-1)
enemy.h.Health=0; callback(.25)
assert(#blue.packet==2,"dead opponents removed")
enemy.h.Health=100; ally.h.Health=0; callback(.25)
assert(#blue.packet==1,"dead allies cannot spot")
ally.h.Health=100
slots.Red[1].model=actor(10,-1000,V(0,0,1)); callback(.25)
assert(#blue.packet==2,"sight range is bounded")
phase="Intermission"; callback(.25)
assert(#blue.packet==0 and #red.packet==0,"round transition clears contacts")
print("Server minimap visibility OK")
