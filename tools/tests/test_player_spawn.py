"""Offline regression checks against actual imported collision geometry.

Not a replacement for Studio Play: checks room clearance, floor and ceiling
at the configured R6 spawn, without requiring the original local BSP.
"""
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
AXES = ((1, 0, 0), (0, 1, 0), (0, 0, 1))


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def intersects(center, half_size, box):
    """AABB vs oriented part bounds, using the 15 separating axes."""
    _, position, axes, half = box
    delta = tuple(p - c for p, c in zip(position, center))
    for axis in (*AXES, *axes, *(cross(a, b) for a in AXES for b in axes)):
        extent_a = sum(s * abs(dot(a, axis)) for s, a in zip(half_size, AXES))
        extent_b = sum(s * abs(dot(a, axis)) for s, a in zip(half, axes))
        if abs(dot(delta, axis)) > extent_a + extent_b + 1e-6:
            return False
    return True


def vertical_interval(x, z, box):
    """Y interval of a vertical line inside an oriented part's bounds."""
    _, position, axes, half = box
    delta = (x - position[0], -position[1], z - position[2])
    low, high = -float("inf"), float("inf")
    for axis, radius in zip(axes, half):
        origin = dot(delta, axis)
        direction = axis[1]
        if abs(direction) < 1e-7:
            if abs(origin) > radius + 1e-6:
                return None
        else:
            a, b = sorted(((-radius - origin) / direction, (radius - origin) / direction))
            low, high = max(low, a), min(high, b)
            if low > high + 1e-6:
                return None
    return low, high


class PlayerSpawnTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        config = (ROOT / "src/shared/Config.luau").read_text()
        match = re.search(r"SpawnCFrame\s*=\s*CFrame.new\(([^)]+)\)", config)
        cls.spawn = tuple(float(n.strip()) for n in match[1].split(","))
        cls.boxes = []
        for item in ET.parse(ROOT / "assets/generated/fy_pool_day.rbxmx").iter("Item"):
            if item.get("class") not in {"Part", "WedgePart"}:
                continue
            props = item.find("Properties")
            if props.find("bool[@name='CanCollide']").text != "true":
                continue
            frame = props.find("CoordinateFrame")
            position = tuple(float(frame.find(k).text) for k in "XYZ")
            axes = tuple(tuple(float(frame.find(f"R{r}{c}").text) for r in range(3)) for c in range(3))
            size = props.find("Vector3[@name='size']")
            half = tuple(float(size.find(k).text) / 2 for k in "XYZ")
            cls.boxes.append((props.find("string[@name='Name']").text, position, axes, half))

    def test_r6_body_has_clearance_inside_room(self):
        x, y, z = self.spawn
        # Standard R6: feet=root-3, head top=root+2; small floor margin.
        center = (x, y - 0.5, z)
        collisions = [box[0] for box in self.boxes if intersects(center, (1.05, 2.48, 1.05), box)]
        self.assertEqual(collisions, [], "Spawn body intersects map collision bounds")

    def test_floor_and_roof_at_entire_spawn_footprint(self):
        x, y, z = self.spawn
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                with self.subTest(dx=dx, dz=dz):
                    intervals = [v for box in self.boxes if (v := vertical_interval(x + dx, z + dz, box))]
                    floor = max(hi for lo, hi in intervals if hi < y - 2.9)
                    ceiling = min(lo for lo, hi in intervals if lo > y + 2)
                    self.assertAlmostEqual(floor, 0, delta=0.1)
                    self.assertAlmostEqual(ceiling, 10, delta=0.1)
                    self.assertLess(y + 2, ceiling, "Spawn must be BELOW room roof")


if __name__ == "__main__":
    unittest.main()
