"""Execute bot decisions with deterministic geometry; Studio still owns physics/navmesh."""
from pathlib import Path
import shutil
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class BotTests(unittest.TestCase):
    def test_accuracy_halfway_to_original_without_faster_reactions(self):
        rules = (ROOT / 'src/shared/SessionRules.luau').read_text()
        base = float(re.search(r'BotAimBase = ([\d.]+)', rules)[1])
        slope = float(re.search(r'BotAimDistance = ([\d.]+)', rules)[1])
        for distance in (0, 10, 50, 100, 300):
            self.assertAlmostEqual(base + distance * slope,
                                   (2 + 2.5 + distance * 0.07) / 2)
        source = (ROOT / 'src/server/Bots.luau').read_text()
        self.assertIn('Rules.BotAimBase + distance * Rules.BotAimDistance', source)
        self.assertIn('random:NextNumber(0.9, 1.6)', source)
        self.assertIn('random:NextNumber(0.8, 1.4)', source)

    def test_tactics_and_combat_loop(self):
        local = ROOT / '.tools/luau/luau'
        runner = str(local) if local.exists() else shutil.which('luau')
        if not runner:
            self.skipTest('Install standalone Luau to execute bot tests')
        fixture = (ROOT / 'tools/tests/fixtures/bots.luau').read_text()
        fixture = fixture.replace('-- TACTICS_MODULE_HERE', (ROOT / 'src/server/BotTactics.luau').read_text())
        fixture = fixture.replace('-- BOTS_MODULE_HERE', (ROOT / 'src/server/Bots.luau').read_text())
        with tempfile.TemporaryDirectory(prefix='robostrike-bots-') as directory:
            path = Path(directory) / 'bots.luau'
            path.write_text(fixture)
            result = subprocess.run([runner, str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
