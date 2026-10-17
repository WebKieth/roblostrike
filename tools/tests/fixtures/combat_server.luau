-- Minimal standalone Roblox services for exercising the REAL server handlers.
-- Does not substitute for Studio physics/network tests.
local clock = 10
local os = { clock = function() return clock end }
local vector = {}
vector.__index = function(v, key)
	if key == "Magnitude" then return math.sqrt(v.X^2 + v.Y^2 + v.Z^2) end
	if key == "Unit" then return v / v.Magnitude end
	return vector[key]
end
local function V(x, y, z) return setmetatable({X=x, Y=y, Z=z}, vector) end
vector.__add = function(a,b) return V(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
vector.__sub = function(a,b) return V(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
vector.__mul = function(a,b) return V(a.X*b, a.Y*b, a.Z*b) end
vector.__div = function(a,b) return V(a.X/b, a.Y/b, a.Z/b) end
local function typeof(value)
	return if getmetatable(value) == vector then "Vector3" else type(value)
end
local function signal()
	return { Connect = function(self, callback)
		self.callback = callback
		return { Disconnect = function() self.callback = nil end }
	end }
end
local events = {}
local Instance = { new = function(class)
	assert(class == "RemoteEvent")
	local event = { OnServerEvent = signal(), FireAllClients = function(self, ...)
		self.last = {...}
		self.count = (self.count or 0) + 1
	end }
	table.insert(events, event)
	return event
end }
local Enum = { RaycastFilterType = { Exclude = 1 }, Material = { Water = 1 } }
local RaycastParams = { new = function() return {} end }
local delayed = nil
local task = { delay = function(_, callback) delayed = callback end }
local players = { PlayerRemoving = signal() }
local game = { GetService = function(_, name)
	return if name == "Players" then players else {Shared={Weapons="weapons"}}
end }
local definition = { FireInterval=.0857, Range=800, Damage=28, Magazine=30, ReloadTime=2.3, Muzzle=V(0,0,-2) }
local require = function(_) return { definition } end
local ammo = { Ammo=30, Reloading=false, WeaponSlot=1 }
local handle = { CFrame = { PointToWorldSpace = function(_, point) return point end } }
local tool = {
	GetAttribute = function(_, name) return ammo[name] end,
	SetAttribute = function(_, name, value) ammo[name] = value end,
	FindFirstChild = function(_, name) return if name == "Handle" then handle else nil end,
	AncestryChanged = signal(),
}
local humanoid = {Health=100}
local head = { Position=V(0,0,0) }
local character = {
	FindFirstChildOfClass = function(_, class) return if class == "Tool" then tool else humanoid end,
	FindFirstChild = function(_, name) return if name == "Head" then head else nil end,
}
tool.Parent = character
local player = { Character=character, UserId=1 }
local victim = {Health=100, TakeDamage=function(self, damage) self.Health -= damage end}
local victimModel = {
	IsA = function(_, class) return class == "Model" end,
	FindFirstChildOfClass = function() return victim end,
}
local targetPart = { Name="Torso", Parent=victimModel, IsA=function() return false end }
local hit = {Position=V(0,0,-50), Normal=V(0,0,1), Material="Metal", Instance=targetPart}
local rayCount, blocked = 0, false
local workspace = { Raycast = function(_, origin, direction, params)
	rayCount += 1
	assert(params.FilterDescendantsInstances[1] == character)
	if direction.Magnitude < 3 then return if blocked then hit else nil end
	return hit
end }

local Combat = (function()
-- SERVER_MODULE_HERE
end)()
Combat.start({})
local fire, reload, effect = events[1].OnServerEvent.callback, events[2].OnServerEvent.callback, events[3]
local direction = V(0,0,-1)
fire(player, V(0,0,0), direction)
assert(ammo.Ammo == 29 and victim.Health == 72 and effect.count == 1)
clock += .03
fire(player, V(0,0,0), direction)
assert(ammo.Ammo == 29, "server must reject excess RPM")
clock += .1
fire(player, V(0,0,0), direction)
assert(ammo.Ammo == 28)
local before = rayCount
clock += .1
fire(player, V(0,0,0), V(0/0,0,-1))
assert(ammo.Ammo == 28 and rayCount == before, "NaN rejected before raycasts")
clock += .1
fire(player, V(100,0,0), direction)
assert(ammo.Ammo == 28, "remote camera rejected")
clock += .1
fire(player, V(0,0,0), V(0,0,-5))
assert(ammo.Ammo == 28, "non-unit vector rejected")
reload(player)
assert(ammo.Reloading and delayed ~= nil)
clock += .1
fire(player, V(0,0,0), direction)
assert(ammo.Ammo == 28, "cannot fire during reload")
delayed()
assert(ammo.Ammo == 30 and not ammo.Reloading)
ammo.Ammo = 5
reload(player)
tool.Parent = {}
tool.AncestryChanged.callback()
delayed()
assert(ammo.Ammo == 5 and not ammo.Reloading, "switch cancels reload")
tool.Parent = character
clock += .2
blocked = true
fire(player, V(0,0,0), direction)
assert(ammo.Ammo == 4 and effect.last[4] == hit.Position, "cover intercepts muzzle")
clock += .2
humanoid.Health = 0
fire(player, V(0,0,0), direction)
assert(ammo.Ammo == 4, "dead player cannot fire")
print("Combat server: damage, ammo, rate, malformed input, cover and reload OK")
