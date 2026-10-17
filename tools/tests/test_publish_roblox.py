import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import io


SPEC = importlib.util.spec_from_file_location(
    "publish_roblox", Path(__file__).resolve().parents[1] / "publish_roblox.py"
)
publish = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(publish)


class PublishTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.place = Path(self.temp.name) / "place.rbxl"
        self.place.write_bytes(b"test place")
        self.env = {
            "ROBLOX_API_KEY": "test-secret",
            "ROBLOX_UNIVERSE_ID": "123",
            "ROBLOX_PLACE_ID": "456",
        }

    def test_request(self):
        request = publish.make_request(self.place, self.env)
        self.assertEqual(request.get_method(), "POST")
        self.assertEqual(request.full_url, "https://apis.roblox.com/universes/v1/123/places/456/versions?versionType=Published")
        self.assertEqual(request.get_header("X-api-key"), "test-secret")
        self.assertEqual(request.get_header("Content-type"), "application/octet-stream")
        self.assertEqual(request.data, b"test place")

    def test_xml(self):
        place = self.place.with_suffix(".rbxlx")
        place.write_text("<roblox/>")
        self.assertEqual(publish.make_request(place, self.env).get_header("Content-type"), "application/xml")

    def test_missing_key(self):
        self.env.pop("ROBLOX_API_KEY")
        with self.assertRaises(ValueError):
            publish.make_request(self.place, self.env)

    def test_invalid_ids(self):
        for name in ("ROBLOX_PLACE_ID", "ROBLOX_UNIVERSE_ID"):
            for value in ("", "0", "-1", "1/2", "123?x=1", "１２３"):
                with self.subTest(name=name, value=value), self.assertRaises(ValueError):
                    publish.make_request(self.place, {**self.env, name: value})

    def test_empty_file(self):
        self.place.write_bytes(b"")
        with self.assertRaises(ValueError):
            publish.make_request(self.place, self.env)

    def test_publish_and_summary(self):
        summary = Path(self.temp.name) / "summary.md"
        with patch.dict(publish.os.environ, {**self.env, "GITHUB_STEP_SUMMARY": str(summary)}, clear=True), \
             patch.object(publish.sys, "argv", ["publish", str(self.place)]), \
             patch.object(publish, "urlopen") as opener, \
             patch("sys.stdout", new_callable=io.StringIO):
            opener.return_value.__enter__.return_value = io.BytesIO(b'{"versionNumber":7}')
            self.assertEqual(publish.main(), 0)
        opener.assert_called_once()
        self.assertIn("version 7", summary.read_text())
        self.assertNotIn("test-secret", summary.read_text())

    def test_http_failure_does_not_leak_secret(self):
        with patch.dict(publish.os.environ, self.env, clear=True), \
             patch.object(publish.sys, "argv", ["publish", str(self.place)]), \
             patch.object(publish, "urlopen", side_effect=publish.HTTPError("url", 403, "test-secret", {}, None)) as opener, \
             patch("sys.stderr", new_callable=io.StringIO) as output:
            self.assertEqual(publish.main(), 1)
        opener.assert_called_once()
        self.assertIn("403", output.getvalue())
        self.assertNotIn("test-secret", output.getvalue())

    def test_conflict_has_actionable_hint_without_retry_or_secret(self):
        with patch.dict(publish.os.environ, self.env, clear=True), \
             patch.object(publish.sys, "argv", ["publish", str(self.place)]), \
             patch.object(publish, "urlopen", side_effect=publish.HTTPError(
                 "url", 409, "test-secret", {}, io.BytesIO(b"test-secret"))) as opener, \
             patch("sys.stderr", new_callable=io.StringIO) as output:
            self.assertEqual(publish.main(), 1)
        opener.assert_called_once()
        self.assertIn("409", output.getvalue())
        self.assertIn("Team Create", output.getvalue())
        self.assertIn("Version History", output.getvalue())
        self.assertNotIn("test-secret", output.getvalue())


if __name__ == "__main__":
    unittest.main()
