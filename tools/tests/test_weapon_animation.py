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


if __name__ == '__main__':
    unittest.main()
