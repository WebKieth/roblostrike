-- Lightweight services for executing the real round/roster controller offline.
local scenario="default"
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
local CFrame = {new=function(x,y,z) return setmetatable({Position=if type(x)=="table" then x else V(x,y,z)}, cf) end,Angles=function() return {} end}
local Color3 = {fromRGB=function(...) return {...} end}
local BrickColor = {new=function(v) return v end}
local UDim2 = {fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end}
local Enum = {HumanoidRigType={R6=1},HumanoidDisplayDistanceType={None=1},Font={GothamMedium=1},
	RaycastFilterType={Exclude=1},HumanoidStateType={Jumping=1}}
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
	if class == "Humanoid" then self.Died=signal(); self.Health=100; self.AutoRotate=true; self.JumpPower=35; self.HipHeight=0 end
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
function methods:Move(direction) self.MoveDirection=direction end
function methods:SetStateEnabled(state, enabled) self.jumpEnabled=enabled end
function methods:SetNetworkOwner(owner)
	assert(not self.Anchored, "ownership must be restored after unanchoring")
	self.owner=owner
end
function methods:FireAllClients(...) self.last={...} end
function methods:FireClient(recipient, ...) self.recipient=recipient; self.last={...} end
local function character()
	local model = Instance.new("Model")
	model.DescendantAdded=signal()
	local h = Instance.new("Humanoid"); h.Parent=model
	for _, name in {"HumanoidRootPart","Head","Left Arm","Right Arm"} do
		local part = Instance.new("Part"); part.Name,part.Parent=name,model; part.CFrame=CFrame.new(0,0,0)
		part.AssemblyLinearVelocity=V(4,-2,5)
		model[name]=part
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
local templateCount=0
function players:CreateHumanoidModelFromDescriptionAsync() templateCount+=1; return character() end
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
local collision = (function()
-- COLLISION_MODULE_HERE
end)()
local probe=character()
collision.apply(probe)
for _, part in probe:GetDescendants() do
	if part:IsA("BasePart") then assert(part.CollisionGroup=="Characters") end
end
local accessory=Instance.new("Part")
probe.DescendantAdded:Fire(accessory)
assert(accessory.CollisionGroup=="Characters", "late-added parts must not push characters")
local movement = (function()
	local game={GetService=function() return {Shared={Config="config"}} end}
	local require=function() return {RunSpeed=22,WalkSpeed=10,CrouchSpeed=6,CrouchDepth=1.2} end
	local OverlapParams={new=function() return {} end}
-- MOVEMENT_MODULE_HERE
end)()
local script = {Parent={PoliceSkin="skin",Loadout="loadout",Bots="bots",CharacterCollision="collision",Movement="movement"}}
local require = function(name)
	return ({rules=rules,skin=skin,loadout=loadout,collision=collision,movement=movement,bots={start=function(slots) capturedSlots=slots end}})[name]
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
	model.HumanoidRootPart.Anchored=false
	model.HumanoidRootPart:SetNetworkOwner(player)
	movement.add(player,model)
	loadout.create().Parent=model
	return model
end)
local state=replicated:FindFirstChild("SessionState")
local choose=remotes:FindFirstChild("ChooseTeam").OnServerEvent
local menu=remotes:FindFirstChild("TeamMenu").OnServerEvent
local setup=remotes:FindFirstChild("SessionSetup").OnServerEvent
local function tick(seconds) clock+=seconds; run.Heartbeat:Fire(seconds) end
assert(state:GetAttribute("Phase")=="WaitingAdmin" and spawnCount==0 and not friend.Character)
choose:Fire(friend,"Blue")
assert(friend:GetAttribute("TeamId")==nil)
local admin=add(85)
assert(state:GetAttribute("Phase")=="Lobby" and friend:GetAttribute("TeamMenuOpen"))
assert(admin:GetAttribute("SessionAdmin") and not friend:GetAttribute("SessionAdmin"))
setup:Fire(friend,"Bots",0)
assert(state:GetAttribute("BotsPerTeam")==3, "only admin can configure")
for _,value in {-1,4,.5,math.huge,0/0,"0"} do setup:Fire(admin,"Bots",value) end
assert(state:GetAttribute("BotsPerTeam")==3, "reject invalid bot counts")
if scenario=="no_bots" then
	setup:Fire(admin,"Bots",0)
	setup:Fire(admin,"Start")
	assert(state:GetAttribute("SetupError") and not state:GetAttribute("Started"))
	choose:Fire(admin,"Blue")
	assert(spawnCount==0 and not state:GetAttribute("Started"), "team choice cannot bypass setup")
	setup:Fire(admin,"Start")
	assert(state:GetAttribute("SetupError") and state:GetAttribute("Phase")=="Lobby", "no-bot game needs both teams")
	choose:Fire(friend,"Red")
	setup:Fire(friend,"Start")
	assert(state:GetAttribute("Phase")=="Lobby", "non-admin cannot launch")
	setup:Fire(admin,"Start")
	assert(state:GetAttribute("Started") and state:GetAttribute("Phase")=="Freeze" and spawnCount==2)
	for _,roster in capturedSlots do
		for _,s in roster do if not s.player then assert(not s.model, "no filler bots") end end
	end
	assert(templateCount==0, "no bot assets requested in human-only mode")
	tick(3.1); tick(.1)
	assert(state:GetAttribute("Phase")=="Combat")
	setup:Fire(admin,"Bots",3)
	assert(state:GetAttribute("BotsPerTeam")==0, "configuration locked after launch")
	players.PlayerRemoving:Fire(friend)
	for _,s in capturedSlots.Red do assert(not s.player and not s.model, "no disconnect backfill") end
	tick(.1); tick(4.1)
	assert(state:GetAttribute("Phase")=="Lobby", "wait when one human team becomes empty")
	local wins=state:GetAttribute("BlueWins")
	tick(30)
	assert(state:GetAttribute("Phase")=="Lobby" and state:GetAttribute("BlueWins")==wins, "no empty-team win loop")
	choose:Fire(add(101),"Red")
	assert(state:GetAttribute("Phase")=="Freeze", "joining opponent resumes rounds")
	assert(templateCount==0)
	players.PlayerRemoving:Fire(admin)
	assert(not state:GetAttribute("Started") and state:GetAttribute("BotsPerTeam")==3)
	print("Session: human-only setup, validation, no backfill, and waiting/resume OK")
	return
elseif scenario=="one_bot" then
	setup:Fire(admin,"Bots",1)
	choose:Fire(admin,"Blue")
	setup:Fire(admin,"Start")
	assert(state:GetAttribute("Phase")=="Freeze")
	local function bots(id)
		local count=0
		for _,s in capturedSlots[id] do if s.model and not s.player then count+=1 end end
		return count
	end
	assert(bots("Blue")==1 and bots("Red")==1)
	assert(templateCount==1)
	tick(3.1)
	choose:Fire(friend,"Red")
	assert(friend.Character and bots("Red")==0, "joining replaces a configured bot")
	friend.Character:FindFirstChildOfClass("Humanoid").Health=37
	players.PlayerRemoving:Fire(friend)
	assert(bots("Red")==1, "allowed backfill stays within bot budget")
	print("Session: one bot per team, sparse slots and budgeted backfill OK")
	return
end
choose:Fire(admin,"Blue")
assert(state:GetAttribute("Phase")=="Lobby" and spawnCount==0)
setup:Fire(friend,"Start")
assert(state:GetAttribute("Phase")=="Lobby")
setup:Fire(admin,"Start")
assert(state:GetAttribute("Phase")=="Freeze" and spawnCount==1)
assert(not admin.Character.HumanoidRootPart.Anchored and admin:GetAttribute("SessionBlocked"))
assert(admin.Character:FindFirstChildOfClass("Humanoid").WalkSpeed==0)
assert(admin.Character:FindFirstChildOfClass("Humanoid").JumpPower==0)
assert(admin.Character.HumanoidRootPart.owner==admin, "ownership stays with player throughout freeze")
assert(admin.Character.HumanoidRootPart.AssemblyLinearVelocity.Y==-2, "freeze preserves gravity/settling")
assert(admin.Character.HumanoidRootPart.AssemblyLinearVelocity.X==0, "freeze cancels horizontal motion")
assert(admin.Character:FindFirstChild("PlayerNickname",true))
local blueBots,redBots=0,0
for _, s in capturedSlots.Blue do if not s.player then blueBots+=1; assert(not s.model:FindFirstChild("PlayerNickname",true)) end end
for _, s in capturedSlots.Red do
	if not s.player then
		redBots+=1
		assert(not s.model.HumanoidRootPart.Anchored and s.model:FindFirstChildOfClass("Humanoid").WalkSpeed==0)
	end
end
assert(rules.TeamSize==3 and blueBots==2 and redBots==3)
tick(2.99)
assert(state:GetAttribute("Phase")=="Freeze")
movement.step(.1)
assert(not admin.Character.HumanoidRootPart.Anchored and admin.Character:FindFirstChildOfClass("Humanoid").WalkSpeed==0)
tick(.02)
assert(state:GetAttribute("Phase")=="Combat" and not admin:GetAttribute("SessionBlocked"))
assert(not admin.Character:FindFirstChild("HumanoidRootPart").Anchored)
assert(admin.Character:FindFirstChild("HumanoidRootPart").owner==admin, "freeze release restores client physics ownership")
assert(admin.Character:FindFirstChildOfClass("Humanoid").WalkSpeed==22, "freeze release restores speed immediately")
assert(admin.Character:FindFirstChildOfClass("Humanoid").JumpPower==35 and admin.Character:FindFirstChildOfClass("Humanoid").AutoRotate)
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
assert(not before.HumanoidRootPart.Anchored and beforeHumanoid.WalkSpeed==0 and beforeHumanoid.Health==42)
menu:Fire(friend,false)
assert(not before:FindFirstChild("HumanoidRootPart").Anchored)
assert(before:FindFirstChild("HumanoidRootPart").owner==friend, "menu release also restores ownership")
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
choose:Fire(add(102),"Red")
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
print("Session: admin gate, 3v3, collision, freeze, takeover, menus, elimination, draw and shutdown OK")
