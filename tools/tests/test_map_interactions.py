"""Generated map contracts and reference projection math; playtest in Studio too."""
import math
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]


def named(root, name):
    return next(i for i in root.iter("Item")
                if i.findtext("Properties/string[@name='Name']") == name)


def xyz(node):
    return tuple(float(node.findtext(a)) for a in "XYZ")


class MapInteractionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = ET.parse(ROOT / "assets/generated/fy_pool_day.rbxmx").getroot()

    def test_six_doors_have_independent_panels_and_source_hinges(self):
        doors = named(self.root, "Doors").findall("Item")
        self.assertEqual(len(doors), 6)
        for door in doors:
            self.assertEqual(door.get("class"), "Model")
            panel = named(door, "Panel").find("Properties")
            x, y, z = xyz(panel.find("CoordinateFrame"))
            sx, sy, sz = xyz(panel.find("Vector3[@name='size']"))
            hx, hy, hz = xyz(named(door, "Hinge").find("Properties/Vector3[@name='Value']"))
            self.assertAlmostEqual(x - sx/2, hx)
            self.assertAlmostEqual(z - sz/2, hz)
            self.assertEqual((y, sy), (3.5, 5))
            self.assertEqual(hy, 3.25)
            self.assertEqual(named(door, "OpenAngle").findtext("Properties/double[@name='Value']"), "90.0")
            self.assertEqual(named(door, "CloseDelay").findtext("Properties/double[@name='Value']"), "4.0")

    def test_no_old_door_collision_or_tile_grout_is_left(self):
        for group in ("Geometry", "TileGrout"):
            for item in named(self.root, group).findall("Item"):
                name = item.findtext("Properties/string[@name='Name']")
                self.assertFalse(any(name.startswith(f"f{face}_") for face in range(1965, 2001)), name)

    def test_mirror_is_above_basin_in_west_passage(self):
        mirror = named(self.root, "PassageMirror").find("Properties")
        self.assertEqual(xyz(mirror.find("CoordinateFrame")), (-41.94, 6, -32))
        self.assertEqual(xyz(mirror.find("Vector3[@name='size']")), (.06, 3.6, 7.5))
        self.assertEqual(mirror.findtext("float[@name='Transparency']"), "0")
        self.assertEqual(len(named(self.root, "Mirrors").findall("Item")), 5)

    def test_off_axis_projection_pins_surface_corners(self):
        # Inverse of the non-orthonormal camera basis used by MapMirror.
        width, height = 7.5, 3.6
        tangent = math.tan(math.radians(35))
        for distance in (.3, 1, 8, 40):
            scale = height / (2 * distance * tangent)
            for eye_x, eye_y in ((0, 0), (5, -2), (-7, 3)):
                for x in (-width/2, width/2):
                    for y in (-height/2, height/2):
                        view_x = ((x-eye_x) - eye_x/distance*(-distance)) / scale
                        view_y = ((y-eye_y) - eye_y/distance*(-distance)) / scale
                        self.assertAlmostEqual(view_x/(distance*tangent*(width/height)), x/(width/2))
                        self.assertAlmostEqual(view_y/(distance*tangent), y/(height/2))

    def test_runtime_security_and_visibility_contracts(self):
        doors = (ROOT / "src/server/MapDoors.luau").read_text()
        for contract in ("humanoid.Health <= 0", "part.Parent ~= actor", "token ~= revision",
                         "GetPartBoundsInBox", "door.WorldPivot = pivot"):
            self.assertIn(contract, doors)
        self.assertNotIn("ProximityPrompt", doors)
        self.assertNotIn("OnServerEvent", doors)
        self.assertIn("panel.Size + Vector3.new(0.24, 0, 0)", doors)
        self.assertIn("if root.Position.X <= closedCenter.X then 1 else -1", doors)
        self.assertIn("swing * width / 2", doors)
        mirror = (ROOT / "src/client/MapMirror.luau").read_text()
        self.assertIn("copy.LocalTransparencyModifier = 0", mirror)
        self.assertIn("if not gui.Enabled then return end", mirror)
        self.assertIn("source.Position.X <= planeX + 0.08", mirror)


if __name__ == "__main__":
    unittest.main()
