"""Offline framing checks; actual mesh/hand appearance needs Studio Play."""
from pathlib import Path
import math
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class WeaponViewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = (ROOT / "src/shared/Weapons.luau").read_text()
        cls.slots = source.split("\ttable.freeze({")[1:]

    def test_firearms_point_inward_from_right_hand(self):
        for slot in self.slots[:2]:
            with self.subTest(weapon=re.search(r'ModelName = "([^"]+)"', slot)[1]):
                match = re.search(
                    r"View = CFrame.new\(([^)]+)\) \* CFrame.Angles\(0, math.rad\(([^)]+)\), 0\)",
                    slot,
                )
                x, y, z = map(float, match[1].split(","))
                yaw = float(match[2])
                self.assertGreater(x, 0)
                self.assertLess(y, 0)
                self.assertLess(z, 0)
                self.assertGreater(yaw, 0, "Negative yaw points away from screen center")
                self.assertLess(yaw, 20)

    def test_rifle_muzzle_frames_near_center_at_common_aspects(self):
        slot = self.slots[0]
        origin = tuple(map(float, re.search(r"View = CFrame.new\(([^)]+)\)", slot)[1].split(",")))
        scale = tuple(map(float, re.search(r"ViewScale = Vector3.new\(([^)]+)\)", slot)[1].split(",")))
        yaw = math.radians(float(re.search(r"View = .*math.rad\(([^)]+)\)", slot)[1]))
        # Barrel tip from the stock Garand mesh (mesh bounds are not Part.Size).
        mx, my, mz = 0, 0.45 * scale[1], -3.26822 * scale[2]
        x = origin[0] + math.cos(yaw) * mx + math.sin(yaw) * mz
        y = origin[1] + my
        z = origin[2] - math.sin(yaw) * mx + math.cos(yaw) * mz
        for aspect in (4 / 3, 16 / 9):
            with self.subTest(aspect=aspect):
                half_height = -z * math.tan(math.radians(70 / 2))
                screen_x = 0.5 + x / (2 * half_height * aspect)
                screen_y = 0.5 - y / (2 * half_height)
                self.assertTrue(0.5 < screen_x < 0.6)
                self.assertTrue(0.53 < screen_y < 0.67)

    def test_hand_anchors_for_all_slots_and_support_for_rifle(self):
        self.assertEqual(len(self.slots), 4)
        for slot in self.slots:
            self.assertIn("RightHand = Vector3.new(", slot)
        self.assertIn("LeftHand = Vector3.new(", self.slots[0])
        self.assertTrue(all("LeftHand =" not in slot for slot in self.slots[1:]))


if __name__ == "__main__":
    unittest.main()
