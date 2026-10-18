local function signal()
	local listeners={}
	return {Connect=function(_,fn) table.insert(listeners,fn) end, Fire=function(_,...) for _,fn in listeners do fn(...) end end}
end
local objects={}
local methods={}
function methods:GetChildren()
	local result={}
	for _,child in objects do if child.Parent==self then table.insert(result,child) end end
	return result
end
function methods:GetDescendants()
	local result={}
	for _,child in self:GetChildren() do table.insert(result,child); for _,descendant in child:GetDescendants() do table.insert(result,descendant) end end
	return result
end
function methods:IsA(class) return self.ClassName==class end
function methods:Destroy() self.Parent=nil end
function methods:WaitForChild(name)
	for _,child in self:GetChildren() do if child.Name==name then return child end end
	error(name)
end
function methods:GetAttribute(name) return self.attributes[name] end
function methods:GetAttributeChangedSignal(name)
	if not self.signals[name] then self.signals[name]=signal() end
	return self.signals[name]
end
function methods:SetAttribute(name,value)
	self.attributes[name]=value
	if self.signals[name] then self.signals[name]:Fire() end
end
local Instance={new=function(class,parent)
	local obj=setmetatable({ClassName=class,Name=class,attributes={},signals={},Activated=signal(),FocusLost=signal(),Parent=parent},{__index=methods})
	table.insert(objects,obj)
	return obj
end}
local UDim2={new=function(...) return {...} end,fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end}
local UDim={new=function(...) return {...} end}
local Vector2={new=function(...) return {...} end,zero={}}
local Color3={new=function(...) return {...} end,fromRGB=function(...) return {...} end}
local Enum={Font={GothamMedium=1,GothamBold=2},TextTruncate={AtEnd=1}}
local replicated={Shared={ServerBrowser="rules",MapCatalog="maps"}}
local script={Parent={MapSelect="select"}}
local game={GetService=function() return replicated end}
local rules=(function()
-- BROWSER_HERE
end)()
local maps=(function()
-- MAP_CATALOG_HERE
end)()
local mapSelect
local require=function(name) return if name=="maps" then maps elseif name=="select" then mapSelect else rules end
mapSelect=(function()
-- MAP_SELECT_HERE
end)()
local ui=(function()
-- UI_HERE
end)()
local player=Instance.new("Player")
local gui=Instance.new("PlayerGui",player)
local remotes=Instance.new("Folder")
local remote=Instance.new("RemoteFunction",remotes); remote.Name="ServerDirectory"
local entries={}
for i=1,105 do table.insert(entries,{id=tostring(i),name=string.format("Arena %03d",i),players=1,capacity=6,started=true}) end
function remote:InvokeServer(command,value,page,size)
	self.last={command,value,page,size}
	if command=="List" then return rules.page(entries,value,page,size) end
	if command=="Create" or command=="Join" then player:SetAttribute("InSession",true) end
	return {ok=true}
end
ui.start(player,remotes)
local root=gui:WaitForChild("ServerBrowser")
local function button(text)
	for _,item in root:GetDescendants() do if item:IsA("TextButton") and item.Text==text then return item end end
	error("Button missing: "..text)
end
local function rows()
	for _,item in root:GetDescendants() do
		if item:IsA("ScrollingFrame") then
			local result={}
			for _,child in item:GetChildren() do if child:IsA("TextButton") then table.insert(result,child) end end
			return result
		end
	end
end
assert(root.Enabled)
button("НАЙТИ СЕРВЕР").Activated:Fire()
assert(remote.last[1]=="List" and remote.last[4]==50 and #rows()==50)
button("›").Activated:Fire()
assert(remote.last[3]==2 and #rows()==50)
button("›").Activated:Fire()
assert(remote.last[3]==3 and #rows()==5)
button("20 строк").Activated:Fire()
assert(remote.last[3]==1 and remote.last[4]==20 and #rows()==20)
button("10 строк").Activated:Fire()
assert(remote.last[4]==10 and #rows()==10)
local search
for _,item in root:GetDescendants() do if item.PlaceholderText=="Поиск по имени сессии" then search=item end end
search.Text="105"; search.FocusLost:Fire()
assert(#rows()==1 and remote.last[2]=="105")
rows()[1].Activated:Fire()
assert(remote.last[1]=="Join" and remote.last[2]=="105" and not root.Enabled)
player:SetAttribute("InSession",false)
button("НОВЫЙ СЕРВЕР").Activated:Fire()
local name
for _,item in root:GetDescendants() do if item.PlaceholderText=="Введите имя сервера" then name=item end end
local previous=remote.last
button("ДАЛЕЕ — НАСТРОЙКИ").Activated:Fire()
assert(remote.last==previous,"invalid name must not create a session")
name.Text="Мой сервер"
button("Карта: Deathmatch Arena  ▾").Activated:Fire()
button("Desert City").Activated:Fire()
button("ДАЛЕЕ — НАСТРОЙКИ").Activated:Fire()
assert(remote.last[1]=="Create" and remote.last[2]=="Мой сервер" and not root.Enabled)
assert(remote.last[3]=="DesertCity", "selected map must be sent with create request")
print("Browser UI: initial choice, name validation, list rendering, search, page navigation, 10/20/50, join and create OK")
