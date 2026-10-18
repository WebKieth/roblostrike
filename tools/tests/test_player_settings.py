"""Execute persistent player settings against a durable DataStore double."""
from pathlib import Path
import unittest
import test_combat

ROOT = Path(__file__).resolve().parents[2]


class PlayerSettingsTests(unittest.TestCase):
    run_luau = test_combat.CombatTests.run_luau

    def test_persistence_validation_and_failed_reads(self):
        fixture = (ROOT / 'tools/tests/fixtures/player_settings.luau').read_text()
        self.run_luau(fixture.replace('-- SETTINGS_MODULE_HERE', (ROOT / 'src/server/PlayerSettings.luau').read_text()))


if __name__ == '__main__':
    unittest.main()
