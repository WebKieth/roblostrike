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
        yaw = math.radians(float(re.search(r"View = .*math.rad\(([^)]+)\)", slot)[1]))
        # Locally authored M4A1 bore, not the removed catalog Garand mesh.
        mx, my, mz = map(float, re.search(r"Muzzle = Vector3.new\(([^)]+)\)", slot)[1].split(","))
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

    def test_ads_sight_line_is_centered(self):
        for slot in self.slots[:2]:
            height = float(re.search(r"SightHeight = ([\d.]+)", slot)[1])
            x, y, z = map(float, re.search(r"ADS = CFrame.new\(([^)]+)\)", slot)[1].split(","))
            self.assertEqual(x, 0)
            self.assertAlmostEqual(y + height, 0)
            self.assertLess(z, -0.5)

    def test_world_firearms_do_not_rotate_the_forward_bore_up(self):
        for slot in self.slots[:2]:
            grip = re.search(r'Grip = ([^\n]+)', slot)[1]
            self.assertNotIn('Angles', grip)
            self.assertIn('Muzzle = Vector3.new(0, 0, -', slot)

    def test_firearms_use_local_models(self):
        self.assertIn('ModelName = "M4A1"', self.slots[0])
        self.assertIn('ModelName = "Glock 17"', self.slots[1])
        self.assertIn('Magazine = 17', self.slots[1])
        self.assertIn('Automatic = true', self.slots[0])
        self.assertIn('Automatic = false', self.slots[1])
        self.assertIn('SpreadMultiplier = 0.8', self.slots[0])
        self.assertIn('SpreadMultiplier = 0.5', self.slots[1])
        self.assertNotIn('9535', self.slots[1])
        self.assertNotIn('94287666', self.slots[0])
        for slot in self.slots[:2]:
            self.assertIn('Procedural = true', slot)

    def test_hand_anchors_for_all_slots_and_support_for_rifle(self):
        self.assertEqual(len(self.slots), 7)  # Grenades share key 4; rifles share key 1.
        for slot in self.slots:
            self.assertIn("RightHand = Vector3.new(", slot)
        self.assertIn("LeftHand = Vector3.new(", self.slots[0])
        self.assertTrue(all("LeftHand =" not in slot for slot in self.slots[1:5]))
        for slot in self.slots[5:]:
            self.assertIn("LeftHand =", slot)
            self.assertIn("HotbarSlot = 1", slot)

    def test_new_weapon_balance(self):
        self.assertIn("DamageMultiplier = 0.9", self.slots[0])
        for slot, name, damage, spread, magazine in (
            (self.slots[5], "AK-47", "1", "1", 30),
            (self.slots[6], "M249", "1.2", "1.2", 100),
        ):
            self.assertIn(f'ModelName = "{name}"', slot)
            self.assertIn(f"DamageMultiplier = {damage},", slot)
            self.assertIn(f"SpreadMultiplier = {spread},", slot)
            self.assertIn(f"Magazine = {magazine},", slot)
            self.assertIn("Procedural = true", slot)
            self.assertIn("Automatic = true", slot)


if __name__ == "__main__":
    unittest.main()
