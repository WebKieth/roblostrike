"""Runtime checks without the private map-clearance integration tests."""
from pathlib import Path
import unittest
import test_combat

ROOT = Path(__file__).resolve().parents[2]


class SessionLootTests(unittest.TestCase):
    run_luau = test_combat.CombatTests.run_luau

    def test_session_and_bot_death_audio(self):
        fixture = (ROOT / 'tools/tests/fixtures/session.luau').read_text()
        for marker, path in (
            ('SESSION_RULES', 'src/shared/SessionRules.luau'),
            ('SESSION_MODULE', 'src/server/Session.luau'),
            ('COLLISION_MODULE', 'src/server/CharacterCollision.luau'),
            ('MOVEMENT_MODULE', 'src/server/Movement.luau'),
            ('CONFIG_MODULE', 'src/shared/Config.luau'),
            ('MAP_CATALOG', 'src/shared/MapCatalog.luau'),
        ):
            fixture = fixture.replace(f'-- {marker}_HERE', (ROOT / path).read_text())
        for scenario in ('default', 'death_audio', 'no_bots', 'one_bot', 'large', 'restart'):
            with self.subTest(scenario=scenario):
                self.run_luau(fixture.replace('local scenario="default"', f'local scenario="{scenario}"'))

    def test_loot(self):
        fixture = (ROOT / 'tools/tests/fixtures/loot.luau').read_text()
        fixture = fixture.replace('-- LOOT_MODULE_HERE', (ROOT / 'src/server/Loot.luau').read_text())
        fixture = fixture.replace('-- SURVIVAL_MODULE_HERE', (ROOT / 'src/shared/Survival.luau').read_text())
        self.run_luau(fixture)


if __name__ == '__main__':
    unittest.main()
