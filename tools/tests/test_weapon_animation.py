"""Execute authored poses and moving geometry; visual quality still needs Studio."""
from pathlib import Path
import unittest

import test_combat

ROOT = Path(__file__).resolve().parents[2]


class WeaponAnimationTests(unittest.TestCase):
    run_luau = test_combat.CombatTests.run_luau

    def runtime(self):
        fixture = (ROOT / 'tools/tests/fixtures/character_animation.luau').read_text()
        return fixture.split('local callback, connections, disconnected')[0]

    def test_reload_phases_empty_tactical_and_shot_cycle(self):
        source = (ROOT / 'src/shared/WeaponAnimation.luau').read_text()
        self.run_luau(self.runtime() + '\nlocal A = (function()\n' + source + r'''
end)()
local function near(a,b) assert(math.abs(a-b)<1e-6, tostring(a).." != "..tostring(b)) end
for _,slot in {1,2,6,7} do
    for _,empty in {false,true} do
        for _,fps in {30,60,144,240} do
            for frame=0,fps do
                local p=A.sample(slot,frame/fps,empty,math.huge)
                for _,v in {p.Magazine,p.Cover,p.Belt,p.Bolt} do assert(v>=0 and v<=1) end
                if not empty and slot~=7 then near(p.Bolt,0) end
                assert(p.Weapon.Position.Magnitude<1)
            end
        end
        local idle=A.sample(slot,nil,empty,math.huge)
        local finish=A.sample(slot,1,empty,math.huge)
        near(finish.Weapon.Position.Magnitude,0)
        near((finish.Weapon.LookVector-idle.Weapon.LookVector).Magnitude,0)
        assert(finish.LeftHand==nil and finish.Magazine==0 and finish.Bolt==0)
    end
    local before=A.sample(slot,.7,true,math.huge)
    local pull=A.sample(slot,.8,true,math.huge)
    near(before.Bolt,0); near(pull.Bolt,1)
    assert(pull.LeftHand~=nil)
end
for _,slot in {1,2,6} do
    local p=A.sample(slot,.4,false,math.huge)
    near(p.Weapon.LookVector.Y,math.sin(math.rad(45)))
    near(p.Magazine,1); assert(p.MagazineHidden)
    near(A.sample(slot,.62,true,math.huge).Magazine,0)
end
near(A.sample(6,.8,true,math.huge).Weapon.roll,math.rad(90))
assert(A.sample(1,.8,true,math.huge).Weapon.Position.Z<0, "M4 moves away to reach rear handle")
local cover=A.sample(7,.26,false,math.huge)
near(cover.Cover,1); near(cover.Weapon.LookVector.X,-math.sin(math.rad(70)))
local belt=A.sample(7,.4,false,math.huge)
near(belt.Cover,1); near(belt.Belt,1); near(belt.Magazine,0)
local charged=A.sample(7,.8,false,math.huge)
near(charged.Cover,0); near(charged.Belt,0); near(charged.Bolt,1)
near(charged.Weapon.roll,math.rad(90))
near(A.sample(2,nil,false,0).Bolt,0)
near(A.sample(2,nil,false,.025).Bolt,1)
near(A.sample(2,nil,false,.11).Bolt,0)
local attrs={WeaponSlot=6,Reloading=true,ReloadStarted=10,ReloadDuration=2.5,ReloadEmpty=true}
local tool={GetAttribute=function(_,key) return attrs[key] end}
near(A.fromTool(tool,12).Bolt,1)
attrs.Reloading=false
near(A.fromTool(tool,12).Bolt,0)
print("Reload phase, weapon axes, empty/tactical, shot cycle and timing OK")
''')

    def test_moving_parts_and_rebind_do_not_accumulate_offsets(self):
        source = (ROOT / 'src/client/WeaponParts.luau').read_text()
        self.run_luau(self.runtime() + '\nlocal P = (function()\n' + source + r'''
end)()
local parts={}
for _,name in {"GlockSlide","SlideSerration","FrontSightPost","MagazineBase","GlockMagazine","FeedCover","BeltRound","ChargingHandle"} do
    local weld={C0=CFrame.identity,IsA=function(_,kind) return kind=="Weld" end}
    local part={Name=name,Transparency=0,CFrame=CFrame.identity,Weld=weld}
    function part:IsA(kind) return kind=="BasePart" end
    function part:FindFirstChild() return self.Weld end
    function part:GetAttribute() return CFrame.identity end
    table.insert(parts,part)
end
-- Standalone typeof does not recognize the numeric CFrame double.
local handle={CFrame=CFrame.identity,GetChildren=function() return parts end}
function frameMeta:ToObjectSpace(other) return self:Inverse()*other end
local oldIndex=frameMeta.__index
frameMeta.__index=function(f,key) return frameMeta[key] or oldIndex(f,key) end
local update=P.bind(handle,.5)
local pose={Magazine=1,MagazineHidden=true,Cover=1,Belt=1,Bolt=1}
update(pose,2,.5)
for i=1,3 do assert(math.abs(parts[i].Weld.C0.Position.Z-.16)<1e-6) end
for i=4,5 do assert(parts[i].Transparency==1 and parts[i].Weld.C0.Position.Y<0) end
assert(parts[6].Weld.C0.LookVector.Y<-.9, "feed cover hinges forward")
assert(parts[7].Weld.C0.Position.Y>.3)
pose={Magazine=0,MagazineHidden=false,Cover=0,Belt=0,Bolt=0}
update(pose,2,.5)
for _,part in parts do assert(part.Transparency==0 and part.Weld.C0.Position.Magnitude<1e-6) end
update=P.bind(handle,.5); update(pose,2,.5)
for _,part in parts do assert(part.Weld.C0.Position.Magnitude<1e-6) end
print("Slide group, detachable magazine, cover hinge, belt and reset OK")
''')

    def test_awp_right_hand_bolt_and_left_hand_magazine(self):
        source = (ROOT / 'src/shared/WeaponAnimation.luau').read_text()
        self.run_luau(self.runtime() + '\nlocal A = (function()\n' + source + r'''
end)()
local function near(a,b) assert(math.abs(a-b)<1e-6, tostring(a).." != "..tostring(b)) end
for _,fps in {30,60,144,240} do
    for frame=0,fps do
        for _,empty in {false,true} do
            local p=A.sample(8,frame/fps,empty,math.huge)
            assert(p.Bolt>=0 and p.Bolt<=1 and p.Magazine>=0 and p.Magazine<=1)
            if not empty then near(p.Bolt,0) end
        end
    end
end
local cycle=A.sample(8,nil,false,.7,1.4)
near(cycle.Bolt,1)
near(cycle.Weapon.roll,math.rad(45))
assert(cycle.Weapon.Position.Z<0 and cycle.RightHand.X>.4)
assert(cycle.LeftHand==nil and cycle.Magazine==0)
local magazine=A.sample(8,.4,false,math.huge)
near(magazine.Weapon.LookVector.Y,math.sin(math.rad(45)))
local unpitched=CFrame.Angles(math.rad(-45),0,0)*magazine.Weapon.Rotation
near(unpitched.roll,math.rad(-45))
assert(magazine.LeftHand.Y<-1 and magazine.MagazineHidden)
near(magazine.RightHand.X,0)
local empty=A.sample(8,.8,true,math.huge)
near(empty.Bolt,1); near(empty.Weapon.roll,math.rad(45))
assert(empty.RightHand.X>.4 and empty.LeftHand.Z<-.8)
local tactical=A.sample(8,.8,false,math.huge)
near(tactical.Bolt,0); near(tactical.RightHand.X,0)
for _,p in {A.sample(8,nil,false,1.4,1.4),A.sample(8,1,true,0)} do
    near(p.Weapon.Position.Magnitude,0)
    assert(p.RightHand==nil and p.LeftHand==nil and p.Bolt==0)
end
''')

    def test_awp_glass_and_continuous_barrel_in_world_and_viewmodel(self):
        model = (ROOT / 'src/shared/GunModel.luau').read_text()
        parts = (ROOT / 'src/client/WeaponParts.luau').read_text()
        weapons = (ROOT / 'src/shared/Weapons.luau').read_text()
        self.run_luau(self.runtime() + r'''
local typeof=function(v) return if getmetatable(v)==frameMeta then "CFrame" else type(v) end
local originalIndex=frameMeta.__index
function frameMeta:ToObjectSpace(other) return self:Inverse()*other end
frameMeta.__index=function(f,k) return frameMeta[k] or originalIndex(f,k) end
local Enum={Material={SmoothPlastic=1,Metal=2,Glass=3},PartType={Cylinder=1,Ball=2},MeshType={Sphere=1}}
local Color3={fromRGB=function(...) return {...} end,new=function(...) return {...} end}
local Instance={}
local methods={}
function methods:GetChildren() return self.children end
function methods:GetAttribute(k) return self.attrs[k] end
function methods:SetAttribute(k,v) self.attrs[k]=v end
function methods:IsA(kind) return kind==self.ClassName or (kind=="BasePart" and self.ClassName=="Part") end
function methods:FindFirstChild(name)
    for _,child in self.children do if child.Name==name then return child end end
end
function Instance.new(kind)
    return setmetatable({ClassName=kind,children={},attrs={},Transparency=0,CFrame=CFrame.identity}, {
        __index=methods,
        __newindex=function(self,k,v)
            rawset(self,k,v)
            if k=="Parent" then table.insert(v.children,self) end
        end,
    })
end
local G=(function()
''' + model + '\nend)()\nlocal P=(function()\n' + parts + '\nend)()\nlocal W=(function()\n' + weapons + r'''
end)()
local function near(a,b) assert(math.abs(a-b)<1e-6,tostring(a).." != "..tostring(b)) end
for _,anchored in {false,true} do
    local handle=Instance.new("Part")
    G.build(handle,8,anchored)
    local lenses,rims,shoulders={},{},{}
    for _,part in handle:GetChildren() do
        assert(part.Anchored==anchored and not part.CanCollide and not part.CanQuery)
        if part.Name=="ScopeLens" then table.insert(lenses,part) end
        if part.Name=="ScopeRim" then table.insert(rims,part) end
        if part.Name=="ScopeShoulder" then table.insert(shoulders,part) end
        assert(part.Name~="ScopeBell", "no opaque solid disk behind the aperture")
    end
    assert(#lenses==2, "both ocular and objective have glass")
    assert(#rims==64, "two open retaining rings")
    assert(#shoulders==10, "both bells have closed stepped shoulders")
    assert(handle:FindFirstChild("ElevationDial") and handle:FindFirstChild("WindageDial"))
    for _,lens in lenses do
        local mesh=lens.children[if anchored then 1 else 2]
        assert(mesh.ClassName=="SpecialMesh" and mesh.MeshType==Enum.MeshType.Sphere,
            "sphere mesh preserves elliptical lens instead of Ball Part's small ball")
        assert(lens.Shape~=Enum.PartType.Ball and lens.Material==Enum.Material.Glass)
        assert(lens.Size.Z<lens.Size.X and lens.Size.X==lens.Size.Y, "shallow spherical lens")
        assert(lens.Size.X/.4>.85, "glass fills the scope aperture, not a small central dot")
        assert(lens.Size.X<.4 and lens.Reflectance>0 and lens.Transparency>0 and lens.Transparency<1)
        local outward=if lens.CFrame.Position.Z>0 then 1 else -1
        local glassFace=lens.CFrame.Position.Z+outward*lens.Size.Z*mesh.Scale.Z/2
        local bellFace=if outward>0 then .64+.125 else -.76-.125
        local recess=(bellFace-glassFace)*outward
        assert(recess>0 and recess<.025, "glass is slightly recessed, never a protruding bubble")
        assert(lens.Size.Z*mesh.Scale.Z/lens.Size.X<.08, "very shallow convexity")
    end
    for _,rim in rims do
        local position=rim.CFrame.Position
        local radius=math.sqrt(position.X^2+(position.Y-.48)^2)
        near(radius-rim.Size.X/2,.175)
        near(radius+rim.Size.X/2,.2)
    end
    for bell,z in {-.76,.64} do
        local outward=if z>0 then 1 else -1
        local previousOuter=-math.huge
        for step=1,5 do
            local shoulder=shoulders[(bell-1)*5+step]
            assert(shoulder.Shape==Enum.PartType.Cylinder and shoulder.Transparency==0,
                "opaque full circumference, not a see-through annular back")
            local center=shoulder.CFrame.Position.Z*outward
            local innerEdge,outerEdge=center-shoulder.Size.X/2,center+shoulder.Size.X/2
            if step>1 then assert(innerEdge<previousOuter, "shoulder steps overlap without cracks") end
            previousOuter=outerEdge
            if step==1 then assert(shoulder.Size.Y>=.24, "transition overlaps central tube radius") end
            if step==5 then
                near(shoulder.Size.Y,.4)
                local rimBack=(z-outward*.125)*outward
                assert(innerEdge<rimBack and outerEdge>rimBack, "shoulder closes the entire back of bell")
                local glassBack=(z+outward*.105)*outward-.01
                assert(outerEdge<glassBack, "shoulder stays behind the exposed lens")
            end
        end
    end
    local shank=handle:FindFirstChild("BarrelShank")
    local barrel=handle:FindFirstChild("HeavyBarrel")
    local crown=handle:FindFirstChild("MuzzleCrown")
    local bore=handle:FindFirstChild("Bore")
    local function ends(part)
        local a=part.CFrame:PointToWorldSpace(Vector3.new(-part.Size.X/2,0,0)).Z
        local b=part.CFrame:PointToWorldSpace(Vector3.new(part.Size.X/2,0,0)).Z
        return math.min(a,b),math.max(a,b)
    end
    local shankFront,shankRear=ends(shank)
    local barrelFront,barrelRear=ends(barrel)
    local crownFront,crownRear=ends(crown)
    local boreFront,boreRear=ends(bore)
    assert(shankRear>=-.475 and shankFront<=barrelRear, "barrel starts in receiver without gaps")
    assert(barrelFront<=crownRear and crownFront<=barrelFront, "barrel reaches crown")
    near(crownFront,boreRear)
    near(crownFront,W[8].Muzzle.Z)
    local animate=P.bind(handle,1)
    for _,pose in {
        {Magazine=1,MagazineHidden=true,Cover=0,Belt=0,Bolt=1},
        {Magazine=0,MagazineHidden=false,Cover=0,Belt=0,Bolt=0},
    } do
        animate(pose,8,1)
        for _,lens in lenses do near(lens.Transparency,.18) end
    end
    animate=P.bind(handle,1)
    animate({Magazine=0,MagazineHidden=false,Cover=0,Belt=0,Bolt=0},8,1)
    for _,lens in lenses do near(lens.Transparency,.18) end
end
''')


if __name__ == '__main__':
    unittest.main()
