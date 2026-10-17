"""Real Luau session controller with service doubles, plus actual map clearance."""
from pathlib import Path
import unittest
import test_combat
import test_player_spawn as spawn

ROOT = Path(__file__).resolve().parents[2]


class SessionTests(unittest.TestCase):
    run_luau = test_combat.CombatTests.run_luau

    def test_real_round_and_roster_controller(self):
        fixture = (ROOT / 'tools/tests/fixtures/session.luau').read_text()
        fixture = fixture.replace('-- SESSION_RULES_HERE', (ROOT / 'src/shared/SessionRules.luau').read_text())
        fixture = fixture.replace('-- SESSION_MODULE_HERE', (ROOT / 'src/server/Session.luau').read_text())
        self.run_luau(fixture)

    def test_all_ten_spawn_positions_have_room_clearance(self):
        spawn.PlayerSpawnTests.setUpClass()
        for z in (-9.8125, -68):
            for index in range(5):
                x = -25 + index * 3
                with self.subTest(x=x, z=z):
                    self.assertFalse([b[0] for b in spawn.PlayerSpawnTests.boxes
                                      if spawn.intersects((x, 2.6, z), (1.05, 2.48, 1.05), b)])
                    floors = [v[1] for b in spawn.PlayerSpawnTests.boxes
                              if (v := spawn.vertical_interval(x, z, b)) and v[1] < .2]
                    self.assertAlmostEqual(max(floors), 0, delta=.1)


if __name__ == '__main__':
    unittest.main()
