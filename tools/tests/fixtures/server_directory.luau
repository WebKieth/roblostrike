local clock=100
local warn=print
local os={clock=function() return clock end,time=function() return math.floor(clock) end}
local function signal()
	local callbacks={}
	return {Connect=function(_,fn) table.insert(callbacks,fn) end, Fire=function(_,...) for _,fn in callbacks do fn(...) end end}
end
local function object()
	local result={attributes={}}
	function result:SetAttribute(key,value) self.attributes[key]=value end
	function result:GetAttribute(key) return self.attributes[key] end
	function result:Destroy() end
	return result
end
local created={}
local Instance={new=function(class)
	local result=object(); result.ClassName=class; table.insert(created,result); return result
end}
local Enum={SortDirection={Ascending=1},TextFilterContext={PublicChat=1}}
local task={spawn=function(fn,...) fn(...) end}
local studio=true
local run={IsStudio=function() return studio end,Heartbeat=signal()}
local players={list={},PlayerRemoving=signal()}
function players:GetPlayers() return table.clone(self.list) end
local function player(id)
	local p=object(); p.UserId,p.Parent=id,players; table.insert(players.list,p); return p
end
local store={values={},writes=0,fail=false}
function store:SetAsync(key,value,ttl,sort)
	assert(ttl==90 and key==sort)
	self.values[key]=table.clone(value); self.writes+=1
end
function store:GetAsync(key) return self.values[key] end
function store:RemoveAsync(key) self.values[key]=nil end
function store:GetRangeAsync(_,limit,bound)
	if self.fail then error("store offline") end
	local keys={}
	for key in self.values do if not bound or key>bound.key then table.insert(keys,key) end end
	table.sort(keys)
	local rows={}
	for i=1,math.min(limit,#keys) do
		local key=keys[i]; table.insert(rows,{key=key,sortKey=key,value=self.values[key]})
	end
	return rows
end
local teleports={TeleportInitFailed=signal(),count=0}
function teleports:ReserveServerAsync() self.count+=1; return "secret"..self.count,"reserved"..self.count end
function teleports:TeleportAsync(place,list,options)
	assert(place==123)
	self.last={player=list[1],access=options.ReservedServerAccessCode}
end
local text={FilterStringAsync=function(_,name,id)
	assert(id)
	return {GetNonChatStringForBroadcastAsync=function() return "filtered "..name end}
end}
local replicated={Shared={ServerBrowser="browser"}}
local game={PrivateServerId="",PrivateServerOwnerId=0,PlaceId=123,shutdown={}}
function game:BindToClose(fn) table.insert(self.shutdown,fn) end
function game:GetService(name)
	return ({Players=players,ReplicatedStorage=replicated,RunService=run,MemoryStoreService={GetSortedMap=function() return store end},TeleportService=teleports,TextService=text})[name]
end
local browser=(function()
-- BROWSER_HERE
end)()
local require=function() return browser end
local directory=(function()
-- DIRECTORY_HERE
end)()
local function start()
	local state=object()
	local joins=0
	local controller
	controller=directory.start(object(),state,function(p,name)
		state:SetAttribute("OwnerUserId",p.UserId); state:SetAttribute("ServerName",name); p:SetAttribute("InSession",true)
	end,function(p) joins+=1; p:SetAttribute("InSession",true) end,function(p)
		p:SetAttribute("InSession",false)
		if p.UserId==state:GetAttribute("OwnerUserId") then state:SetAttribute("OwnerUserId",nil); controller.close() end
	end)
	local remote
	for _,obj in created do if obj.ClassName=="RemoteFunction" then remote=obj end end
	local function request(p,command,value,page,size)
		clock+=1
		return remote.OnServerInvoke(p,command,value,page or 1,size or 50)
	end
	return controller,state,request,function() return joins end
end
local owner,guest=player(12),player(55)
local controller,state,request,joins=start()
assert(request(owner,"Create","").error)
assert(request(owner,"Create","Studio server").ok)
assert(state:GetAttribute("OwnerUserId")==12 and owner:GetAttribute("InSession"))
assert(request(owner,"Create","Duplicate").error)
run.Heartbeat:Fire(20)
local result=request(guest,"List","")
assert(result.total==1 and result.rows[1].name=="Studio server" and result.rows[1].players==1)
assert(not result.rows[1].access and not result.rows[1].owner)
assert(request(guest,"Join","studio").ok and joins()==1)
assert(request(guest,"Join","studio").error)
assert(request(guest,"Leave").ok and not guest:GetAttribute("InSession"))
assert(request(owner,"Leave").ok and request(guest,"List","").total==0)

-- Public production servers reserve independent instances, without activating locally.
studio=false
owner:SetAttribute("InSession",false)
controller,state,request,joins=start()
assert(request(owner,"Create","Arena").ok)
assert(not state:GetAttribute("OwnerUserId") and teleports.last.access=="secret1")
assert(store.values.reserved1.name=="filtered Arena" and not store.values.reserved1.ready)
assert(request(guest,"List","").total==0, "pending reservations must not be advertised")
assert(request(guest,"Join","reserved1").error)

-- The reserved server resolves the trusted owner, ignoring any client claims.
game.PrivateServerId="reserved1"
controller,state,request,joins=start()
controller.added(owner)
assert(state:GetAttribute("OwnerUserId")==12 and state:GetAttribute("ServerName")=="filtered Arena")
run.Heartbeat:Fire(20)
assert(store.values.reserved1.ready)
guest:SetAttribute("InSession",false)
local advertised=request(guest,"List","")
assert(advertised.total==1 and not advertised.rows[1].access)
assert(request(guest,"Join","reserved1").ok and teleports.last.access=="secret1")
teleports.TeleportInitFailed:Fire(guest)
controller.added(guest)
assert(guest:GetAttribute("InSession"))
store.values.reserved1.players=6
local extra=player(66)
assert(request(extra,"Join","reserved1").error)
controller.close()
assert(not store.values.reserved1)
assert(request(extra,"Join","reserved1").error)

-- More than one MemoryStore batch: search/pagination applies across the entire catalog.
for i=1,205 do
	local id=string.format("%03d",i)
	store.values[id]={id=id,name="Arena "..id,ready=true,updated=os.time(),players=1,capacity=6,access="private",owner=12}
end
clock+=11
local lastPage=request(extra,"List","Arena",5,50)
assert(lastPage.total==205 and #lastPage.rows==5 and lastPage.pages==5)
clock+=11; store.fail=true
assert(request(extra,"List","").error, "storage failures must return a retryable response")
store.fail=false
print("Directory: public creation, filtering, trusted reserved ownership, hidden codes, catalog scan, full/stale entries, local join/leave OK")
