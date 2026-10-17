"""Damage feedback math and integration contracts; visuals still need Studio."""
from pathlib import Path
import test_combat
import unittest

ROOT = Path(__file__).resolve().parents[2]


class HitFeedbackTests(unittest.TestCase):
    run_luau = test_combat.CombatTests.run_luau

    def test_bearing_and_exact_eased_recovery(self):
        source = (ROOT / 'src/shared/HitFeedback.luau').read_text()
        self.run_luau('local H = (function()\n' + source + '\nend)()\n' + r'''
local function near(a, b) assert(math.abs(a - b) < 1e-9) end
near(H.bearing(0, -10), 0)
near(H.bearing(10, 0), math.pi / 2)
near(math.abs(H.bearing(0, 10)), math.pi)
near(H.bearing(-10, 0), -math.pi / 2)
near(H.bearing(0, 0), 0)
assert(H.Recovery == .5)
near(H.weight(0, H.Recovery), 1)
near(H.weight(.25, H.Recovery), .25)
near(H.weight(.5, H.Recovery), 0)
near(H.weight(10, H.Recovery), 0)
assert(H.CameraPitch > 0 and H.AimDrop > 0)
for fps = 30, 240, 30 do
    local previous = 1
    for frame = 0, fps do
        local weight = H.weight(frame / fps, H.Recovery)
        assert(weight <= previous and weight >= 0)
        -- Camera rises while the real ballistic aim drops, so the reticle
        -- moves down relative to the camera by the sum of the two angles.
        local camera = H.CameraPitch * weight
        local bullet = -H.AimDrop * weight
        assert(bullet - camera <= 0)
        if frame / fps >= .5 then assert(camera == 0 and bullet == 0) end
        previous = weight
    end
end
''')

    def test_server_routes_only_real_damage_to_victim(self):
        server = (ROOT / 'src/server/Combat.luau').read_text()
        self.assertIn('damageTaken = remote("DamageTaken")', server)
        self.assertIn('damageTaken:FireClient(player, body, origin, headshot)', server)
        self.assertIn('if victim.Health < health then', server)
        self.assertIn('Survival.zone(hit.Instance.Name) == "Head"', server)
        self.assertLess(server.index('Rules.friendly(source, body)'), server.index('Combat.incoming(body,'))
        for path in ('Bots', 'Knife'):
            self.assertIn('Combat.damage(', (ROOT / f'src/server/{path}.luau').read_text())
        grenade = (ROOT / 'src/server/Grenades.luau').read_text()
        self.assertIn('if victim.Humanoid.Health < health then Combat.incoming(victim.Body, position, false)', grenade)

    def test_actual_weapon_direction_and_lifecycle(self):
        client = (ROOT / 'src/client/Combat.luau').read_text()
        self.assertIn('local flinchLift, aimDrop = hitFeedback()', client)
        self.assertIn('offset -= Vector2.new(0, aimDrop)', client)
        self.assertLess(client.index('offset -= Vector2.new(0, aimDrop)'), client.index('Ballistics.elevation(basePitch, offset.Y)'))
        self.assertLess(client.index('Ballistics.elevation(basePitch, offset.Y)'), client.index('local aim = state.Aim'))
        self.assertIn('local direction = weaponFrame.LookVector', client)
        self.assertIn('fire:FireServer(muzzle - head.Position, direction)', client)
        hud = (ROOT / 'src/client/HitFeedback.luau').read_text()
        for contract in ('body ~= player.Character or not alive()',
                         'player.CharacterRemoving:Connect(clear)',
                         'player.CharacterAdded:Connect(clear)',
                         'if not alive() then clear(); return end',
                         '#arcs >= 8', 'Instance.new("UIGradient")',
                         'camera.CFrame:VectorToObjectSpace(arc.Origin - camera.CFrame.Position)'):
            self.assertIn(contract, hud)

    def test_no_armbands(self):
        self.assertNotIn('TeamArmband', (ROOT / 'src/server/Session.luau').read_text())


if __name__ == '__main__':
    unittest.main()
