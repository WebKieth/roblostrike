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
	function event:FireClient(recipient, ...) self.recipient = recipient; self:FireAllClients(...) end
	table.insert(events, event)
	return event
end }
local Enum = { RaycastFilterType = { Exclude = 1 }, Material = { Water = 1 } }
local RaycastParams = { new = function() return {} end }
local delayed = nil
local task = { delay = function(_, callback) delayed = callback end }
local players = { PlayerRemoving = signal() }
local game = { GetService = function(_, name)
	return if name == "Players" then players else {Shared={Weapons="weapons", Ballistics="ballistics", Survival="survival", SessionRules="session"}}
end }
local definition = { FireInterval=.0857, Range=800, Damage=28, Magazine=30, ReloadTime=2.3, Muzzle=V(0,0,-2) }
local survival = (function()
-- SURVIVAL_MODULE_HERE
end)()
local session = (function()
	local Color3 = {fromRGB=function(...) return {...} end}
-- SESSION_RULES_HERE
end)()
local require = function(name) return if name == "session" then session elseif name == "survival" then survival elseif name == "ballistics" then {MaxMuzzleOffset=6} else { definition } end
local ammo = { Ammo=30, ReserveAmmo=90, Reloading=false, WeaponSlot=1 }
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
	GetPivot = function() return { Position = head.Position } end,
	GetAttribute = function(_, key) return if key == "TeamId" then "Blue" else nil end,
	FindFirstChildOfClass = function(_, class) return if class == "Tool" then tool else humanoid end,
	FindFirstChild = function(_, name) return if name == "Head" then head else nil end,
}
tool.Parent = character
local playerAttributes = {}
local player = { Character=character, UserId=1, GetAttribute=function(_, key) return playerAttributes[key] end }
players.GetPlayerFromCharacter = function(_, model) return if model == character then player else nil end
local victim = {Health=100, TakeDamage=function(self, damage) self.Health -= damage end}
local attributes = {}
local victimModel = {
	IsA = function(_, class) return class == "Model" end,
	FindFirstChildOfClass = function() return victim end,
	FindFirstChild = function() return nil end,
	GetAttribute = function(_, name) return attributes[name] end,
	SetAttribute = function(_, name, value) attributes[name] = value end,
}
local victimPlayer = { Character = victimModel }
players.GetPlayerFromCharacter = function(_, model)
	return if model == character then player elseif model == victimModel then victimPlayer else nil
end
victim.Parent = victimModel
local targetPart = { Name="Torso", Parent=victimModel, IsA=function() return false end }
local hit = {Position=V(0,0,-50), Normal=V(0,0,1), Material="Metal", Instance=targetPart}
local rayCount, blocked = 0, false
local lastOrigin, lastDirection
local workspace = { Raycast = function(_, origin, direction, params)
	rayCount += 1
	lastOrigin, lastDirection = origin, direction
	assert(params.FilterDescendantsInstances[1] == character)
	if direction.Magnitude < 6 then return if blocked then hit else nil end
	return hit
end }

local Combat = (function()
-- SERVER_MODULE_HERE
end)()
Combat.start({})
local fire, reload, effect = events[1].OnServerEvent.callback, events[2].OnServerEvent.callback, events[3]
local direction = V(0,0,-1)
fire(player, V(0,0,0), direction)
assert(ammo.Ammo == 29 and victim.Health == 30 and effect.count == 1)
assert(events[4].recipient == player, "damage feedback goes only to the attacker")
assert(events[5].recipient == victimPlayer, "incoming damage goes only to victim")
assert(events[5].last[1] == victimModel and events[5].last[2] == head.Position and events[5].last[3] == false)
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
assert(ammo.Ammo == 28, "remote muzzle rejected")
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
assert(ammo.ReserveAmmo == 88, "tactical reload only transfers missing rounds")
ammo.Ammo = 5
reload(player)
tool.Parent = {}
tool.AncestryChanged.callback()
delayed()
assert(ammo.Ammo == 5 and not ammo.Reloading, "switch cancels reload")
tool.Parent = character
clock += .2
blocked = true
fire(player, V(0,0,-2), direction)
assert(ammo.Ammo == 4 and effect.last[4] == hit.Position, "cover intercepts muzzle")
assert(effect.last[3] == head.Position, "clipped muzzle cannot shoot through cover")
-- Moving head replication must not invalidate a legitimate local barrel offset.
blocked = false
for _, position in {V(20,0,0), V(40,2,-10), V(-30,0,50)} do
	clock += .2
	head.Position = position
	local offset = V(.7,-.7,-3.5)
	local before = ammo.Ammo
	fire(player, offset, direction)
	assert(ammo.Ammo == before - 1, "moving shot consumes ammo")
	assert((lastOrigin - (position + offset)).Magnitude < 1e-9, "use first-person muzzle")
	assert((lastDirection.Unit - direction).Magnitude < 1e-9, "bullet stays parallel to bore")
end
clock += .2
humanoid.Health = 0
fire(player, V(0,0,0), direction)
assert(ammo.Ammo == 1, "dead player cannot fire")
humanoid.Health = 100
ammo.Ammo, ammo.ReserveAmmo = 0, 7
reload(player)
delayed()
assert(ammo.Ammo == 7 and ammo.ReserveAmmo == 0, "last reserve can be partial")
reload(player)
assert(not ammo.Reloading, "no infinite reloads")
attributes.Immortal = true
local incomingBefore = events[5].count
victim.Health = 100
clock += .2
fire(player, V(0,0,0), direction)
assert(victim.Health == 100 and events[4].last[2] == 70, "immortal target still reports real damage")
definition.DamageMultiplier = .6
targetPart.Name = "Head"
clock += .2
fire(player, V(0,0,0), direction)
assert(victim.Health == 100 and events[4].last[2] == 90, "Glock uses reference damage times .6")
assert(events[5].count == incomingBefore, "immortality must not create incoming damage")
-- Server freeze/menu gates and friendly fire protect armor as well as HP.
local beforeAmmo, beforeFeedback = ammo.Ammo, events[4].count
playerAttributes.SessionBlocked = true
clock += .2
fire(player, V(0,0,0), direction)
reload(player)
assert(ammo.Ammo == beforeAmmo and not ammo.Reloading)
playerAttributes.SessionBlocked = false
playerAttributes.TeamMenuOpen = true
clock += .2
fire(player, V(0,0,0), direction)
assert(ammo.Ammo == beforeAmmo)
playerAttributes.TeamMenuOpen = false
attributes.TeamId, attributes.Armor, attributes.Helmet = "Blue", 100, true
victim.Health, attributes.Immortal = 100, false
Combat.damage(hit, 1, events[4], character)
assert(victim.Health == 100 and attributes.Armor == 100 and events[4].count == beforeFeedback)
assert(events[5].count == incomingBefore, "friendly fire must not kick victim camera")
attributes.TeamId = "Red"
Combat.damage(hit, 1, events[4], character)
assert(victim.Health == 25 and attributes.Armor == 80)
assert(events[5].last[3] == true and events[5].count == incomingBefore + 1, "helmet headshot still kicks camera")
print("Combat server: damage, ammo, rate, malformed input, cover and reload OK")
