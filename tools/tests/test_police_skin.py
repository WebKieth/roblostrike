"""Exercise cosmetic team skins and armor changes; rendering needs Studio."""
from pathlib import Path
import unittest
import test_combat

ROOT = Path(__file__).resolve().parents[2]


class PoliceSkinTests(unittest.TestCase):
    run_luau = test_combat.CombatTests.run_luau

    def test_team_silhouettes_and_armor_transitions(self):
        fixture = (ROOT / 'tools/tests/fixtures/police_skin.luau').read_text()
        for marker, path in (
            ('-- STYLE_HERE', 'src/shared/PoliceStyle.luau'),
            ('-- SKIN_HERE', 'src/server/PoliceSkin.luau'),
        ):
            fixture = fixture.replace(marker, (ROOT / path).read_text())
        self.run_luau(fixture)
