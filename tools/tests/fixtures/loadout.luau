-- Execute the real loadout/model builders; simulate engine Backpack replacement.
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, f) table.insert(callbacks, f) end,
		Fire = function(_, ...) for _, f in callbacks do f(...) end end,
	}
end
local deferred = {}
local task = { defer = function(f) table.insert(deferred, f) end }
local function flush()
	while #deferred > 0 do table.remove(deferred, 1)() end
end
local methods = {}
function methods:IsA(class) return self.ClassName == class end
function methods:GetChildren() return table.clone(self.children) end
function methods:FindFirstChildOfClass(class)
	for _, child in self.children do if child:IsA(class) then return child end end
	return nil
end
function methods:SetAttribute(key, value) self.attributes[key] = value end
function methods:GetAttribute(key) return self.attributes[key] end
function methods:Destroy()
	for _, child in self:GetChildren() do child:Destroy() end
	self.Parent = nil
end
local object = {
	__index = function(self, key) return methods[key] or self.props[key] end,
	__newindex = function(self, key, value)
		if key == "Parent" then
			local previous = self.props.Parent
			if previous then
				for i, child in previous.children do
					if child == self then table.remove(previous.children, i) break end
				end
			end
			self.props.Parent = value
			if value then
				table.insert(value.children, self)
				value.ChildAdded:Fire(self)
			end
		else self.props[key] = value end
	end,
}
local frame = { __mul = function(a, _) return a end }
local Instance = { new = function(class)
	return setmetatable({props={ClassName=class, ChildAdded=signal(), Transparency=0, CFrame=setmetatable({},frame)}, children={}, attributes={}}, object)
end }
local CFrame = {
	new = function(...) return setmetatable({}, frame) end,
	Angles = function(...) return setmetatable({}, frame) end,
}
local Vector3 = { new = function(x,y,z) return {X=x,Y=y,Z=z} end }
local Color3 = { fromRGB = function(...) return {} end, new = function(...) return {} end }
local Enum = {Material={SmoothPlastic=1, Metal=2}, PartType={Cylinder=1}, MeshType={FileMesh=1}}
local weapons = (function()
-- WEAPONS_MODULE_HERE
end)()
local gun = (function()
-- GUN_MODULE_HERE
end)()
local require = function(name) return if name == "weapons" then weapons elseif name == "survival" then {SpareMagazines=3} else gun end
local game = {GetService=function() return {Shared={Weapons="weapons", GunModel="gun", Survival="survival"}} end}
local Loadout = (function()
-- LOADOUT_MODULE_HERE
end)()
local player = Instance.new("Player")
local character = Instance.new("Model")
local humanoid = Instance.new("Humanoid")
humanoid.Health = 100
humanoid.Parent = character
humanoid.EquipTool = function(_, tool)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child ~= tool then child.Parent = player:FindFirstChildOfClass("Backpack") end
	end
	tool.Parent = character
end
humanoid.UnequipTools = function()
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then child.Parent = player:FindFirstChildOfClass("Backpack") end
	end
end
player.Character = character
Loadout.watch(player)
assert(Loadout.give(player))
Loadout.equip(player, 1)
flush()
local equipped = character:FindFirstChildOfClass("Tool")
assert(equipped and equipped.Name == "M4A1", "initial weapon must be equipped")
assert(equipped:GetAttribute("ReserveAmmo") == 90, "three spare M4 magazines")
local handle = equipped:FindFirstChildOfClass("Part")
assert(handle.Transparency == 1 and #handle:GetChildren() > 30, "visible gun geometry must exist")
local visibleParts = 0
for _, part in handle:GetChildren() do
	if part:IsA("Part") and part.Transparency == 0 then visibleParts += 1 end
end
assert(visibleParts > 30, "not just an invisible handle")
equipped:SetAttribute("Ammo", 17)
Loadout.equip(player, 1)
assert(equipped:GetAttribute("Ammo") == 17, "repair must not refill ammo")
-- Engine clears equipment and replaces its container after manual Character setup.
equipped:Destroy()
player:FindFirstChildOfClass("Backpack"):Destroy()
local replacement = Instance.new("Backpack")
replacement.Parent = player
flush()
equipped = character:FindFirstChildOfClass("Tool")
assert(equipped and equipped.Name == "M4A1", "replacement must recover equipped weapon")
assert(#replacement:GetChildren() == 4, "default weapons restored; pickup-only models excluded")
Loadout.give(player, true)
Loadout.equip(player, 1)
flush()
assert(#replacement:GetChildren() == 4, "recovery must not duplicate tools")
Loadout.equip(player, 4)
equipped = character:FindFirstChildOfClass("Tool")
assert(equipped:GetAttribute("WeaponSlot") == 4 and equipped:GetAttribute("Ammo") == 3)
equipped:SetAttribute("Ammo", 2)
Loadout.equip(player, 4)
equipped = character:FindFirstChildOfClass("Tool")
assert(equipped:GetAttribute("WeaponSlot") == 5 and player:GetAttribute("SelectedSlot") == 4)
Loadout.equip(player, 4)
equipped = character:FindFirstChildOfClass("Tool")
assert(equipped:GetAttribute("WeaponSlot") == 4 and equipped:GetAttribute("Ammo") == 2,
	"key 4 cycles grenade types without refilling inventory")
Loadout.equip(player, 1)
equipped = character:FindFirstChildOfClass("Tool")
-- Selecting a missing slot must never conjure a replacement gun.
equipped:Destroy()
character:SetAttribute("DroppedSlot1", true)
Loadout.equip(player, 1)
assert(character:FindFirstChildOfClass("Tool") == nil, "empty slot stays empty")
Loadout.give(player, true)
assert(not Loadout.find(player, 1), "Backpack repair respects intentionally dropped slot")
Loadout.equip(player, 2)
local pistol = character:FindFirstChildOfClass("Tool")
assert(pistol.Name == "Glock 17" and pistol:GetAttribute("Ammo") == 17, "Glock replaces Luger with 17-round magazine")
assert(pistol:GetAttribute("ReserveAmmo") == 51, "three spare Glock magazines")
local pistolParts = {}
for _, child in pistol:FindFirstChildOfClass("Part"):GetChildren() do pistolParts[child.Name] = child end
assert(pistolParts.GlockSlide and pistolParts.PolymerFrame and pistolParts.TriggerSafety, "Glock geometry is built")
assert(not pistolParts.Toggle and not pistolParts.WoodGripPanel, "no Luger geometry remains")
local slideWeld = pistolParts.GlockSlide:FindFirstChildOfClass("Weld")
assert(not pistolParts.GlockSlide.Anchored and slideWeld and slideWeld.Name == "AnimationWeld", "world pistol has an animatable weld")
for slot, expected in {[6]={"AKReceiver",30,90}, [7]={"M249Receiver",100,300}} do
	local primary = Loadout.create(slot)
	assert(primary:GetAttribute("Ammo")==expected[2] and primary:GetAttribute("ReserveAmmo")==expected[3])
	local found=false
	for _, part in primary:FindFirstChildOfClass("Part"):GetChildren() do
		if part.Name==expected[1] then found=true end
	end
	assert(found, "new primary has distinct geometry")
	primary.Parent=replacement
	character:SetAttribute("DroppedSlot1",false)
	Loadout.give(player,true)
	assert(not Loadout.find(player,1), "repair does not add M4 beside another primary")
	Loadout.equip(player,1)
	assert(character:FindFirstChildOfClass("Tool")==primary and player:GetAttribute("SelectedSlot")==1)
	Loadout.equip(player,2)
	Loadout.equip(player,1)
	assert(character:FindFirstChildOfClass("Tool")==primary, "key 1 re-equips picked-up primary")
	primary:Destroy()
end
local ak = Loadout.create(6)
ak:SetAttribute("Ammo",7); ak:SetAttribute("ReserveAmmo",13); ak.Parent=replacement
pistol:SetAttribute("Ammo",0); pistol:SetAttribute("ReserveAmmo",0)
Loadout.find(player,4):Destroy()
Loadout.find(player,5):SetAttribute("Ammo",0)
character:SetAttribute("Armor",40); character:SetAttribute("Helmet",true)
Loadout.equip(player,1)
local saved=Loadout.capture(player)
Loadout.give(player)
Loadout.restore(player,saved)
Loadout.give(player,true)
assert(not Loadout.find(player,1) and Loadout.find(player,6), "picked-up AK survives without default M4")
assert(Loadout.find(player,6):GetAttribute("Ammo")==7 and Loadout.find(player,6):GetAttribute("ReserveAmmo")==13)
assert(Loadout.find(player,2):GetAttribute("Ammo")==0 and Loadout.find(player,2):GetAttribute("ReserveAmmo")==0)
assert(not Loadout.find(player,4) and Loadout.find(player,5):GetAttribute("Ammo")==0, "spent grenades stay spent after repair")
assert(character:GetAttribute("Armor")==40 and character:GetAttribute("Helmet"))
assert(character:FindFirstChildOfClass("Tool"):GetAttribute("WeaponSlot")==6)
print("Loadout: equip, Backpack repair and exact survivor inventory restoration OK")
