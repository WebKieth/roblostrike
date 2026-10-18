"""Run real grenade math and server state with small Roblox stubs; Studio still required."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class GrenadeTests(unittest.TestCase):
    def run_luau(self, source):
        runner = ROOT / '.tools/luau/luau'
        runner = str(runner) if runner.exists() else shutil.which('luau')
        if not runner:
            self.skipTest('Luau runtime not installed')
        with tempfile.TemporaryDirectory(prefix='robostrike-grenades-') as directory:
            path = Path(directory) / 'test.luau'
            path.write_text(source)
            result = subprocess.run([runner, str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_real_ballistics_and_linear_damage(self):
        rules = (ROOT / 'src/shared/Grenades.luau').read_text()
        self.run_luau('''
local mt = {}
mt.__index = function(v, key)
    if key == "Magnitude" then return math.sqrt(v.X^2+v.Y^2+v.Z^2) end
    if key == "Unit" then return v end
end
mt.__mul = function(v, s) return setmetatable({X=v.X*s,Y=v.Y*s,Z=v.Z*s},mt) end
local G = (function()
''' + rules + '''
end)()
local function near(a,b) assert(math.abs(a-b)<1e-6, tostring(a).." ~= "..tostring(b)) end
near(G.damage(0),150)
near(G.damage(5*G.StudsPerMeter),75)
near(G.damage(10*G.StudsPerMeter),0)
near(G.damage(20*G.StudsPerMeter),0)
local gravity = 196.2
for _, hip in {false,true} do
    local maximum = if hip then G.HipRange else G.ShoulderRange
    for _, height in {0.01,1,3,5} do
        local previous = 0
        for degrees = -90,90 do
            local pitch = math.rad(degrees)
            local direction = setmetatable({X=math.cos(pitch),Y=math.sin(pitch),Z=0},mt)
            local velocity = G.velocity(direction,hip,gravity,height)
            assert(velocity.X == velocity.X and velocity.Y == velocity.Y)
            local time = (velocity.Y+math.sqrt(velocity.Y^2+2*gravity*height))/gravity
            local distance = velocity.X*time
            assert(distance <= maximum + 1e-6, "exceeds maximum at "..degrees)
            if degrees == 45 then near(distance,maximum) end
            if degrees > -90 and degrees <= 45 then assert(distance >= previous-1e-6, "must increase to 45") end
            if degrees > 45 then assert(distance <= previous+1e-6, "must decrease above 45") end
            previous = distance
        end
    end
end
''')

    def test_real_server_grenade_lifecycle_and_occlusion(self):
        fixture = (ROOT / 'tools/tests/fixtures/grenades.luau').read_text()
        for marker, path in [('RULES', 'src/shared/Grenades.luau'), ('SERVER', 'src/server/Grenades.luau')]:
            fixture = fixture.replace('-- ' + marker + '_MODULE_HERE', (ROOT / path).read_text())
        fixture = fixture.replace('-- SESSION_RULES_HERE', (ROOT / 'src/shared/SessionRules.luau').read_text())
        self.run_luau(fixture)

    def test_four_hotbar_slots_and_clockwise_indicator(self):
        client = (ROOT / 'src/client/init.client.luau').read_text()
        grenades = (ROOT / 'src/client/Grenades.luau').read_text()
        self.assertNotIn('Enum.KeyCode.Five', client)
        self.assertIn('slot == selectedSlot and slot ~= 4', client)
        self.assertIn('rotation += 180', grenades)
        self.assertIn('TweenService:Create(arc', grenades)
        self.assertIn('send("Prime")', grenades)
        self.assertIn('send("Throw")', grenades)
