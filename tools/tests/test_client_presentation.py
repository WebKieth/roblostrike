"""Execute client-side state/cleanup with doubles; rendering still needs Studio."""
from pathlib import Path
import unittest
import test_combat

ROOT = Path(__file__).resolve().parents[2]


class ClientPresentationTests(unittest.TestCase):
    run_luau = test_combat.CombatTests.run_luau

    def test_procedural_character_movement_and_cleanup(self):
        fixture = (ROOT / 'tools/tests/fixtures/character_animation.luau').read_text()
        source = (ROOT / 'src/client/CharacterAnimation.luau').read_text()
        self.run_luau(fixture.replace('-- ANIMATION_MODULE_HERE', source))

    def test_mac_crouch_keys_and_observer_animation(self):
        source = (ROOT / 'src/client/init.client.luau').read_text()
        self.assertIn('Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl)', source)
        self.assertIn('crouching = next(crouchKeys) ~= nil', source)
        self.assertIn('table.clear(crouchKeys)', source)
        self.assertIn('Players.PlayerAdded:Connect(watchAnimations)', source)
        self.assertIn('other.CharacterAdded:Connect(start)', source)

    def test_freeze_and_menus_reset_movement_controller(self):
        fixture = (ROOT / 'tools/tests/fixtures/movement_input.luau').read_text()
        source = (ROOT / 'src/client/MovementInput.luau').read_text()
        self.run_luau(fixture.replace('-- MOVEMENT_INPUT_MODULE_HERE', source))

    def test_sound_settings_and_first_person_visibility(self):
        fixture = (ROOT / 'tools/tests/fixtures/client_settings.luau').read_text()
        for marker, path in (
            ('-- AUDIO_MODULE_HERE', 'src/client/AudioSettings.luau'),
            ('-- SETTINGS_MODULE_HERE', 'src/client/SettingsUI.luau'),
            ('-- VISIBILITY_MODULE_HERE', 'src/client/FirstPersonVisibility.luau'),
            ('-- RULES_MODULE_HERE', 'src/shared/SessionRules.luau'),
            ('-- SESSION_HUD_MODULE_HERE', 'src/client/SessionHUD.luau'),
        ):
            fixture = fixture.replace(marker, (ROOT / path).read_text())
        self.run_luau(fixture)

    def test_death_volume_and_menu_guards(self):
        session = (ROOT / 'src/client/SessionHUD.luau').read_text()
        self.assertIn('Rules.WilhelmSoundId, 0.64, 110', session)
        self.assertIn('Audio.assign(sound, "Characters")', session)
        for name in ('Combat', 'Knife', 'Grenades'):
            source = (ROOT / f'src/client/{name}.luau').read_text()
            self.assertIn('player:GetAttribute("SettingsOpen")', source)
            self.assertIn('GetAttributeChangedSignal("SettingsOpen")', source)
            self.assertIn('player:GetAttribute("HUDCursorFree")', source)
            self.assertIn('GetAttributeChangedSignal("HUDCursorFree")', source)


if __name__ == '__main__':
    unittest.main()
