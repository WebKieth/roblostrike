-- Real Loot controller: independent cooldowns, automatic pickups, ballistic wall collision.
local vmt = {}
local function V(x,y,z) return setmetatable({X=x,Y=y,Z=z},vmt) end
vmt.__index = function(v,k)
	if k == "Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
	if k == "Unit" then return v / v.Magnitude end
end
vmt.__add = function(a,b) return V(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vmt.__sub = function(a,b) return V(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vmt.__mul = function(a,b)
	if type(b)=="number" then return V(a.X*b,a.Y*b,a.Z*b) end
	return V(a.X*b.X,a.Y*b.Y,a.Z*b.Z)
end
vmt.__div = function(a,b) return V(a.X/b,a.Y/b,a.Z/b) end
local Vector3 = {new=V}
local CFrame = {new=function(position, y, z)
	return {Position=if type(position)=="number" then V(position,y,z) else position or V(0,0,0)}
end}
local Color3 = {fromRGB=function(...) return {} end}
local UDim2 = {fromOffset=function(...) return {} end, fromScale=function(...) return {} end}
local Enum = {PartType={Ball=1},RaycastFilterType={Exclude=1}}
local function signal()
	local callbacks = {}
	return {Connect=function(_,f) table.insert(callbacks,f) end,
		Fire=function(_,...) for _,f in callbacks do f(...) end end}
end
local methods = {}
function methods:IsA(class) return self.ClassName==class or (class=="BasePart" and self.ClassName=="Part") end
function methods:GetChildren() return table.clone(self.children) end
function methods:GetDescendants()
	local all = {}
	for _,child in self.children do
		table.insert(all,child)
		for _,desc in child:GetDescendants() do table.insert(all,desc) end
	end
	return all
end
function methods:FindFirstChild(name)
	for _,child in self.children do if child.Name==name then return child end end
	return nil
end
function methods:FindFirstChildOfClass(class)
	for _,child in self.children do if child:IsA(class) then return child end end
	return nil
end
function methods:SetAttribute(k,v) self.attrs[k]=v end
function methods:GetAttribute(k) return self.attrs[k] end
function methods:PivotTo(frame) self.PrimaryPart.Position=frame.Position end
function methods:Destroy() self.Parent=nil end
local mt = {
	__index=function(self,k) return methods[k] or self.props[k] end,
	__newindex=function(self,k,v)
		if k=="Parent" then
			local old = self.props.Parent
			if old then for i,child in old.children do if child==self then table.remove(old.children,i) break end end end
			if v then table.insert(v.children,self) end
		end
		self.props[k]=v
	end,
}
local Instance = {new=function(class)
	return setmetatable({props={ClassName=class,OnServerEvent=signal()},attrs={},children={}},mt)
end}
function methods:Clone()
	local clone = Instance.new(self.ClassName)
	clone.Name=self.Name
	return clone
end
local clock = 0
local os = {clock=function() return clock end}
local heartbeat = signal()
local player = Instance.new("Player")
local character = Instance.new("Model")
local backpack = Instance.new("Backpack")
backpack.Parent=player
local root = Instance.new("Part")
root.Name="HumanoidRootPart"
root.Position=V(100,3.1,100)
root.CFrame={LookVector=V(1,0,0)}
root.Parent=character
local humanoid = Instance.new("Humanoid")
humanoid.Health=100
humanoid.Parent=character
player.Character=character
local players = {GetPlayers=function() return {player} end,PlayerRemoving=signal()}
local storage = Instance.new("Folder")
local wall: number? = nil
local workspace = Instance.new("Folder")
workspace.Gravity=196.2
workspace.FallenPartsDestroyHeight=-500
workspace.Raycast=function() return nil end
workspace.Spherecast=function(_,origin,radius,delta)
	local t = math.huge
	local normal = nil
	if delta.Y<0 and origin.Y+delta.Y<=radius then
		t=(radius-origin.Y)/delta.Y
		normal=V(0,1,0)
	end
	if wall and delta.X>0 and origin.X+delta.X>=wall-radius then
		local tw=(wall-radius-origin.X)/delta.X
		if tw<t and tw>=0 then t=tw; normal=V(-1,0,0) end
	end
	if t<=1 then return {Distance=delta.Magnitude*t,Normal=normal} end
	return nil
end
local RaycastParams = {new=function() return {} end}
local survival = (function()
-- SURVIVAL_MODULE_HERE
end)()
local loadout = {}
local weapons = {
	[1]={Magazine=30,HotbarSlot=1}, [2]={Magazine=17},
	[6]={Magazine=30,HotbarSlot=1}, [7]={Magazine=100,HotbarSlot=1},
}
function loadout.create(slot)
	local tool = Instance.new("Tool")
	tool.Name="Gun"..slot
	tool:SetAttribute("WeaponSlot",slot)
	tool:SetAttribute("Ammo",slot==1 and 30 or 17)
	tool:SetAttribute("ReserveAmmo",slot==1 and 90 or 51)
	local handle = Instance.new("Part")
	handle.Name="Handle"; handle.Parent=tool
	return tool
end
function loadout.find(_,slot)
	for _,container in {character,backpack} do
		for _,tool in container:GetChildren() do
			if tool:IsA("Tool") and tool:GetAttribute("WeaponSlot")==slot then return tool end
		end
	end
	return nil
end
function loadout.equip(_,slot)
	local tool = loadout.findHotbar(player,slot)
	if tool then tool.Parent=character end
end
function loadout.findHotbar(_,slot)
	for id,definition in weapons do
		if (definition.HotbarSlot or id)==slot then
			local tool=loadout.find(player,id)
			if tool then return tool end
		end
	end
end
local game = {GetService=function(_,name)
	if name=="Players" then return players end
	if name=="ReplicatedStorage" then return {Shared={Survival="survival",Weapons="weapons"}} end
	if name=="RunService" then return {Heartbeat=heartbeat} end
	return storage
end}
local script = {Parent={Loadout="loadout"}}
local require = function(name) return if name=="survival" then survival else if name=="weapons" then weapons else loadout end
local Loot = (function()
-- LOOT_MODULE_HERE
end)()
local remotes = Instance.new("Folder")
Loot.start(remotes)
local folder = workspace:FindFirstChild("Loot")
local function step(dt) clock+=dt; heartbeat:Fire(dt) end
local function count() return #folder:GetChildren() end
assert(count()==12, "six items in each room")
root.Position=V(-10,3.1,-10)
step(.1)
assert(character:GetAttribute("Armor")==100 and not character:GetAttribute("Helmet"))
assert(count()==11)
step(.1)
assert(count()==11, "full armor leaves loot untouched")
root.Position=V(3,3.1,-10)
step(.1)
assert(count()==11 and not character:GetAttribute("Helmet"), "no upgrade pickup with full armor")
character:SetAttribute("Armor",80)
step(.1)
assert(count()==10 and character:GetAttribute("Helmet"))
root.Position=V(100,3.1,100)
step(59.71)
assert(count()==11, "first armor respawns after its own 60 seconds")
step(.3)
assert(count()==12, "second armor has independent timer")
root.Position=V(-25,3.1,-10)
player:SetAttribute("SelectedSlot",1)
step(.1)
local gun = loadout.find(player,1)
assert(gun and gun.Parent==character and count()==11, "auto pickup into empty slot")
gun:SetAttribute("Ammo",7)
gun:SetAttribute("ReserveAmmo",23)
root.Position=V(0,3.1,-10)
local drop = remotes:FindFirstChild("DropWeapon")
drop.OnServerEvent:Fire(player)
assert(not loadout.find(player,1) and count()==12)
assert(character:GetAttribute("DroppedSlot1"))
step(.01)
assert(not loadout.find(player,1), "cannot reclaim in flight")
for _=1,50 do step(.01) end
assert(not loadout.find(player,1), "one metre throw lands beyond pickup reach")
local dropped = folder:GetChildren()[#folder:GetChildren()]
local landing = dropped.PrimaryPart.Position
assert(math.abs(landing.X-survival.DropDistance)<.3 and landing.Y>.5)
root.Position=V(landing.X,3.1,-10)
step(.1)
assert(loadout.find(player,1)==gun and gun:GetAttribute("Ammo")==7 and gun:GetAttribute("ReserveAmmo")==23)
-- Wall stops the arc and allows immediate reclaim once it falls nearby.
root.Position=V(0,3.1,-10)
wall=1.5
drop.OnServerEvent:Fire(player)
assert(not loadout.find(player,1))
for _=1,50 do step(.01) end
assert(loadout.find(player,1)==gun, "near-wall throw falls and automatically returns")
-- Same model replenishes reserve only, capped at three spare magazines.
root.Position=V(-25,3.1,-65)
local before=count()
step(.1)
assert(count()==before-1 and gun:GetAttribute("ReserveAmmo")==90)
assert(gun:GetAttribute("Ammo")==7, "pickup does not silently reload the current magazine")
root.Position=V(-25,3.1,-10)
step(60)
before=count()
step(.1)
assert(count()==before, "full reserve leaves identical weapon untouched")
root.Position=V(-25,3.1,-6)
before=count()
step(.1)
assert(count()==before and not loadout.find(player,6), "different primary cannot refill or replace M4")
gun:Destroy()
step(.1)
local ak=loadout.find(player,6)
assert(ak and ak.Parent==character, "AK picked up and equipped through hotbar key 1")
root.Position=V(-18,3.1,-6)
before=count()
step(.1)
assert(count()==before and not loadout.find(player,7), "only one primary can be carried")
ak:Destroy()
step(.1)
assert(loadout.find(player,7), "M249 available in the room")
print("Loot: auto pickup, independent cooldowns, preserved ammo, arc, wall and reclaim OK")
