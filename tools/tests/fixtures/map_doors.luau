local clock=0
local os={clock=function() return clock end}
local mt={}
local function V(x,y,z) return setmetatable({X=x,Y=y,Z=z},mt) end
mt.__add=function(a,b) return V(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
mt.__sub=function(a,b) return V(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
mt.__mul=function(a,b) return V(a.X*b,a.Y*b,a.Z*b) end
mt.__index=function(v,k) if k=="Magnitude" then return math.sqrt(v.X^2+v.Y^2+v.Z^2) end end
local Vector3={new=V,one=V(1,1,1)}
local cf={}
cf.__index=cf
cf.__add=function(a,b) return setmetatable({Position=a.Position+b},cf) end
function cf:PointToObjectSpace(p) return p-self.Position end
local CFrame={new=function(x,y,z) return setmetatable({Position=V(x,y,z)},cf) end}
local function signal()
	local listeners={}
	return {Connect=function(_,fn)
		local connection={active=true,Disconnect=function(self) self.active=false end}
		table.insert(listeners,{fn,connection})
		return connection
	end,Fire=function(_,dt) for _,pair in listeners do if pair[2].active then pair[1](dt) end end end}
end
local run={Heartbeat=signal()}
local tweens={}
local tweenService={Create=function(_,panel,info,target)
	local tween={target=target.CFrame,Cancel=function(self) self.cancelled=true end,Play=function(self) self.played=true end}
	table.insert(tweens,tween)
	return tween
end}
local game={GetService=function(_,name) return if name=="RunService" then run else tweenService end}
local Enum={RaycastFilterType={Exclude=1},EasingStyle={Linear=1}}
local TweenInfo={new=function(...) return {...} end}
local OverlapParams={new=function() return {} end}
local nearby={}
local workspace={GetPartBoundsInBox=function() return nearby end}
local panel={CFrame=CFrame.new(0,5,0),Position=V(0,5,0),Size=V(1,10,20)}
local door={attributes={},parented=true}
function door:IsA(class) return class=="Model" end
function door:FindFirstChild(name)
	if name=="Panel" then return panel end
	if name=="Motion" then return {Value="Vertical",IsA=function(_,class) return class=="StringValue" end} end
end
function door:SetAttribute(k,v) self.attributes[k]=v end
function door:IsDescendantOf() return self.parented end
local map={FindFirstChild=function(_,name) if name=="Doors" then return {GetChildren=function() return {door} end} end end}
local function actor(x,y,z,health,accessory)
	local root={Position=V(x,y,z),IsA=function(_,class) return class=="BasePart" end}
	local model={FindFirstChildOfClass=function() return {Health=health or 100} end,
		FindFirstChild=function() return root end}
	return {Parent=if accessory then {} else model,FindFirstAncestorOfClass=function() return model end},root
end
local Doors=(function()
-- MAP_DOORS_HERE
end)()
Doors.start(map)
local function tick(dt) clock+=dt; run.Heartbeat:Fire(dt) end
local radius=2/.28
assert(door.attributes.SensorRadiusMetres==2 and not door.attributes.Open)
local part,root=actor(.5+radius+.01,3.1,0)
nearby={part}; tick(.05)
assert(#tweens==0,"outside two metres must not open")
root.Position=V(.5+radius,3.1,9.5); tick(.05)
assert(#tweens==1 and door.attributes.Open and tweens[1].target.Position.Y>15,
	"within two metres at wide door edge opens upwards")
tick(.2)
assert(#tweens==1,"standing still in sensor keeps the door open")
nearby={}; tick(.05); tick(.35)
assert(#tweens==1,"short sensor exit must not chatter")
panel.Position=V(0,15.15,0); tick(.1)
assert(#tweens==2 and not door.attributes.Open and tweens[2].target.Position.Y==5,
	"empty sensor closes downward")
panel.Position=V(0,9,0)
part,root=actor(-.5-radius+.01,3.1,0); nearby={part}; tick(.05)
assert(tweens[2].cancelled and door.attributes.Open and #tweens==3,
	"entry from opposite side reverses closing immediately")
local dead=actor(0,3.1,0,0)
local weapon=actor(0,3.1,0,100,true)
nearby={dead,weapon}; tick(.05); tick(.5)
assert(not door.attributes.Open,"dead bodies and protruding accessories do not trigger sensor")
door.parented=false; tick(.05)
assert(tweens[#tweens].cancelled,"map unload cancels animation")
local count=#tweens
nearby={part}; tick(1)
assert(#tweens==count,"unloading disconnects sensor heartbeat")
print("Lift doors: 2m threshold, edge distance, both sides, hold, close, safety reversal, actor filter, cleanup OK")
