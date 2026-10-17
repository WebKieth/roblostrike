"""Execute damage math and loot server with mocked Roblox services."""
from pathlib import Path
import test_combat
from test_player_spawn import intersects, vertical_interval
import test_player_spawn
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SurvivalTests(unittest.TestCase):
    run_luau = test_combat.CombatTests.run_luau

    def test_reference_damage_multipliers_rounding_and_armor(self):
        source = (ROOT / 'src/shared/Survival.luau').read_text()
        self.run_luau('local S = (function()\n' + source + '\nend)()\n' + r'''
assert(S.MaxHealth == 100 and S.MaxArmor == 100)
assert(S.SpareMagazines == 3 and S.LootRespawn == 60)
local names = {"Left Leg", "Right Arm", "Torso", "Head"}
for index, expected in {20, 30, 70, 150} do
    local damage, armor = S.damage(names[index], 0, false)
    assert(damage == expected and armor == 0)
    assert(S.damage(names[index], 0, false, .6) == math.round(expected * .6))
end
assert(S.damage("LeftFoot", 0, false) == 20)
assert(S.damage("RightHand", 0, false) == 30)
local damage, armor = S.damage("Torso", 100, false)
assert(damage == 35 and armor == 80)
damage, armor = S.damage("Head", 100, false)
assert(damage == 150 and armor == 100, "bare head does not wear vest")
damage, armor = S.damage("Head", 100, true)
assert(damage == 75 and armor == 80)
damage, armor = S.damage("Torso", 10, true)
assert(damage == 35 and armor == 0, "last armor hit is protected; never negative")
assert(S.damage("Torso", 0, true) == 70)
assert(S.damage("Torso", 100, true, .6) == 21)
assert(S.damage("Head", 100, true, .6) == 45)
assert(S.damage("Torso", 0, false, .61) == 43, "final damage rounded, not truncated")
assert(S.damage("Torso", 100, false, .61) == 21, "round only after armor")
for _, name in {"Left Arm", "Right Leg"} do
    local _, remaining = S.damage(name, 100, true)
    assert(remaining == 100, "unprotected limbs never wear armor")
end
''')

    def test_real_loot_server(self):
        fixture = (ROOT / 'tools/tests/fixtures/loot.luau').read_text()
        fixture = fixture.replace('-- LOOT_MODULE_HERE', (ROOT / 'src/server/Loot.luau').read_text())
        fixture = fixture.replace('-- SURVIVAL_MODULE_HERE', (ROOT / 'src/shared/Survival.luau').read_text())
        self.run_luau(fixture)

    def test_loot_and_dummy_have_room_clearance_and_floor(self):
        test_player_spawn.PlayerSpawnTests.setUpClass()
        boxes = test_player_spawn.PlayerSpawnTests.boxes
        for z in (-10, -65):
            positions = [(x, z) for x in (-25, -18, -10, 3)]
            positions += [(x, z + (4 if z == -10 else -4)) for x in (-25, -18)]
            for x, loot_z in positions:
                self.assertFalse([b[0] for b in boxes if intersects((x, .6, loot_z), (.6, .55, .6), b)])
                floors = [v[1] for b in boxes if (v := vertical_interval(x, loot_z, b)) and v[1] < .6]
                self.assertAlmostEqual(max(floors), 0, delta=.1)
        self.assertFalse([b[0] for b in boxes if intersects((-12, 2.6, 1), (1.05, 2.48, 1.05), b)])


if __name__ == '__main__':
    unittest.main()
