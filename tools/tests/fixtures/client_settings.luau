-- Run the actual sound mixer, settings interactions and local body visibility.
local function signal()
	local listeners={}
	return {Connect=function(_,callback)
		local entry={callback=callback,connected=true}; table.insert(listeners,entry)
		return {Disconnect=function() entry.connected=false end}
	end,Fire=function(_,...) for _,entry in listeners do if entry.connected then entry.callback(...) end end end}
end
local created={}
local methods={}
function methods:IsA(class) return self.ClassName==class or (class=="BasePart" and self.ClassName=="Part") end
function methods:GetChildren()
	local result={}; for _,item in created do if item.Parent==self then table.insert(result,item) end end; return result
end
function methods:GetDescendants()
	local result={}; for _,child in self:GetChildren() do
		table.insert(result,child); for _,item in child:GetDescendants() do table.insert(result,item) end
	end; return result
end
function methods:FindFirstChild(name)
	for _,child in self:GetChildren() do if child.Name==name then return child end end; return nil
end
function methods:FindFirstChildOfClass(class)
	for _,child in self:GetChildren() do if child:IsA(class) then return child end end; return nil
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
function methods:SetAttribute(name,value) self.attributes[name]=value end
function methods:GetAttribute(name) return self.attributes[name] end
function methods:Play() self.played=true end
function methods:FireServer(...) self.last={...} end
function methods:IsDescendantOf(ancestor)
	local parent=self.Parent; while parent do if parent==ancestor then return true end; parent=parent.Parent end; return false
end
local Instance={new=function(class)
	local obj=setmetatable({ClassName=class,Name=class,attributes={},LocalTransparencyModifier=0,
		Activated=signal(),InputBegan=signal(),DescendantAdded=signal(),CharacterAdded=signal(),CharacterRemoving=signal(),
		OnClientEvent=signal(),ChildAdded=signal(),
		AbsolutePosition={X=0},AbsoluteSize={X=100}}, {__index=methods})
	table.insert(created,obj); return obj
end}
local workspace=Instance.new("Workspace")
local soundService=Instance.new("SoundService")
local actions,renders={},{}
local input={InputChanged=signal(),InputEnded=signal(),GetFocusedTextBox=function() return nil end}
local guiService={MenuOpened=signal(),MenuClosed=signal()}
local services={SoundService=soundService,UserInputService=input,GuiService=guiService,
	ContextActionService={BindActionAtPriority=function(_,name,callback) actions[name]=callback end},
	RunService={BindToRenderStep=function(_,name,_,callback) renders[name]=callback end}}
local game={GetService=function(_,name) return assert(services[name],name) end}
local Color3={fromRGB=function(...) return {...} end,new=function(...) return {...} end}
local UDim2={new=function(...) return {...} end,fromScale=function(x,y) return {X=x,Y=y} end,fromOffset=function(...) return {...} end}
local UDim={new=function(...) return {...} end}
local Vector2={new=function(...) return {...} end}
local Enum={Font={GothamMedium=1},TextXAlignment={Left=1},UserInputState={Begin=1},
	UserInputType={MouseButton1=1,MouseMovement=2,Touch=3},ContextActionPriority={High={Value=100}},
	ContextActionResult={Sink=1,Pass=2},KeyCode={F10=1},MouseBehavior={Default=1},RenderPriority={Camera={Value=200}},
	PlayerActions={CharacterForward=1,CharacterBackward=2,CharacterLeft=3,CharacterRight=4,CharacterJump=5}}
local audio=(function()
-- AUDIO_MODULE_HERE
end)()
audio.start(); audio.start()
local master=assert(soundService:FindFirstChild("RobostrikeMaster"))
local gunfire=assert(master:FindFirstChild("RobostrikeGunfire"))
local characters=assert(master:FindFirstChild("RobostrikeCharacters"))
assert(#soundService:GetDescendants()==3, "mixer initialized once")
local gunshot=Instance.new("Sound"); gunshot.Volume=.7
audio.assign(gunshot,"Gunfire")
audio.set("Gunfire",.25)
assert(gunshot.SoundGroup==gunfire and gunfire.Volume==.25 and gunshot.Volume==.7)
assert(characters.Volume==1, "gunfire volume does not affect characters")
audio.set("Master",.5)
assert(master.Volume==.5 and gunfire.Parent==master and characters.Parent==master)
audio.set("Characters",-5); assert(characters.Volume==0)
audio.set("Characters",20); assert(characters.Volume==1)
audio.set("Gunfire",0/0); assert(gunfire.Volume==.25, "reject NaN")
local body=Instance.new("Model"); body.Parent=workspace
local humanoid=Instance.new("Humanoid"); humanoid.Parent=body
local root=Instance.new("Part"); root.Parent=body
local footsteps=Instance.new("Sound"); footsteps.Parent=root
workspace.DescendantAdded:Fire(footsteps)
assert(footsteps.SoundGroup==characters, "stock character audio follows character slider")
workspace.DescendantAdded:Fire(gunshot)
assert(gunshot.SoundGroup==gunfire)
local player=Instance.new("Player")
local playerGui=Instance.new("PlayerGui"); playerGui.Parent=player
player.Character=body
local script={Parent={AudioSettings="audio"}}
local require=function() return audio end
local settings=(function()
-- SETTINGS_MODULE_HERE
end)()
settings.start(player)
local gui=playerGui:FindFirstChild("AudioSettings")
local modal=assert(gui:FindFirstChild("SettingsModal"))
assert(not modal.Visible and not player:GetAttribute("SettingsOpen"))
actions.RobostrikeSettings(nil,1)
assert(modal.Visible and player:GetAttribute("SettingsOpen"))
assert(actions.RobostrikeSettingsMovement()==Enum.ContextActionResult.Sink)
renders.RobostrikeSettingsMouse()
assert(input.MouseIconEnabled and input.MouseBehavior==Enum.MouseBehavior.Default)
local track
local close
for _,item in gui:GetDescendants() do
	if item.Name=="GunfireSlider" then track=item end
	if item.Text=="ВЕРНУТЬСЯ В ИГРУ" then close=item end
end
assert(track and close)
local mouse={UserInputType=1,Position={X=20}}
track.InputBegan:Fire(mouse)
assert(audio.get("Gunfire")==.2)
input.InputChanged:Fire({UserInputType=2,Position={X=70}})
assert(audio.get("Gunfire")==.7)
input.InputEnded:Fire(mouse)
input.InputChanged:Fire({UserInputType=2,Position={X=90}})
assert(audio.get("Gunfire")==.7, "release ends dragging")
local finger={UserInputType=3,Position={X=30}}
track.InputBegan:Fire(finger)
finger.Position.X=45; input.InputChanged:Fire(finger)
assert(audio.get("Gunfire")==.45, "touch dragging")
input.InputEnded:Fire(finger)
close.Activated:Fire()
assert(not modal.Visible and not player:GetAttribute("SettingsOpen"))
assert(actions.RobostrikeSettingsMovement()==Enum.ContextActionResult.Pass)
guiService.MenuOpened:Fire()
assert(not modal.Visible and player:GetAttribute("SettingsOpen"), "native menu blocks gameplay")
guiService.MenuClosed:Fire()
assert(modal.Visible and player:GetAttribute("SettingsOpen"), "audio panel after native Escape menu")
guiService.MenuOpened:Fire(); guiService.MenuClosed:Fire()
assert(not modal.Visible and not player:GetAttribute("SettingsOpen"), "second menu cycle returns to game")
local visibility=(function()
-- VISIBILITY_MODULE_HERE
end)()
local cameraArms=Instance.new("Part"); cameraArms.Parent=workspace
visibility.start(player)
assert(root.LocalTransparencyModifier==1 and cameraArms.LocalTransparencyModifier==0)
local sleeve=Instance.new("Part"); sleeve.Parent=body
body.DescendantAdded:Fire(sleeve)
assert(sleeve.LocalTransparencyModifier==1, "late-added cosmetics hidden")
local dropped=Instance.new("Part"); dropped.Parent=body
body.DescendantAdded:Fire(dropped)
dropped.Parent=workspace
renders.RobostrikeHideBody()
assert(dropped.LocalTransparencyModifier==0, "dropped equipment becomes visible again")
root.LocalTransparencyModifier=0 -- simulate Roblox transparency controller
renders.RobostrikeHideBody()
assert(root.LocalTransparencyModifier==1)
player.CharacterRemoving:Fire(body)
assert(root.LocalTransparencyModifier==0 and sleeve.LocalTransparencyModifier==0)
local nextBody=Instance.new("Model"); nextBody.Parent=workspace
local nextRoot=Instance.new("Part"); nextRoot.Parent=nextBody
player.Character=nextBody; player.CharacterAdded:Fire(nextBody)
assert(nextRoot.LocalTransparencyModifier==1, "respawn hides new rig")
player.CharacterRemoving:Fire(body)
nextRoot.LocalTransparencyModifier=0; renders.RobostrikeHideBody()
assert(nextRoot.LocalTransparencyModifier==1, "stale removal cannot clear current rig")
assert(audio.get("Gunfire")==.45, "volume survives respawn")
print("Client: sound mixing, slider input, Escape lifecycle, and first-person visibility OK")
-- The real lobby UI must expose the server-checked bot budget and explicit start.
local replicated=Instance.new("ReplicatedStorage")
local state=Instance.new("Folder"); state.Name="SessionState"; state.Parent=replicated
state:SetAttribute("Phase","Lobby"); state:SetAttribute("Started",false); state:SetAttribute("BotsPerTeam",3)
local remotes=Instance.new("Folder"); remotes.Name="Remotes"; remotes.Parent=replicated
for _,name in {"ChooseTeam","TeamMenu","SessionSetup","SessionDeath","SpectatorPose"} do
	local remote=Instance.new("RemoteEvent"); remote.Name=name; remote.Parent=remotes
end
local actors=Instance.new("Folder"); actors.Name="SessionActors"; actors.Parent=workspace
function workspace:GetServerTimeNow() return 10 end
player.UserId,player.Name=85,"Host"
player:SetAttribute("SessionAdmin",true)
services.Players={GetPlayers=function() return {player} end}
services.ReplicatedStorage=replicated
services.Debris={AddItem=function() end}
replicated.Shared={SessionRules="rules"}
local rules=(function()
-- RULES_MODULE_HERE
end)()
script.Parent.CharacterAnimation="animation"
require=function(name) return if name=="rules" then rules elseif name=="animation" then {} else audio end
local hud=(function()
-- SESSION_HUD_MODULE_HERE
end)()
hud.start(player)
renders.RobostrikeSessionHUD()
local setupPanel,zero,start
for _,obj in playerGui:FindFirstChild("SessionHUD"):GetDescendants() do
	if obj.Name=="SessionSetup" then setupPanel=obj end
	if obj.Text=="Без ботов" then zero=obj end
	if obj.Text=="НАЧАТЬ СЕССИЮ" then start=obj end
end
assert(setupPanel and setupPanel.Visible and zero and start and start.Interactable)
zero.Activated:Fire()
local setupRemote=remotes:FindFirstChild("SessionSetup")
assert(setupRemote.last[1]=="Bots" and setupRemote.last[2]==0)
start.Activated:Fire()
assert(setupRemote.last[1]=="Start")
state:SetAttribute("BotsPerTeam",0)
renders.RobostrikeSessionHUD()
player:SetAttribute("SessionAdmin",false)
renders.RobostrikeSessionHUD()
assert(not zero.Interactable and not start.Interactable, "non-admin lobby controls disabled")
state:SetAttribute("Started",true); state:SetAttribute("Phase","Freeze")
player:SetAttribute("TeamMenuOpen",false); player:SetAttribute("SessionBlocked",true)
renders.RobostrikeSessionHUD()
assert(not setupPanel.Visible, "configuration disappears during play")
assert(actions.RobostrikeSessionFreeze()==Enum.ContextActionResult.Sink)
remotes:FindFirstChild("SessionDeath").OnClientEvent:Fire({})
local death=created[#created]
assert(death:IsA("Sound") and death.Volume==.64 and death.SoundGroup==characters and death.played)
print("Client lobby: bot count, host controls, explicit start, and reduced death audio OK")
