"""Source contracts plus execution of the real Ballistics module with Luau.

Only Vector2's two numeric components are stubbed in the standalone runtime.
Roblox rendering, remotes and hit detection still need Studio integration tests.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class CombatTests(unittest.TestCase):
    def run_luau(self, script):
        local = ROOT / '.tools/luau/luau'
        runner = str(local) if local.exists() else shutil.which('luau')
        if not runner:
            self.skipTest('Standalone Luau is optional; install it to execute math tests')
        with tempfile.TemporaryDirectory(prefix='robostrike-combat-') as directory:
            path = Path(directory) / 'combat.luau'
            path.write_text(script)
            result = subprocess.run([runner, str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_one_visible_direction_and_no_hidden_cone(self):
        client = (ROOT / 'src/client/Combat.luau').read_text()
        server = (ROOT / 'src/server/Combat.luau').read_text()
        view = (ROOT / 'src/client/Viewmodel.luau').read_text()
        self.assertIn('camera:WorldToViewportPoint(target)', client)
        self.assertIn('local direction = weaponFrame.LookVector', client)
        self.assertIn('workspace:Raycast(muzzle, direction * definition.Range, filter)', client)
        self.assertIn('fire:FireServer(muzzle - head.Position, direction)', client)
        self.assertIn('workspace:Raycast(muzzle, direction * definition.Range, params)', server)
        self.assertIn('weaponFrame = combat.WeaponFrame or weaponFrame', view)
        self.assertIn('state.WeaponFrame = if definition and definition.FireInterval then state.Aim * definition.View else nil', client)
        self.assertIn('WeaponFrame = nil :: CFrame?', client)
        self.assertNotIn('CFrame.lookAt(sightOrigin, target', view)
        self.assertNotIn('muzzle = state.Muzzle or muzzle', client)
        self.assertLess(client.index('state.WeaponFrame, state.Muzzle ='), client.index('fire:FireServer('))
        self.assertLess(client.index('dispersion = Ballistics.dispersion('), client.index('local aim = state.Aim'))
        self.assertIn('Ballistics.spreadScale(definition.SpreadMultiplier, state.ADS, character:GetAttribute("Crouching") == true)', client)
        self.assertIn('dispersion * dispersionWeight) * spreadScale', client)
        self.assertNotIn('impulse *= 0.65', client)
        self.assertNotIn('Random', server)

    def test_server_owns_damage_ammo_rate_and_cover(self):
        server = (ROOT / 'src/server/Combat.luau').read_text()
        for guard in ('finiteVector(muzzleOffset)', 'finiteVector(direction)',
                      'muzzleOffset.Magnitude > Ballistics.MaxMuzzleOffset',
                      'now < due - 0.025', 'tool:GetAttribute("Reloading")',
                      'tool:SetAttribute("Ammo", ammo - 1)', 'victim:TakeDamage',
                      'workspace:Raycast(head.Position, muzzle - head.Position, params)'):
            self.assertIn(guard, server)

    def test_camera_follow_is_applied_after_mouse_and_removed_before_next_frame(self):
        client = (ROOT / 'src/client/Combat.luau').read_text()
        self.assertIn('Enum.RenderPriority.Camera.Value - 1', client)
        self.assertIn('recoilCamera.CFrame *= cameraRotation:Inverse()', client)
        self.assertIn('Enum.RenderPriority.Camera.Value + 1', client)
        self.assertIn('Ballistics.recoilWeight(age, definition.FireInterval)', client)
        self.assertIn('Ballistics.elevation(basePitch, offset.Y)', client)
        self.assertLess(client.index('camera.CFrame *= cameraRotation'), client.index('local aim = state.Aim'))

    def test_pistol_trigger_and_audio_are_wired_to_actual_shots(self):
        client = (ROOT / 'src/client/Combat.luau').read_text()
        self.assertIn('if pressed and not held then held, queued = true, true', client)
        self.assertIn('Ballistics.trigger(definition.Automatic == true, held, queued)', client)
        shot = client[client.index('if shooting then', client.index('status.TextSize = 15')):]
        for action in ('queued = false', 'Ballistics.nextShot(', 'fire:FireServer(',
                       'Effects.sound(muzzle, definition)', 'carry = recoil', 'Ballistics.kick('):
            self.assertIn(action, shot)
        effect = client[client.index('effects.OnClientEvent:Connect'):client.index('-- Remove only our presentation')]
        own, other = effect.split('\n\t\telse', 1)
        self.assertNotIn('Effects.sound', own, 'server echo must not double local audio')
        self.assertIn('Effects.sound(muzzleFrame.Position, definition)', other)

    def test_real_shot_audio_lifecycle(self):
        fixture = (ROOT / 'tools/tests/fixtures/shot_audio.luau').read_text()
        source = (ROOT / 'src/client/ShotEffects.luau').read_text()
        self.run_luau(fixture.replace('-- EFFECTS_MODULE_HERE', source))

    def test_material_effects_are_cosmetic_and_bounded(self):
        source = (ROOT / 'src/client/ShotEffects.luau').read_text()
        for material in ('Metal', 'Wood', 'Glass', 'Water'):
            self.assertIn('Enum.Material.' + material, source)
        self.assertIn('#marks > 100', source)
        self.assertIn('p.CanCollide, p.CanTouch, p.CanQuery = false, false, false', source)
        self.assertIn('Debris:AddItem', source)

    def test_remote_shots_use_world_weapon_muzzle(self):
        client = (ROOT / 'src/client/Combat.luau').read_text()
        self.assertIn('Effects.worldFlash(character, slot, definition, muzzle, direction)', client)
        self.assertIn('Effects.tracer(muzzleFrame.Position, target)', client)
        server = (ROOT / 'src/server/Combat.luau').read_text()
        bots = (ROOT / 'src/server/Bots.luau').read_text()
        self.assertIn('victim ~= nil, character)', server)
        self.assertIn('victim ~= nil, model)', bots)

    def test_real_luau_first_shot_dispersion_bounds_and_weapon_ads_scaling(self):
        source = (ROOT / 'src/shared/Ballistics.luau').read_text()
        self.run_luau(r'''
local mt = { __mul = function(a, b) return { X = a.X * b, Y = a.Y * b } end }
local Vector2 = { new = function(x, y) return setmetatable({X=x, Y=y}, mt) end }
local B = (function()
''' + source + r'''
end)()
local function near(a, b) assert(math.abs(a - b) < 1e-10) end
near(B.spreadScale(1, 0), 1)
near(B.spreadScale(.8, 0), .8)
near(B.spreadScale(.8, 1), .4)
near(B.spreadScale(.5, 0), .5)
near(B.spreadScale(.5, 1), .25)
near(B.spreadScale(1, .5), .75)
near(B.spreadScale(2, 0, false), 2)
near(B.spreadScale(2, 1, false), 1)
near(B.spreadScale(2, 0, true), 1.6)
near(B.spreadScale(2, 1, true), .8)
for _, multiplier in {.5, .8, 1, 2} do
    for _, ads in {0, .5, 1} do
        near(B.spreadScale(multiplier, ads, true), B.spreadScale(multiplier, ads, false) * .8)
    end
end
local first = B.dispersion(1, math.huge, .5, .125)
assert(first.X ~= 0 and first.Y ~= 0, "first shot after complete recovery is already random")
local other = B.dispersion(1, math.huge, .5, .625)
assert(first.X * other.X < 0 and first.Y * other.Y < 0, "fresh sample changes direction")
for _, interval in {math.huge, 1, .18, .0857} do
    local sumX, sumY, radiusSquared = 0, 0, 0
    local reference = B.kick(1, interval, 1)
    local boundSquared = reference.X^2 + reference.Y^2
    for radial = 0, 19 do
        for angular = 0, 19 do
            local offset = B.dispersion(1, interval, (radial + .5) / 20, angular / 20)
            local squared = offset.X^2 + offset.Y^2
            assert(squared > 0 and squared <= boundSquared + 1e-12, "bounded by current recoil strength")
            sumX += offset.X; sumY += offset.Y; radiusSquared += squared
            for _, multiplier in {.5, .8, 1, 2} do
                local hip = offset * B.spreadScale(multiplier, 0)
                local ads = offset * B.spreadScale(multiplier, 1)
                near(ads.X, hip.X * .5); near(ads.Y, hip.Y * .5)
                local crouched = offset * B.spreadScale(multiplier, 0, true)
                local crouchedADS = offset * B.spreadScale(multiplier, 1, true)
                near(crouched.X, hip.X * .8); near(crouched.Y, hip.Y * .8)
                near(crouchedADS.X, ads.X * .8); near(crouchedADS.Y, ads.Y * .8)
            end
        end
    end
    near(sumX, 0); near(sumY, 0)
    near(radiusSquared / 400, boundSquared * .5) -- uniform disk, no square/outlier tails
end
assert(B.dispersion(1, .0857, 1, 0).X > B.dispersion(1, 1, 1, 0).X, "rapid fire widens by the same recoil algorithm")
print("Dispersion: first shot, uniform bounds, cadence and exact weapon/ADS scales OK")
''')

    def test_real_luau_recovery_pattern_sway_and_cadence(self):
        source = (ROOT / 'src/shared/Ballistics.luau').read_text()
        script = r'''
local mt = { __mul = function(a, b) return { X = a.X * b, Y = a.Y * b } end }
local Vector2 = { new = function(x, y) return setmetatable({X=x, Y=y}, mt) end }
local B = (function()
''' + source + r'''
end)()
assert(B.Recovery == 0.5)
assert(B.recovery(0) == 1)
assert(B.recovery(0.499) > 0)
assert(B.recovery(0.5) == 0)
assert(B.recovery(10) == 0)
for fps = 30, 240, 30 do
    local previous = 1
    for frame = 0, fps do
        local weight = B.recovery(frame / fps)
        assert(weight <= previous and weight >= 0)
        previous = weight
    end
    local count, due = 0, 0
    for frame = 0, fps * 10 - 1 do
        local now = frame / fps
        if now >= due then
            count += 1
            due = B.nextShot(now, due, 0.0857, 1 / fps)
        end
    end
    assert(math.abs(count - 10 / 0.0857) < 2, tostring(fps) .. ": bad cadence " .. count)
end
assert(B.nextShot(20, 0, .0857, 1/60) == 20 + .0857, "idle cannot bank shots")
for _, automatic in {false, true} do
    local queued, shots = true, 0
    for frame = 1, 100 do
        if B.trigger(automatic, true, queued) then
            shots += 1
            queued = false
        end
    end
    assert(shots == (if automatic then 100 else 1), "held pistol fires only once")
    assert(not B.trigger(automatic, false, false), "release stops firing")
    assert(B.trigger(automatic, false, true), "short click survives between frames")
end
-- Separate rapid pistol taps use the same accumulator/cadence as automatic fire.
local pistolRecoil, previous = 0, 0
for tap = 1, 17 do
    assert(B.trigger(false, true, true), "each new press can fire")
    assert(not B.trigger(false, true, false), "consumed press cannot repeat")
    pistolRecoil = pistolRecoil * B.recoilWeight(.18, .18) + B.kick(tap, .18, 1.35).Y
    assert(pistolRecoil > previous, "rapid taps accumulate recoil")
    previous = pistolRecoil
end
assert(pistolRecoil > B.CameraFollowAngle, "rapid pistol taps engage camera follow")
local positive, negative = false, false
for i = 1, 40 do
    local fast, slow = B.kick(i, .0857, 1), B.kick(i, .49, 1)
    assert(fast.Y > slow.Y and slow.Y > 0)
    positive = positive or fast.X > 0
    negative = negative or fast.X < 0
end
assert(positive and negative, "both horizontal directions")
assert(math.abs(B.kick(1, .5, 1).Y - math.rad(.48 * 3)) < 1e-9, "triple recoil")
assert(math.abs(B.sway(math.pi/2, 1, 0).X - math.rad(.85 * 3)) < 1e-9, "triple running sway")
-- A sustained burst must accumulate, not settle at a geometric equilibrium.
for fps = 30, 240, 30 do
    local interval, carry, impulse, lastShot, due = .0857, 0, 0, -math.huge, 0
    local previous, shots, highestCamera = 0, 0, 0
    for frame = 0, fps * 8 do
        local now = frame / fps
        local age = now - lastShot
        local rise = math.clamp(age / .035, 0, 1)
        rise = rise * rise * (3 - 2 * rise)
        local recoil = (carry + impulse * rise) * B.recoilWeight(age, interval)
        local pitch, lift = B.elevation(0, recoil)
        assert(pitch <= math.pi/2 and lift >= 0)
        assert(pitch - lift <= B.CameraFollowAngle + 1e-9, "reticle stays within camera follow threshold")
        highestCamera = math.max(highestCamera, lift)
        if now >= due then
            if shots > 0 then assert(recoil > previous, "burst must keep climbing at " .. fps .. " FPS") end
            previous = recoil
            carry = recoil
            impulse = B.kick(shots + 1, now - lastShot, 1).Y
            lastShot = now
            due = B.nextShot(now, due, interval, 1/fps)
            shots += 1
        end
    end
    assert(previous > math.pi/2, "accumulation can reach zenith")
    assert(math.abs(highestCamera + B.CameraFollowAngle - math.pi/2) < 1e-9, "camera follows to zenith")
end
assert(B.recoilWeight(.0857, .0857) == 1, "no decay between automatic shots")
assert(B.recoilWeight(.5, .0857) == 0, "burst recovery still ends at .5s")
assert(B.recoilWeight(.4, .0857) > 0, "smooth release recovery")
local pitch, lift = B.elevation(0, math.rad(4))
assert(math.abs(pitch - math.rad(4)) < 1e-9 and lift == 0, "initial recoil moves only gun")
pitch, lift = B.elevation(0, math.rad(20))
assert(math.abs(lift - math.rad(14)) < 1e-9, "excess recoil moves camera")
local compensated = B.elevation(math.rad(-10), math.rad(20))
assert(math.abs(compensated - math.rad(10)) < 1e-9, "mouse can compensate camera recoil")
for phase = 0, 20, .1 do
    local standing = B.sway(phase, 0, 0)
    local running, walking = B.sway(phase, 1, 0), B.sway(phase, .45, 0)
    local ads = B.sway(phase, 1, 1)
    assert(standing.X == 0 and standing.Y == 0)
    assert(running.Y <= 0, "wave comes from below the center")
    assert(math.abs(walking.X) <= math.abs(running.X))
    assert(math.abs(ads.X) <= math.abs(running.X))
end
-- ADS sight height cancels translation; recoil/reticle rays remain identical.
print("Ballistics: recovery, pattern, cadence, movement and sustained camera recoil OK")
'''
        self.run_luau(script)

    def test_real_server_handlers_with_mocked_roblox_services(self):
        fixture = (ROOT / 'tools/tests/fixtures/combat_server.luau').read_text()
        server = (ROOT / 'src/server/Combat.luau').read_text()
        survival = (ROOT / 'src/shared/Survival.luau').read_text()
        self.run_luau(fixture.replace('-- SERVER_MODULE_HERE', server).replace('-- SURVIVAL_MODULE_HERE', survival)
                      .replace('-- SESSION_RULES_HERE', (ROOT / 'src/shared/SessionRules.luau').read_text()))

    def test_loadout_recovers_after_engine_replaces_backpack(self):
        fixture = (ROOT / 'tools/tests/fixtures/loadout.luau').read_text()
        for marker, path in (
            ('-- WEAPONS_MODULE_HERE', 'src/shared/Weapons.luau'),
            ('-- GUN_MODULE_HERE', 'src/shared/GunModel.luau'),
            ('-- LOADOUT_MODULE_HERE', 'src/server/Loadout.luau'),
        ):
            fixture = fixture.replace(marker, (ROOT / path).read_text())
        self.run_luau(fixture)


if __name__ == '__main__':
    unittest.main()
