"""Execute knife timing and server contacts; Studio is needed for actual geometry."""
from pathlib import Path
import unittest
import test_combat

ROOT = Path(__file__).resolve().parents[2]


class KnifeTests(unittest.TestCase):
    run_luau = test_combat.CombatTests.run_luau

    def test_real_server(self):
        fixture = (ROOT / 'tools/tests/fixtures/knife.luau').read_text()
        for marker, path in (
            ('-- RULES_MODULE_HERE', 'src/shared/Knife.luau'),
            ('-- SURVIVAL_MODULE_HERE', 'src/shared/Survival.luau'),
            ('-- COMBAT_MODULE_HERE', 'src/server/Combat.luau'),
            ('-- KNIFE_MODULE_HERE', 'src/server/Knife.luau'),
            ('-- SESSION_RULES_HERE', 'src/shared/SessionRules.luau'),
        ):
            fixture = fixture.replace(marker, (ROOT / path).read_text())
        self.run_luau(fixture)


if __name__ == '__main__':
    unittest.main()
