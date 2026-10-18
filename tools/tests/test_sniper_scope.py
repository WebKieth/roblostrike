"""Execute procedural scope layout; optical appearance still needs Studio."""
from pathlib import Path
import unittest

import test_combat

ROOT = Path(__file__).resolve().parents[2]


class SniperScopeTests(unittest.TestCase):
    run_luau = test_combat.CombatTests.run_luau

    def test_mask_reticle_zoom_and_visibility_on_multiple_aspects(self):
        source = (ROOT / 'src/client/SniperScope.luau').read_text()
        self.run_luau(r'''
local Vector2={}
local vector={}
function Vector2.new(x,y) return setmetatable({X=x,Y=y},vector) end
vector.__mul=function(a,b) return Vector2.new(a.X*b,a.Y*b) end
Vector2.zero=Vector2.new(0,0)
local UDim2={fromScale=Vector2.new,fromOffset=Vector2.new}
local Color3={new=function(...) return {...} end}
local Instance={}
local all={}
function Instance.new(kind)
    local obj={ClassName=kind}
    table.insert(all,obj)
    return obj
end
local Scope=(function()
''' + source + r'''
end)()
local update=Scope.start({})
local root=all[1]
assert(not root.Visible and root.Name=="SniperScope")
local count=#all
for _,size in {{1280,720},{1920,1080},{800,600},{600,1000}} do
    local w,h=size[1],size[2]
    local radius=math.min(w,h)*.46
    for _,zoom in {8,4,1.5} do
        update(true,zoom,Vector2.new(w,h),Vector2.new(w/2+2,h/2-3))
        assert(root.Visible and #all==count, "no per-frame UI allocation")
        assert(string.find(all[#all].Text,"×"..tostring(zoom),1,true))
        for i=1,128 do
            local left,right=all[2*i],all[2*i+1]
            local y=left.Position.Y
            assert(left.Position.X==0 and left.Size.X>=0)
            assert(math.abs(right.Position.X+right.Size.X-w-1)<1e-6)
            if math.abs(y-h/2)>radius then
                assert(left.Size.X==w/2 and right.Position.X==w/2, "opaque outside circle")
            else
                local dx=w/2-left.Size.X
                assert(dx*dx+(y-h/2)^2<=radius*radius+1e-6, "mask leaves only circular aperture")
            end
        end
        local horizontal,vertical=all[258],all[259]
        assert(horizontal.Position.Y==h/2-3 and vertical.Position.X==w/2+2,
            "reticle follows barrel hit rather than an independent fake center")
    end
end
update(false,8,Vector2.new(1280,720),Vector2.zero)
assert(not root.Visible)
''')


if __name__ == '__main__':
    unittest.main()
