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
        self.assertEqual(len(self.slots), 8)  # Grenades share key 4; rifles share key 1.
        for slot in self.slots:
            self.assertIn("RightHand = Vector3.new(", slot)
        self.assertIn("LeftHand = Vector3.new(", self.slots[0])
        self.assertIn("LeftHand = Vector3.new(", self.slots[1])  # Two-handed pistol grip.
        self.assertTrue(all("LeftHand =" not in slot for slot in self.slots[2:5]))
        for slot in self.slots[5:]:
            self.assertIn("LeftHand =", slot)
            self.assertIn("HotbarSlot = 1", slot)

    def test_new_weapon_balance(self):
        self.assertIn("DamageMultiplier = 0.9", self.slots[0])
        for slot, name, damage, spread, magazine in (
            (self.slots[5], "AK-47", "1", "1", 30),
            (self.slots[6], "M249", "1.2", "2", 100),
        ):
            self.assertIn(f'ModelName = "{name}"', slot)
            self.assertIn(f"DamageMultiplier = {damage},", slot)
            self.assertIn(f"SpreadMultiplier = {spread},", slot)
            self.assertIn(f"Magazine = {magazine},", slot)
            self.assertIn("Procedural = true", slot)
            self.assertIn("Automatic = true", slot)

    def test_ak_rear_sight_is_supported_flat_plate_with_v_notch(self):
        source = (ROOT / 'src/shared/GunModel.luau').read_text()
        ak = source.split('elseif slot == 6 then', 1)[1].split('elseif slot == 7 then', 1)[0]

        def geometry(name):
            match = re.search(
                rf'block\("{name}", Vector3.new\(([^)]+)\),\s*CFrame.new\(([^)]+)\)', ak)
            self.assertIsNotNone(match)
            size = tuple(map(float, match[1].split(',')))
            position = tuple(map(float, match[2].split(',')))
            return size, position

        receiver, receiver_pos = geometry('AKReceiver')
        support, support_pos = geometry('AKSightBlock')
        leaf, leaf_pos = geometry('AKSightLeaf')
        self.assertLessEqual(support_pos[1] - support[1] / 2, receiver_pos[1] + receiver[1] / 2)
        self.assertLess(support_pos[2] + support[2] / 2, receiver_pos[2] + receiver[2] / 2)
        self.assertGreater(support_pos[2] + support[2] / 2, receiver_pos[2] - receiver[2] / 2)
        self.assertAlmostEqual(support_pos[1] + support[1] / 2, leaf_pos[1] - leaf[1] / 2)
        self.assertNotIn('RearSightWing', ak)
        self.assertIn('wedge.MeshType = Enum.MeshType.Wedge', ak)
        self.assertIn('CFrame.Angles(0, side * math.pi / 2, 0)', ak)
        plate = re.search(r'block\("AKRearSightPlate", Vector3.new\(([^)]+)\), CFrame.new\(side \* ([\d.]+), ([\d.]+),', ak)
        width, height, depth = map(float, plate[1].split(','))
        x, y = map(float, plate.group(2, 3))
        notch = re.search(r'block\("AKRearSightNotch", Vector3.new\(([^)]+)\),\s*CFrame.new\(side \* ([\d.]+), ([\d.]+),', ak)
        notch_depth, notch_height, notch_width = map(float, notch[1].split(','))
        notch_x, notch_y = map(float, notch.group(2, 3))
        self.assertLess(height, width)
        self.assertAlmostEqual(y - height / 2, leaf_pos[1] + leaf[1] / 2)
        self.assertAlmostEqual(notch_x - notch_width / 2, 0)
        self.assertAlmostEqual(notch_x + notch_width / 2, x - width / 2)
        self.assertAlmostEqual(notch_y, y)
        self.assertAlmostEqual(notch_height, height)
        self.assertAlmostEqual(notch_depth, depth)
        post, post_pos = geometry('FrontSightPost')
        self.assertAlmostEqual(y + height / 2, post_pos[1] + post[1] / 2)

    def test_awp_scope_magazine_and_manual_cycle(self):
        slot = self.slots[7]
        for contract in ('ModelName = "AWP"', 'Magazine = 5,', 'HotbarSlot = 1,',
                         'PickupOnly = true,', 'Automatic = false,',
                         'DamageMultiplier = 3,', 'ScopeMagnifications = table.freeze({ 8, 4, 1.5 })'):
            self.assertIn(contract, slot)
        interval = float(re.search(r'FireInterval = ([\d.]+)', slot)[1])
        cycle = float(re.search(r'BoltCycle = ([\d.]+)', slot)[1])
        self.assertGreaterEqual(interval, cycle)
        client = (ROOT / 'src/client/Combat.luau').read_text()
        self.assertIn('Enum.UserInputType.MouseButton3', client)
        self.assertIn('active and not definition.ScopeMagnifications', client)
        server = (ROOT / 'src/server/Combat.luau').read_text()
        self.assertEqual(server.count('workspace:GetServerTimeNow() - shotTime < definition.BoltCycle'), 2)


if __name__ == "__main__":
    unittest.main()
