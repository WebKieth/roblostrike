local nodes = {}
local frame = setmetatable({}, { __mul = function(a, b) return a end })
local CFrame = { new = function(...) return frame end, identity = frame, Angles = function(...) return frame end }
local Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
local Vector2 = { new = function(...) return {} end }
local UDim2 = { fromScale = function(...) return {} end }
local Color3 = { fromRGB = function(...) return {...} end }
local Enum = {
    Material = { SmoothPlastic = "plastic" }, MeshType = { Sphere = "sphere" },
    NormalId = { Front = "front", Back = "back", Left = "left", Right = "right" },
    Font = { GothamBold = "bold" },
}
local Instance = {}
function Instance.new(class)
    local node = { ClassName = class, Transparency = 0, attributes = {}, signals = {}, CFrame = frame }
    function node:IsA(kind) return self.ClassName == kind or (kind == "BasePart" and self.ClassName == "Part") end
    function node:GetChildren()
        local children = {}
        for _, child in nodes do if child.Parent == self then table.insert(children, child) end end
        return children
    end
    function node:WaitForChild(name)
        for _, child in self:GetChildren() do if child.Name == name then return child end end
        error("Missing child " .. name)
    end
    function node:GetAttribute(name) return self.attributes[name] end
    function node:GetAttributeChangedSignal(name)
        self.signals[name] = self.signals[name] or {}
        local callbacks = self.signals[name]
        return { Connect = function(_, callback) table.insert(callbacks, callback) end }
    end
    function node:SetAttribute(name, value)
        self.attributes[name] = value
        for _, callback in self.signals[name] or {} do callback() end
    end
    function node:ScaleTo(scale) self.scale = scale end
    table.insert(nodes, node)
    return node
end
local style = (function()
-- STYLE_HERE
end)()
local config = { CharacterScale = 0.9 }
local game = { GetService = function() return { Shared = { PoliceStyle = style, Config = config } } end }
local function require(value) return value end
local skin = (function()
-- SKIN_HERE
end)()

local function character(team)
    local model = Instance.new("Model")
    for _, name in { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
        local limb = Instance.new("Part")
        limb.Name, limb.Parent = name, model
    end
    local face = Instance.new("Decal")
    face.Parent = model:WaitForChild("Head")
    skin.apply(model, team)
    assert(model.scale == 0.9)
    return model, model:WaitForChild(if team == "Red" then "PhoenixUniform" else "PoliceUniform"), face
end

local blue, outfit, face = character("Blue")
assert(face.Transparency == 1)
for _, name in { "TacticalHelmet", "GoggleLens", "FaceGuard", "ChestPlate", "LeftShoulderArmor", "RightForearmArmor" } do
    local part = outfit:WaitForChild(name)
    assert(not part.CanCollide and not part.CanQuery and part.Massless)
end
for _, armor in { 0, 100, 0 } do
    blue:SetAttribute("Armor", armor)
    blue:SetAttribute("Helmet", armor > 0)
    assert(outfit:WaitForChild("TacticalHelmet").Transparency == 0)
    assert(outfit:WaitForChild("BodyArmor").Transparency == 0)
    assert(outfit:WaitForChild("ArmorHelmet").Transparency == 1)
end
assert(blue:GetAttribute("Armor") == 0)
local red, phoenix = character("Red")
assert(phoenix:WaitForChild("Balaclava"))
assert(phoenix:WaitForChild("BodyArmor").Transparency == 1)
red:SetAttribute("Armor", 100)
red:SetAttribute("Helmet", true)
assert(phoenix:WaitForChild("BodyArmor").Transparency == 0)
assert(phoenix:WaitForChild("ArmorHelmet").Transparency == 0)
red:SetAttribute("Armor", 0)
assert(phoenix:WaitForChild("ArmorHelmet").Transparency == 1)
for _, part in phoenix:GetChildren() do assert(part.Name ~= "TacticalHelmet") end
