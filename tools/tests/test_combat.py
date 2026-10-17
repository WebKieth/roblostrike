"""Source contracts plus execution of the real Ballistics module with Luau.

Only Vector2's two numeric components are stubbed in the standalone runtime.
Roblox rendering, remotes and hit detection still need Studio integration tests.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class CombatTests(unittest.TestCase):
    def run_luau(self, script):
        local = ROOT / '.tools/luau/luau'
        runner = str(local) if local.exists() else shutil.which('luau')
        if not runner:
            self.skipTest('Standalone Luau is optional; install it to execute math tests')
        with tempfile.TemporaryDirectory(prefix='robostrike-combat-') as directory:
            path = Path(directory) / 'combat.luau'
            path.write_text(script)
            result = subprocess.run([runner, str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_one_visible_direction_and_no_hidden_cone(self):
        client = (ROOT / 'src/client/Combat.luau').read_text()
        server = (ROOT / 'src/server/Combat.luau').read_text()
        self.assertIn('state.Aim.Position + state.Aim.LookVector * 1000', client)
        self.assertIn('fire:FireServer(state.Aim.Position, state.Aim.LookVector)', client)
        self.assertIn('origin, direction * definition.Range', server)
        self.assertNotIn('Random', client)
        self.assertNotIn('Random', server)

    def test_server_owns_damage_ammo_rate_and_cover(self):
        server = (ROOT / 'src/server/Combat.luau').read_text()
        for guard in ('finiteVector(origin)', 'finiteVector(direction)',
                      '(origin - head.Position).Magnitude > 2.5',
                      'now < due - 0.025', 'tool:GetAttribute("Reloading")',
                      'tool:SetAttribute("Ammo", ammo - 1)', 'victim:TakeDamage',
                      'workspace:Raycast(head.Position, muzzle - head.Position, params)',
                      'workspace:Raycast(head.Position, offset, params)'):
            self.assertIn(guard, server)

    def test_material_effects_are_cosmetic_and_bounded(self):
        source = (ROOT / 'src/client/ShotEffects.luau').read_text()
        for material in ('Metal', 'Wood', 'Glass', 'Water'):
            self.assertIn('Enum.Material.' + material, source)
        self.assertIn('#marks > 100', source)
        self.assertIn('p.CanCollide, p.CanTouch, p.CanQuery = false, false, false', source)
        self.assertIn('Debris:AddItem', source)

    def test_real_luau_recovery_pattern_sway_and_cadence(self):
        source = (ROOT / 'src/shared/Ballistics.luau').read_text()
        script = r'''
local mt = { __mul = function(a, b) return { X = a.X * b, Y = a.Y * b } end }
local Vector2 = { new = function(x, y) return setmetatable({X=x, Y=y}, mt) end }
local B = (function()
''' + source + r'''
end)()
assert(B.Recovery == 0.5)
assert(B.recovery(0) == 1)
assert(B.recovery(0.499) > 0)
assert(B.recovery(0.5) == 0)
assert(B.recovery(10) == 0)
for fps = 30, 240, 30 do
    local previous = 1
    for frame = 0, fps do
        local weight = B.recovery(frame / fps)
        assert(weight <= previous and weight >= 0)
        previous = weight
    end
    local count, due = 0, 0
    for frame = 0, fps * 10 - 1 do
        local now = frame / fps
        if now >= due then
            count += 1
            due = B.nextShot(now, due, 0.0857, 1 / fps)
        end
    end
    assert(math.abs(count - 10 / 0.0857) < 2, tostring(fps) .. ": bad cadence " .. count)
end
assert(B.nextShot(20, 0, .0857, 1/60) == 20 + .0857, "idle cannot bank shots")
local positive, negative = false, false
for i = 1, 40 do
    local fast, slow = B.kick(i, .0857, 1), B.kick(i, .49, 1)
    assert(fast.Y > slow.Y and slow.Y > 0)
    positive = positive or fast.X > 0
    negative = negative or fast.X < 0
end
assert(positive and negative, "both horizontal directions")
for phase = 0, 20, .1 do
    local standing = B.sway(phase, 0, 0)
    local running, walking = B.sway(phase, 1, 0), B.sway(phase, .45, 0)
    local ads = B.sway(phase, 1, 1)
    assert(standing.X == 0 and standing.Y == 0)
    assert(running.Y <= 0, "wave comes from below the center")
    assert(math.abs(walking.X) <= math.abs(running.X))
    assert(math.abs(ads.X) <= math.abs(running.X))
end
-- ADS sight height cancels translation; recoil/reticle rays remain identical.
print("Ballistics: recovery, two-axis pattern, cadence and movement OK")
'''
        self.run_luau(script)

    def test_real_server_handlers_with_mocked_roblox_services(self):
        fixture = (ROOT / 'tools/tests/fixtures/combat_server.luau').read_text()
        server = (ROOT / 'src/server/Combat.luau').read_text()
        self.run_luau(fixture.replace('-- SERVER_MODULE_HERE', server))


if __name__ == '__main__':
    unittest.main()
