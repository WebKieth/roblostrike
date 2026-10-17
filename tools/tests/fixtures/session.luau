-- Lightweight services for executing the real round/roster controller offline.
local clock = 10
local os = {clock=function() return clock end}
local function signal()
	local callbacks = {}
	return {
		Connect=function(_, callback) table.insert(callbacks, callback); return {Disconnect=function() end} end,
		Once=function(_, callback) table.insert(callbacks, callback) end,
		Fire=function(_, ...) for _, callback in callbacks do callback(...) end end,
	}
end
local vector = {}
vector.__index = function(v, k) if k == "Magnitude" then return math.sqrt(v.X^2+v.Y^2+v.Z^2) end end
local function V(x,y,z) return setmetatable({X=x,Y=y,Z=z}, vector) end
vector.__sub = function(a,b) return V(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
local Vector3 = {new=V,zero=V(0,0,0)}
local cf = {__mul=function(a) return a end}
cf.__index = {Inverse=function(self) return self end}
local CFrame = {new=function(x,y,z) return setmetatable({Position=V(x,y,z)}, cf) end,Angles=function() return {} end}
local Color3 = {fromRGB=function(...) return {...} end}
local BrickColor = {new=function(v) return v end}
local UDim2 = {fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end}
local Enum = {HumanoidRigType={R6=1},HumanoidDisplayDistanceType={None=1},Font={GothamMedium=1}}
local instances = {}
local methods = {}
local object = {
	__index=function(self, key) return methods[key] or self.props[key] end,
	__newindex=function(self, key, value)
		local previous = self.props[key]
		self.props[key] = value
		if key == "Health" and previous and previous > 0 and value <= 0 then self.Died:Fire() end
	end,
}
local Instance = {new=function(class)
	local self = setmetatable({props={ClassName=class,Name=class},attributes={}}, object)
	table.insert(instances,self)
	if class == "RemoteEvent" then self.OnServerEvent=signal() end
	if class == "Humanoid" then self.Died=signal(); self.Health=100 end
	return self
end}
function methods:IsA(class) return self.ClassName == class or (class == "BasePart" and self.ClassName == "Part") end
function methods:GetChildren()
	local children = {}
	for _, child in instances do if child.Parent == self then table.insert(children,child) end end
	return children
end
function methods:GetDescendants()
	local result = {}
	for _, child in self:GetChildren() do
		table.insert(result,child)
		for _, descendant in child:GetDescendants() do table.insert(result,descendant) end
	end
	return result
end
function methods:FindFirstChild(name, recursive)
	for _, child in (if recursive then self:GetDescendants() else self:GetChildren()) do if child.Name==name then return child end end
	return nil
end
function methods:FindFirstChildOfClass(class)
	for _, child in self:GetChildren() do if child:IsA(class) then return child end end
	return nil
end
function methods:SetAttribute(key,value) self.attributes[key]=value end
function methods:GetAttribute(key) return self.attributes[key] end
function methods:Destroy()
	for _, child in self:GetChildren() do child:Destroy() end
	self.Parent=nil
	self.Destroyed=true
end
function methods:GetPivot() return self:FindFirstChild("HumanoidRootPart").CFrame end
function methods:PivotTo(frame)
	for _, part in self:GetChildren() do if part:IsA("Part") then part.CFrame,part.Position=frame,frame.Position end end
end
function methods:EquipTool(tool) tool.Parent=self.Parent end
function methods:FireAllClients(...) self.last={...} end
function methods:FireClient(recipient, ...) self.recipient=recipient; self.last={...} end
local function character()
	local model = Instance.new("Model")
	local h = Instance.new("Humanoid"); h.Parent=model
	for _, name in {"HumanoidRootPart","Head","Left Arm","Right Arm"} do
		local part = Instance.new("Part"); part.Name,part.Parent=name,model; part.CFrame=CFrame.new(0,0,0)
	end
	return model
end
function methods:Clone() return character() end
local workspace = Instance.new("Workspace")
function workspace:GetServerTimeNow() return clock end
local players = {PlayerAdded=signal(),PlayerRemoving=signal(),list={}}
function players:GetPlayers() return table.clone(self.list) end
function players:GetPlayerFromCharacter(model)
	for _, p in self.list do if p.Character == model then return p end end
	return nil
end
function players:CreateHumanoidModelFromDescriptionAsync() return character() end
local run = {Heartbeat=signal(),IsStudio=function() return false end}
local replicated,teams = Instance.new("ReplicatedStorage"),Instance.new("Teams")
replicated.Shared={SessionRules="rules"}
local game = {CreatorId=85,GetService=function(_,name)
	return ({Players=players,ReplicatedStorage=replicated,RunService=run,Teams=teams})[name]
end}
local rules = (function()
-- SESSION_RULES_HERE
end)()
local capturedSlots
local loadout = {create=function()
	local tool=Instance.new("Tool"); tool:SetAttribute("WeaponSlot",1); tool:SetAttribute("Ammo",30); tool:SetAttribute("ReserveAmmo",90)
	return tool
end,find=function(player) return player.Character:FindFirstChildOfClass("Tool") end}
local skin = {description=function() return Instance.new("HumanoidDescription") end,apply=function() end}
local script = {Parent={PoliceSkin="skin",Loadout="loadout",Bots="bots"}}
local require = function(name)
	return ({rules=rules,skin=skin,loadout=loadout,bots={start=function(slots) capturedSlots=slots end}})[name]
end
local delayed={}
local task = {
	spawn=function(callback,...) callback(...) end,
	defer=function(callback,...) callback(...) end,
	delay=function(seconds,callback) table.insert(delayed,{at=clock+seconds,callback=callback}) end,
}
local remotes=Instance.new("Folder")
local session=(function()
-- SESSION_MODULE_HERE
end)()
local function add(id)
	local p=Instance.new("Player"); p.Name,p.UserId,p.Parent="Player"..id,id,players
	table.insert(players.list,p); players.PlayerAdded:Fire(p)
	return p
end
local friend=add(100)
local spawnCount=0
session.start(remotes,function(player,frame)
	spawnCount+=1
	local model=character(); model.Name=player.Name; model:PivotTo(frame)
	if player.Character then player.Character:Destroy() end
	player.Character=model; model.Parent=workspace
	loadout.create().Parent=model
	return model
end)
local state=replicated:FindFirstChild("SessionState")
local choose=remotes:FindFirstChild("ChooseTeam").OnServerEvent
local menu=remotes:FindFirstChild("TeamMenu").OnServerEvent
local function tick(seconds) clock+=seconds; run.Heartbeat:Fire(seconds) end
assert(state:GetAttribute("Phase")=="WaitingAdmin" and spawnCount==0 and not friend.Character)
choose:Fire(friend,"Blue")
assert(friend:GetAttribute("TeamId")==nil)
local admin=add(85)
assert(state:GetAttribute("Phase")=="Lobby" and friend:GetAttribute("TeamMenuOpen"))
choose:Fire(admin,"Blue")
assert(state:GetAttribute("Phase")=="Freeze" and spawnCount==1)
assert(admin.Character:FindFirstChild("HumanoidRootPart").Anchored and admin:GetAttribute("SessionBlocked"))
assert(admin.Character:FindFirstChild("PlayerNickname",true))
local blueBots,redBots=0,0
for _, s in capturedSlots.Blue do if not s.player then blueBots+=1; assert(not s.model:FindFirstChild("PlayerNickname",true)) end end
for _, s in capturedSlots.Red do if not s.player then redBots+=1 end end
assert(blueBots==4 and redBots==5)
tick(2.99)
assert(state:GetAttribute("Phase")=="Freeze")
tick(.02)
assert(state:GetAttribute("Phase")=="Combat" and not admin:GetAttribute("SessionBlocked"))
assert(not admin.Character:FindFirstChild("HumanoidRootPart").Anchored)
for _, s in capturedSlots.Red do
	s.model:FindFirstChildOfClass("Humanoid").Health=42
	s.model:SetAttribute("Armor",60)
	s.model:FindFirstChildOfClass("Tool"):SetAttribute("Ammo",7)
end
choose:Fire(friend,"Red")
assert(friend.Character and friend:GetAttribute("TeamId")=="Red")
assert(friend.Character:FindFirstChildOfClass("Humanoid").Health==42 and friend.Character:GetAttribute("Armor")==60)
assert(friend.Character:FindFirstChildOfClass("Tool"):GetAttribute("Ammo")==7, "takeover preserves bot ammo")
local before=friend.Character
local beforeHumanoid=before:FindFirstChildOfClass("Humanoid")
menu:Fire(friend,true)
assert(before:FindFirstChild("HumanoidRootPart").Anchored and before:FindFirstChildOfClass("Humanoid").Health==42)
menu:Fire(friend,false)
assert(not before:FindFirstChild("HumanoidRootPart").Anchored)
tick(.6); menu:Fire(friend,true); choose:Fire(friend,"Red")
assert(beforeHumanoid.Health==0 and spawnCount==2, "same-team selection kills, never respawns")
for _, s in capturedSlots.Red do if s.model then s.model:FindFirstChildOfClass("Humanoid").Health=0 end end
tick(.1)
assert(state:GetAttribute("Phase")=="Intermission" and state:GetAttribute("BlueWins")==1)
tick(4.1)
assert(state:GetAttribute("Phase")=="Freeze" and state:GetAttribute("Round")==2)
assert(friend.Character~=before and friend.Character:FindFirstChildOfClass("Humanoid").Health==100)
tick(3.1)
for _, s in capturedSlots.Red do if not s.player then s.model:FindFirstChildOfClass("Humanoid").Health=0 end end
local late=add(101)
local previousSpawns=spawnCount
choose:Fire(late,"Red")
assert(not late.Character and spawnCount==previousSpawns, "joining a dead bot cannot resurrect")
for id=102,104 do choose:Fire(add(id),"Red") end
local excess=add(105); choose:Fire(excess,"Red")
assert(excess:GetAttribute("TeamId")==nil and excess:GetAttribute("TeamMenuError"))
tick(.1)
assert(state:GetAttribute("Phase")=="Combat", "living human keeps team in round")
friend.Character:FindFirstChildOfClass("Humanoid").Health=0
tick(.1)
assert(state:GetAttribute("BlueWins")==2)
-- Simultaneous elimination is a draw and does not increment either score.
tick(4.1); tick(3.1)
for _, roster in capturedSlots do for _, s in roster do s.model:FindFirstChildOfClass("Humanoid").Health=0 end end
tick(.1)
assert(state:GetAttribute("Winner")=="Draw" and state:GetAttribute("BlueWins")==2 and state:GetAttribute("RedWins")==0)
tick(4.1); tick(3.1)
friend.Character:FindFirstChildOfClass("Humanoid").Health=37
players.PlayerRemoving:Fire(friend)
local replacement
for _, s in capturedSlots.Red do
	if not s.player and s.model and s.model:GetAttribute("Bot") then replacement=s.model end
end
assert(replacement and replacement:FindFirstChildOfClass("Humanoid").Health==37, "disconnect backfills bot without a fresh life")
players.PlayerRemoving:Fire(admin)
assert(state:GetAttribute("Phase")=="WaitingAdmin" and state:GetAttribute("BlueWins")==0)
assert(not friend:GetAttribute("TeamId"))
print("Session: admin gate, 5v5, freeze, takeover, menus, elimination, draw and shutdown OK")
