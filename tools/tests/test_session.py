"""Real Luau session controller with service doubles, plus actual map clearance."""
from pathlib import Path
import math
import re
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
        fixture = fixture.replace('-- COLLISION_MODULE_HERE', (ROOT / 'src/server/CharacterCollision.luau').read_text())
        self.run_luau(fixture)

    def test_bots_yield_without_pushing_or_retreating_into_walls(self):
        fixture = (ROOT / 'tools/tests/fixtures/bot_spacing.luau').read_text()
        self.run_luau(fixture.replace('-- BOTS_MODULE_HERE', (ROOT / 'src/server/Bots.luau').read_text()))

    def test_all_six_spawns_are_spread_inside_rooms(self):
        spawn.PlayerSpawnTests.setUpClass()
        rules = (ROOT / 'src/shared/SessionRules.luau').read_text()
        for team in ('Blue', 'Red'):
            row = re.search(rf'{team} = \{{([^\n]+)\}}', rules)[1]
            positions = [tuple(map(float, xyz.split(',')))
                         for xyz in re.findall(r'\{([^}]+)\}', row)]
            self.assertEqual(len(positions), 3)
            for index, (x, y, z) in enumerate(positions):
                with self.subTest(x=x, z=z):
                    self.assertTrue(2 <= z <= 8 if team == 'Blue' else -72 <= z <= -66)
                    for other in positions[index + 1:]:
                        self.assertGreaterEqual(math.dist((x, y, z), other), 16)
                    self.assertFalse([b[0] for b in spawn.PlayerSpawnTests.boxes
                                      if spawn.intersects((x, y - .5, z), (2, 2.48, 2), b)])
                    for dx in (-1, 0, 1):
                        for dz in (-1, 0, 1):
                            intervals = [v for b in spawn.PlayerSpawnTests.boxes
                                         if (v := spawn.vertical_interval(x + dx, z + dz, b))]
                            self.assertAlmostEqual(max(hi for lo, hi in intervals if hi < y - 2.9), 0, delta=.1)
                            ceiling = min(lo for lo, hi in intervals if lo > y + 2)
                            self.assertGreaterEqual(ceiling, 9)
                            self.assertLessEqual(ceiling, 10.1)


if __name__ == '__main__':
    unittest.main()
