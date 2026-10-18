local function signal()
	local callbacks={}
	return {Connect=function(_,f) table.insert(callbacks,f) end,
		Fire=function(_,...) for _,f in callbacks do f(...) end end}
end
local clock, jobs = 0, {}
local task = {}
function task.spawn(callback,...)
	local thread=coroutine.create(callback)
	local ok, delay=coroutine.resume(thread,...)
	assert(ok,delay)
	if coroutine.status(thread)~="dead" then table.insert(jobs,{thread=thread,at=clock+(delay or 0)}) end
end
function task.wait(seconds) return coroutine.yield(seconds or .01) end
local function advance(seconds)
	local target=clock+seconds
	while true do
		local index, nextAt=nil,math.huge
		for i,job in jobs do if job.at<nextAt then index,nextAt=i,job.at end end
		if not index or nextAt>target then break end
		clock=nextAt
		local job=table.remove(jobs,index)
		local ok,delay=coroutine.resume(job.thread)
		assert(ok,delay)
		if coroutine.status(job.thread)~="dead" then job.at=clock+(delay or 0); table.insert(jobs,job) end
	end
	clock=target
end
local os={clock=function() return clock end}
local warnings={}
local warn=function(message) table.insert(warnings,message) end
local methods={}
function methods:SetAttribute(k,v) self.attrs[k]=v end
function methods:GetAttribute(k) return self.attrs[k] end
local remote
local Instance={new=function(class)
	local object=setmetatable({ClassName=class,attrs={},OnServerEvent=signal()}, {__index=methods})
	if class=="RemoteEvent" then remote=object end
	return object
end}
local data, writes, failRead, failWrite, readDelay = {}, 0, false, false, 0
local store={
	GetAsync=function(_,key)
		if readDelay>0 then task.wait(readDelay) end
		if failRead then error("offline") end
		return data[key]
	end,
	UpdateAsync=function(_,key,callback)
		if failWrite then error("offline") end
		data[key]=callback(data[key]); writes+=1
	end,
}
local players={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function() return {} end}
local close
local failOpen = false
local game={GetService=function(_,name)
	return if name=="Players" then players else {GetDataStore=function()
		if failOpen then error("You must publish this place to the web to access DataStore.") end
		return store
	end}
end,BindToClose=function(_,f) close=f end}
local Settings=(function()
-- SETTINGS_MODULE_HERE
end)()
local remotes={}
Settings.start(remotes)
local function add(id)
	local player=Instance.new("Player"); player.UserId=id
	players.PlayerAdded:Fire(player)
	return player
end
local function set(player,channel,value) remote.OnServerEvent:Fire(player,channel,value) end
local first=add(1)
assert(first:GetAttribute("SettingMaster")==1 and first:GetAttribute("SettingSensitivity")==1)
set(first,"Master",.25); set(first,"Characters",.4); set(first,"Gunfire",0); set(first,"Sensitivity",1.75)
for _,bad in {0/0,math.huge,-1,2,"loud"} do set(first,"Master",bad) end
set(first,"Unknown",.5); set(first,{},.5)
assert(first:GetAttribute("SettingMaster")==.25 and first:GetAttribute("SettingUnknown")==nil)
advance(15)
assert(writes==1 and data["1"].Master==.25 and data["1"].Sensitivity==1.75)
set(first,"Sensitivity",.5)
players.PlayerRemoving:Fire(first)
assert(data["1"].Sensitivity==.5, "disconnect flushes changes without waiting for autosave")
local second=add(1)
assert(second:GetAttribute("SettingMaster")==.25 and second:GetAttribute("SettingGunfire")==0)
assert(second:GetAttribute("SettingSensitivity")==.5, "reconnect restores saved preferences")
-- User edits made before the asynchronous read returns win over stored values.
readDelay=1
data["2"]={Master=.1,Sensitivity=1.8}
local early=add(2)
set(early,"Sensitivity",.3)
advance(1)
assert(early:GetAttribute("SettingSensitivity")==.3 and early:GetAttribute("SettingMaster")==.1)
readDelay=0
-- Failed reads must never overwrite a previous user's preferences with defaults.
failRead=true
data["3"]={Master=.15,Sensitivity=1.9}
local offline=add(3)
set(offline,"Master",.9)
advance(15)
assert(data["3"].Master==.15 and #warnings==3)
failRead=false
-- Failed writes remain dirty and are retried by the next autosave.
failWrite=true
set(second,"Master",.6)
advance(15)
assert(data["1"].Master==.25)
failWrite=false
advance(15)
assert(data["1"].Master==.6)
set(second,"Gunfire",.7)
close()
assert(data["1"].Gunfire==.7, "shutdown saves the latest values")
-- Opening an unpublished file must still create the settings remote and listeners.
failOpen=true
players.PlayerAdded=signal()
players.PlayerRemoving=signal()
local writesBefore, warningsBefore = writes, #warnings
Settings.start({})
local localPlayer=add(4)
assert(remote.Name=="PlayerSettings")
assert(localPlayer:GetAttribute("SettingMaster")==1)
set(localPlayer,"Master",.35)
set(localPlayer,"Sensitivity",1.2)
set(localPlayer,"Master",-1)
assert(localPlayer:GetAttribute("SettingMaster")==.35)
assert(localPlayer:GetAttribute("SettingSensitivity")==1.2)
local before=clock
players.PlayerRemoving:Fire(localPlayer)
assert(clock==before, "session-only settings must not delay disconnect")
close()
assert(writes==writesBefore and #warnings==warningsBefore+1)
print("Settings: reconnect, validation, async loading, retry and shutdown OK")
