import importlib.util
import math
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("import_bsp", ROOT / "tools/import_bsp.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class ImportTests(unittest.TestCase):
    def test_coordinate_transform_preserves_handedness(self):
        self.assertEqual(mod.position((16, 32, 48)), (1, 3, -2))
        x, y, z = [mod.position(p) for p in ((16, 0, 0), (0, 16, 0), (0, 0, 16))]
        self.assertEqual(mod.cross(x, y), z)

    def test_nonrectangle_is_not_filled_as_a_box(self):
        scene = mod.Scene()
        scene.surface(0, "floor", "worldspawn", [(0, 0, 0), (4, 0, 0), (2, 0, 2)])
        self.assertGreater(scene.counts["WedgePart"], 0)
        self.assertEqual(scene.counts["Part"], 0)

    def test_collinear_rectangle_vertices(self):
        scene = mod.Scene()
        scene.surface(0, "floor", "worldspawn", [(0, 0, 0), (2, 0, 0), (4, 0, 0), (4, 0, 4), (0, 0, 4)])
        self.assertEqual(scene.counts["WedgePart"], 0)
        self.assertGreater(scene.counts["Part"], 0)

    def test_generated_scene(self):
        tree = ET.parse(ROOT / "assets/generated/fy_pool_day.rbxmx")
        parts = [node for node in tree.iter("Item") if node.get("class") in {"Part", "WedgePart", "SpawnLocation"}]
        self.assertGreater(len(parts), 1000)
        self.assertEqual(sum(node.get("class") == "SpawnLocation" for node in parts), 32)
        for node in parts:
            props = node.find("Properties")
            if node.get("class") == "SpawnLocation":
                self.assertEqual(props.find("int[@name='Duration']").text, "0")
            self.assertEqual(props.find("bool[@name='Anchored']").text, "true")
            size = props.find("Vector3[@name='size']")
            self.assertTrue(all(math.isfinite(float(v.text)) and float(v.text) > 0 for v in size))
            frame = props.find("CoordinateFrame")
            cols = [tuple(float(frame.find(f"R{r}{c}").text) for r in range(3)) for c in range(3)]
            for col in cols:
                self.assertAlmostEqual(mod.length(col), 1, places=5)
            self.assertAlmostEqual(mod.dot(mod.cross(cols[0], cols[1]), cols[2]), 1, places=5)

    @unittest.skipUnless((ROOT / "assets/source/fy_pool_day.bsp").exists(), "Local BSP not present")
    def test_bsp_faces_and_door_offsets(self):
        bsp = mod.BSP(ROOT / "assets/source/fy_pool_day.bsp")
        self.assertEqual(len(bsp.faces), 2048)
        surfaces = list(bsp.surfaces())
        self.assertGreater(len(surfaces), 1900)
        doors = [p for _, mid, _, _, points, _ in surfaces if mid == 12 for p in points]
        # Rotating door vertices are local to the entity origin in the source BSP.
        self.assertAlmostEqual(min(p[0] for p in doors), 237 / 16)
        self.assertTrue(all(name.lower() not in mod.SKIP for _, _, name, _, _, _ in surfaces))


if __name__ == "__main__":
    unittest.main()
