-- Execute the real audio effect with small Roblox object/service stubs.
local created, cleanup = {}, {}
local heartbeat
local Instance = {new = function(class)
	local object = {ClassName=class, Parent=nil}
	function object:Destroy() self.Parent = nil; self.destroyed = true end
	if class == "Sound" then
		object.Ended = {Once=function(_, callback) object.finish = callback end}
		function object:Play() self.played = true end
	end
	table.insert(created, object)
	return object
end}
local game = {GetService=function(_, name)
	if name == "Debris" then return {AddItem=function(_, object, lifetime) cleanup[object] = lifetime end} end
	if name == "RunService" then return {Heartbeat={Connect=function(_,callback) heartbeat=callback end}} end
	return {}
end}
local script={Parent={AudioSettings="audio"}}
local require=function() return {assign=function(sound,channel) sound.channel=channel end} end
local nextHit
local workspace = {Gravity=196.2,Raycast=function() local hit=nextHit; nextHit=nil; return hit end}
local Random = {new=function() return {NextNumber=function(_,a,b) return (a+b)/2 end} end}
local vector={}
local function V(x,y,z) return setmetatable({X=x,Y=y,Z=z},vector) end
vector.__add=function(a,b) return V(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vector.__sub=function(a,b) return V(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vector.__mul=function(a,b) if type(a)=="number" then a,b=b,a end; return V(a.X*b,a.Y*b,a.Z*b) end
vector.__index=function(v,k)
	if k=="Magnitude" then return math.sqrt(v.X^2+v.Y^2+v.Z^2) end
	if k=="Dot" then return function(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
local Vector3 = {new=V}
local frame={}
local function F(x,y,z)
	return setmetatable({Position=if type(x)=="table" then x else V(x or 0,y or 0,z or 0)},frame)
end
frame.__mul=function(a,b) return F(a.Position+b.Position) end
frame.__index=function(v,k)
	if k=="LookVector" then return V(0,0,-1) end
	if k=="Rotation" then return F() end
	if k=="PointToWorldSpace" then return function(self,p) return self.Position+p end end
	if k=="VectorToWorldSpace" then return function(_,p) return p end end
end
local CFrame = {new=F,lookAt=function(position) return F(position) end,Angles=function() return F() end}
local RaycastParams={new=function() return {} end}
local Color3 = {new=function(...) return {...} end,fromRGB=function(...) return {...} end}
local Enum = {Material={SmoothPlastic=1,Neon=2,Metal=3}, RollOffMode={InverseTapered=2},PartType={Ball=1,Cylinder=2}}
local Effects = (function()
-- EFFECTS_MODULE_HERE
end)()
local definition = {ShotSound="rbxassetid://123", ShotVolume=.65, ShotPlaybackSpeed=1.1}
local function shot()
	Effects.sound({0,0,0}, definition)
	return created[#created-1], created[#created]
end
local emitter, sound = shot()
assert(sound.ClassName == "Sound" and sound.Parent == emitter and sound.played)
assert(sound.SoundId == definition.ShotSound and sound.Volume == .65 and sound.PlaybackSpeed == 1.1)
assert(sound.channel=="Gunfire", "shots use the independent gunfire volume group")
assert(emitter.Transparency == 1 and not emitter.CanCollide and not emitter.CanQuery)
assert(sound.RollOffMode == 2 and sound.RollOffMinDistance == 8 and sound.RollOffMaxDistance == 180)
assert(cleanup[emitter] == 5, "unloaded audio must still be cleaned up")
local nextEmitter, nextSound = shot()
assert(nextSound ~= sound and not emitter.destroyed, "rapid shots overlap")
sound.finish()
assert(emitter.destroyed, "finished audio emitter cleaned up")
for i = 1, 40 do shot() end
assert(nextEmitter.destroyed, "concurrent audio bounded to 32 emitters")
local before = #created
Effects.sound({}, {})
assert(#created == before, "weapons without shot audio are ignored")
print("Shot audio: playback, overlap, spatial falloff, cleanup and bounds OK")
local first=#created+1
Effects.flash(V(1,2,3),true,V(0,0,-1))
local core=created[first]
assert(core.Name=="MuzzleFlash" and core.Material==Enum.Material.Neon and cleanup[core]==.055)
assert(not core.CanCollide and not core.CanQuery)
local light=created[#created]
assert(light.ClassName=="PointLight" and light.Brightness==4 and light.Parent==core)
Effects.updateMuzzle(V(10,20,30),V(0,0,-1))
assert(core.CFrame.Position.X==10 and core.CFrame.Position.Y==20)
Effects.clearMuzzle()
assert(core.destroyed, "weapon/character removal clears following flames")
local handle={CFrame=F(20,5,10),Parent=true,IsA=function(_,class) return class=="BasePart" end,
	IsDescendantOf=function(self) return self.Parent~=nil end}
local tool={FindFirstChild=function(_,name) return if name=="Handle" then handle else nil end,
	GetAttribute=function() return 1 end}
local character={FindFirstChildOfClass=function() return tool end}
local gun={Muzzle=V(0,0,-2)}
first=#created+1
local worldFrame=Effects.worldFlash(character,1,gun,V(0,100,0),V(0,0,-1))
local worldCore=created[first]
assert(worldFrame.Position.X==20 and worldFrame.Position.Y==5 and worldFrame.Position.Z==8,
	"other players and bots flash at the replicated barrel, not the reported head/viewmodel origin")
assert(worldCore.Size.X>core.Size.X*2 and cleanup[worldCore]==.1,"world burst remains visible at distance")
handle.CFrame=F(30,6,10)
heartbeat(.016)
assert(worldCore.CFrame.Position.X==30 and worldCore.CFrame.Position.Y==6,"world flash follows the moving gun")
Effects.clearMuzzle()
assert(not worldCore.destroyed,"clearing local viewmodel does not remove other shooters' flashes")
handle.Parent=nil; heartbeat(.016)
assert(worldCore.destroyed,"removed world gun cleans up its flash")
local fallback=Effects.worldFlash(character,2,gun,V(3,4,5),V(0,0,-1))
assert(fallback.Position.X==3,"weapon switch cannot attach old shot to the new weapon")
fallback=Effects.worldFlash(nil,1,gun,V(7,8,9),V(0,0,-1))
assert(fallback.Position.X==7,"missing replicated character still gets a visible fallback burst")
handle.Parent=true
first=#created+1
for _=1,40 do Effects.worldFlash(character,1,gun,V(0,0,0),V(0,0,-1)) end
assert(created[first].destroyed,"simultaneous world flames are bounded")
handle.Parent=nil; heartbeat(.016)
local rifle={EjectionPort=V(.2,.1,-.15),CasingSize=V(.24,.085,.085)}
Effects.casing(F(2,3,-4),rifle)
local shell=created[#created]
assert(shell.Name=="EjectedCasing" and shell.Shape==Enum.PartType.Cylinder)
assert(shell.Anchored and not shell.CanCollide and not shell.CanTouch and not shell.CanQuery)
assert(shell.CFrame.Position.X==2.2 and shell.CFrame.Position.Y==3.1)
heartbeat(.016)
assert(shell.CFrame.Position.X>2.2, "case ejects to the right")
nextHit={Position=V(3,0,0),Normal=V(0,1,0)}
heartbeat(.016)
assert(shell.CFrame.Position.Y==.06, "swept collision keeps shell above floor")
for _=1,45 do Effects.casing(F(),rifle) end
assert(shell.destroyed, "casing count bounded to forty")
heartbeat(3)
for _,obj in created do if obj.Name=="EjectedCasing" then assert(obj.destroyed, "casing expires") end end
local count=#created
Effects.casing(F(),{})
assert(#created==count, "knife/grenades do not eject casings")
print("Shot presentation: directional fire/light, following cleanup, swept casing motion and bounds OK")
