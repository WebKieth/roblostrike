--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local Catalog = require(ReplicatedStorage.Shared.MapCatalog)
local Rules = require(ReplicatedStorage.Shared.SessionRules)
local Loot = require(script.Parent.Loot)
local Doors = require(script.Parent.MapDoors)
local MapManager = {}
local current: Model? = nil

function MapManager.activate(id: string)
	assert(Catalog.find(id), "Unknown map")
	if current and current:GetAttribute("MapId") == id then return end
	local templates = ServerStorage:WaitForChild("Maps")
	local template = templates:FindFirstChild(id)
	assert(template and template:IsA("Model"), "Missing map template: " .. id)
	local map = template:Clone() :: Model
	map.Name = "ActiveMap"
	map:SetAttribute("MapId", id)
	-- Validate spawn markers before touching the current arena.
	Rules.setMap(map)
	if current then current:Destroy() end
	current = map
	map.Parent = workspace
	Doors.start(map)
	Loot.setMap(map)
	Lighting.Brightness = if id == "DeathmatchArena" then 1 else 2
	Lighting.Ambient = if id == "DeathmatchArena" then Color3.fromRGB(56, 64, 77) else Color3.fromRGB(115, 105, 85)
	ReplicatedStorage:SetAttribute("ActiveMapId", id)
end

return MapManager
