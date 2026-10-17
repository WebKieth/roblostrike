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

    def session_fixture(self):
        fixture = (ROOT / 'tools/tests/fixtures/session.luau').read_text()
        fixture = fixture.replace('-- SESSION_RULES_HERE', (ROOT / 'src/shared/SessionRules.luau').read_text())
        fixture = fixture.replace('-- SESSION_MODULE_HERE', (ROOT / 'src/server/Session.luau').read_text())
        fixture = fixture.replace('-- COLLISION_MODULE_HERE', (ROOT / 'src/server/CharacterCollision.luau').read_text())
        fixture = fixture.replace('-- MOVEMENT_MODULE_HERE', (ROOT / 'src/server/Movement.luau').read_text())
        fixture = fixture.replace('-- CONFIG_MODULE_HERE', (ROOT / 'src/shared/Config.luau').read_text())
        return fixture

    def test_real_round_and_roster_controller(self):
        self.run_luau(self.session_fixture())

    def test_one_second_freeze_and_ten_percent_slower_movement(self):
        config = (ROOT / 'src/shared/Config.luau').read_text()
        for name, previous in (('RunSpeed', 22), ('WalkSpeed', 10),
                               ('CrouchSpeed', 6), ('BotSpeed', 16)):
            value = float(re.search(rf'{name} = ([\d.]+)', config)[1])
            self.assertAlmostEqual(value, previous * 0.9)
        rules = (ROOT / 'src/shared/SessionRules.luau').read_text()
        self.assertRegex(rules, r'FreezeSeconds = 1,')
        session = (ROOT / 'src/server/Session.luau').read_text()
        self.assertEqual(session.count('then Config.BotSpeed else 0'), 2)

    def test_human_only_setup_and_no_disconnect_backfill(self):
        self.run_luau(self.session_fixture().replace('local scenario="default"', 'local scenario="no_bots"'))

    def test_configured_bot_budget_with_empty_slots(self):
        self.run_luau(self.session_fixture().replace('local scenario="default"', 'local scenario="one_bot"'))

    def test_restart_with_new_bot_count_after_team_reselection(self):
        self.run_luau(self.session_fixture().replace('local scenario="default"', 'local scenario="restart"'))

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
                        self.assertGreaterEqual(math.dist((x, y, z), other), 7)
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

    def test_spawns_have_wall_cover_from_arena(self):
        spawn.PlayerSpawnTests.setUpClass()
        boxes = spawn.PlayerSpawnTests.boxes
        walls = [b for b in boxes if spawn.intersects((0, 3, -32), (100, 2, 100), b)]
        # Include both doorways and diagonal shots from across the arena.
        sources = [(x, 4.5, z) for z in range(-18, -47, -4) for x in range(-30, 25, 3)
                   if not any(spawn.intersects((x, 2.6, z), (1, 2.48, 1), b) for b in boxes)]
        rules = (ROOT / 'src/shared/SessionRules.luau').read_text()
        for team in ('Blue', 'Red'):
            row = re.search(rf'{team} = \{{([^\n]+)\}}', rules)[1]
            for xyz in re.findall(r'\{([^}]+)\}', row):
                x, y, z = map(float, xyz.split(','))
                for source in sources:
                    for dx, dz in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
                        for height in (1.5, 4.5):
                            target = (x + dx, height, z + dz)
                            self.assertTrue(any(spawn.segment_intersects(source, target, b) for b in walls),
                                            f'{team} spawn {xyz} exposed from {source} to {target}')


if __name__ == '__main__':
    unittest.main()
