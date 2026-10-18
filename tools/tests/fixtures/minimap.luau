local function signal()
	local callbacks={}
	return {Connect=function(_,fn) table.insert(callbacks,fn); return {Disconnect=function() table.remove(callbacks,table.find(callbacks,fn)) end} end,
		Fire=function(_,...) for _,fn in callbacks do fn(...) end end}
end
local objects={}
local methods={}
local Instance={new=function(class,parent)
	local object=setmetatable({ClassName=class,Name=class,Parent=parent}, {__index=methods})
	table.insert(objects,object)
	return object
end}
function methods:IsA(class) return self.ClassName==class or (class=="BasePart" and self.ClassName=="Part") end
function methods:GetChildren()
	local children={}
	for _,object in objects do if object.Parent==self then table.insert(children,object) end end
	return children
end
function methods:FindFirstChild(name)
	for _,object in self:GetChildren() do if object.Name==name then return object end end
	return nil
end
function methods:FindFirstChildOfClass(class)
	for _,object in self:GetChildren() do if object:IsA(class) then return object end end
	return nil
end
function methods:Destroy() self:ClearAllChildren(); self.Parent=nil end
function methods:ClearAllChildren() for _,child in self:GetChildren() do child:Destroy() end end
local function V(x,y,z) return {X=x,Y=y,Z=z} end
local Vector3={new=V,zero=V(0,0,0)}
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local UDim2={fromOffset=function(x,y) return {X=x,Y=y} end,fromScale=function(x,y) return {X=x,Y=y} end,new=function(...) return {...} end}
local UDim={new=function(...) return {...} end}
local Color3={fromRGB=function(r,g,b) return {R=r,G=g,B=b} end}
local CFrame={new=function(point) return {Position=point} end}
local RaycastParams,OverlapParams={new=function() return {} end},{new=function() return {} end}
local Enum={Font={GothamBold=1},RaycastFilterType={Include=1},RenderPriority={Camera={Value=200}}}
local waitingHook
local task={spawn=function(fn,...) fn(...) end,wait=function(duration)
	if waitingHook and not duration then local hook=waitingHook; waitingHook=nil; hook() end
end}
local render
local contactsEvent={OnClientEvent=signal()}
local remotes={WaitForChild=function() return contactsEvent end}
local game={GetService=function(_,name)
	if name=="ReplicatedStorage" then return {WaitForChild=function() return remotes end} end
	return {BindToRenderStep=function(_,_,_,fn) render=fn end}
end}
local workspace=Instance.new("Workspace")
workspace.ChildAdded,workspace.ChildRemoved=signal(),signal()
workspace.CurrentCamera={CFrame={LookVector=V(1,0,0)}}
local probes=0
function workspace:GetPartBoundsInBox(frame,_,filter)
	assert(filter.RespectCanCollide and filter.MaxParts==1 and filter.FilterType==Enum.RaycastFilterType.Include)
	assert(filter.FilterDescendantsInstances[1].Name=="ActiveMap", "actors excluded from schematic")
	probes+=1
	return if math.abs(frame.Position.X)<3 then {{}} else {}
end
function workspace:Raycast(point,_,filter)
	assert(filter.RespectCanCollide and filter.IgnoreWater)
	return if math.abs(point.X)<55 and math.abs(point.Z)<30 then {} else nil
end
local gui=Instance.new("ScreenGui")
local player={inSession=false,GetAttribute=function(self) return self.inSession end}
local character=Instance.new("Model")
local root=Instance.new("Part",character); root.Name,root.Position="HumanoidRootPart",V(10,3.1,-10)
local humanoid=Instance.new("Humanoid",character); humanoid.Health=100
player.Character=character
local function map()
	local arena=Instance.new("Model",workspace)
	arena.DescendantAdded=signal()
	arena.Name="ActiveMap"
	function arena:GetBoundingBox() return {Position=V(0,0,0)},V(120,20,72) end
	local spawns=Instance.new("Folder",arena); spawns.Name="TeamSpawns"
	local marker=Instance.new("Part",spawns); marker.Name,marker.Position="Blue1",V(-40,0,-10)
	return arena
end
local first=map()
local Minimap=(function()
-- MINIMAP_HERE
end)()
Minimap.start(player,gui)
local panel=gui:FindFirstChild("Minimap")
local marker=panel:FindFirstChild("PlayerPosition")
local cells
for _,child in panel:GetChildren() do if child:IsA("Frame") then cells=child end end
assert(probes==64*36 and #cells:GetChildren()>0 and #cells:GetChildren()<=64*36, "bounded floor plan build")
local wall,floor=false,false
for _,cell in cells:GetChildren() do
	if cell.BackgroundColor3.R==137 then wall=true elseif cell.BackgroundColor3.R==48 then floor=true end
end
assert(wall and floor, "walls and passages have distinct colours")
render(); assert(not panel.Visible, "hidden outside a session")
player.inSession=true
render()
assert(panel.Visible and marker.Visible and marker.Position.X>.5 and marker.Position.Y<.5)
assert(math.abs(marker.Rotation-90)<1e-8, "marker follows camera bearing")
contactsEvent.OnClientEvent:Fire({{model=character,position=V(0,0,0)},
	{model={},position=V(-20,3,10),enemy=false},{model={},position=V(20,3,-10),enemy=true}})
assert(panel:FindFirstChild("AllyContact") and panel:FindFirstChild("EnemyContact"), "team and visible enemy markers")
assert(#panel:GetChildren()==5, "self marker is not duplicated")
contactsEvent.OnClientEvent:Fire({})
assert(not panel:FindFirstChild("EnemyContact") and not panel:FindFirstChild("AllyContact"), "lost contacts removed immediately")
humanoid.Health=0
render(); assert(not marker.Visible, "dead player's position is not shown as alive")
first.Parent=nil; workspace.ChildRemoved:Fire(first)
render(); assert(not panel.Visible and #cells:GetChildren()==0)
local replacement
waitingHook=function()
	local second=workspace:FindFirstChild("ActiveMap")
	second.Parent=nil; workspace.ChildRemoved:Fire(second)
	replacement=map(); workspace.ChildAdded:Fire(replacement)
end
local second=map(); workspace.ChildAdded:Fire(second)
assert(replacement and #cells:GetChildren()>0 and #cells:GetChildren()<=64*36, "stale build must stop after map replacement")
replacement.Parent=nil; workspace.ChildRemoved:Fire(replacement)
render(); assert(not panel.Visible and #cells:GetChildren()==0)
