"""Offline water geometry/dynamics checks; Studio is still needed for playtesting.

Numerical reference for the client formulas, not execution of the Luau controller.
"""
import math
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "src/shared/Water.luau").read_text()
SWIMMING = (ROOT / "src/client/Swimming.luau").read_text()


def setting(name):
    return float(re.search(rf"{name}\s*=\s*([\d.]+)", SOURCE)[1])


def wave(pool, x, z, time):
    x0, x1, z0, z1, y = pool
    fade = min(1, max(0, min(x-x0, x1-x, z-z0, z1-z) / setting("EdgeFade")))
    fade = fade * fade * (3 - 2 * fade)
    k = 2 * math.pi / setting("WaveLength")
    return y + fade * setting("WaveHeight") * (
        math.sin(x*k + z*k*.35 - time*2.3)
        + .4*math.sin(z*k*1.3 - x*k*.2 + time*1.8)) / 1.4


class WaterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = ET.parse(ROOT / "assets/generated/fy_pool_day.rbxmx")
        folder = next(i for i in root.iter("Item")
                      if i.findtext("Properties/string[@name='Name']") == "Water")
        cls.rectangles = []
        for item in folder.findall("Item"):
            props = item.find("Properties")
            frame = props.find("CoordinateFrame")
            size = props.find("Vector3[@name='size']")
            x, y, z = (float(frame.findtext(a)) for a in "XYZ")
            sx, sy, sz = (float(size.findtext(a)) for a in "XYZ")
            cls.rectangles.append((x-sx/2, x+sx/2, z-sz/2, z+sz/2, y+sy/2))

    def test_imported_rectangles_exactly_cover_two_pools(self):
        for bounds in ((-20, 4, -42, -26, -.5), (22, 30, -42, -34, -.5)):
            x0, x1, z0, z1, y = bounds
            parts = [p for p in self.rectangles if x0 <= p[0] < p[1] <= x1]
            self.assertTrue(parts)
            self.assertAlmostEqual(sum((p[1]-p[0])*(p[3]-p[2]) for p in parts),
                                   (x1-x0)*(z1-z0))
            for p in parts:
                self.assertTrue(z0 <= p[2] < p[3] <= z1)
                self.assertAlmostEqual(p[4], y)

    def test_waves_pin_entire_pool_boundary(self):
        pool = (-20, 4, -42, -26, -.5)
        for time in (0, .3, 2, 17):
            for t in range(101):
                x, z = -20 + 24*t/100, -42 + 16*t/100
                for px, pz in ((x, -42), (x, -26), (-20, z), (4, z)):
                    self.assertEqual(wave(pool, px, pz, time), -.5)
                self.assertLessEqual(abs(wave(pool, x, z, time) + .5), setting("WaveHeight"))

    def test_ascent_eases_and_settles_at_multiple_frame_rates(self):
        for fps in (30, 60, 144):
            y, velocity, target = -8, -8.75, -1.65
            for _ in range(fps * 5):
                dt, omega = 1/fps, 5
                velocity = (velocity + (omega*(target-y)-velocity)*omega*dt)*math.exp(-omega*dt)
                velocity = min(9, max(-9, velocity))
                y += velocity*dt
                self.assertLessEqual(y, target + .01)
            self.assertAlmostEqual(y, target, places=3)
            self.assertLess(abs(velocity), .01)

    def test_controller_source_uses_vertical_only_physics_constraint(self):
        # Source contract only: actual Humanoid/solver interaction needs Studio.
        self.assertIn('Instance.new("LinearVelocity")', SWIMMING)
        self.assertIn('controller.RelativeTo = Enum.ActuatorRelativeTo.World', SWIMMING)
        self.assertIn('controller.VelocityConstraintMode = Enum.VelocityConstraintMode.Line', SWIMMING)
        self.assertIn('controller.LineDirection = Vector3.yAxis', SWIMMING)
        self.assertIn('controller.ForceLimitsEnabled = false', SWIMMING)
        self.assertIn('verticalVelocity.LineVelocity = vy', SWIMMING)
        self.assertIn('if verticalVelocity then verticalVelocity:Destroy() end', SWIMMING)
        self.assertNotIn('Instance.new("VectorForce")', SWIMMING)

    def test_swimming_initializes_before_cosmetic_water(self):
        client = (ROOT / "src/client/init.client.luau").read_text()
        self.assertLess(client.index('require(script.Swimming).start'),
                        client.index('require(script.WaterSurface).start'))

    def test_submerged_controller_checks_held_space_each_step(self):
        # The check must remain outside the water-entry initialization branch.
        update = SWIMMING.split('humanoid.JumpPower = 0', 1)[1]
        self.assertIn('UserInputService:IsKeyDown(Enum.KeyCode.Space)', update)
        self.assertIn('UserInputService:GetFocusedTextBox() == nil', update)
        self.assertIn('rising = true', update)

    def test_exit_impulse_has_small_bounded_apex(self):
        for height in (3.5, 4.9, 5.5):
            velocity = math.sqrt(2*196.2*height)
            self.assertAlmostEqual(velocity**2/(2*196.2), height)
            self.assertLess(velocity, 47)


if __name__ == "__main__":
    unittest.main()
