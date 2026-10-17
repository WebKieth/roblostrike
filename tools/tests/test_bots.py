"""Execute bot decisions with deterministic geometry; Studio still owns physics/navmesh."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class BotTests(unittest.TestCase):
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
