"""Execute menu music lifecycle with sound and replicated-state doubles."""
from pathlib import Path
import unittest
import test_combat

ROOT = Path(__file__).resolve().parents[2]


class SessionMusicTests(unittest.TestCase):
    run_luau = test_combat.CombatTests.run_luau

    def test_music_follows_initial_setup_not_ingame_menu(self):
        module = (ROOT / 'src/client/SessionMusic.luau').read_text()
        self.run_luau('''
local Rules = { SessionMusicSoundId = "rbxassetid://123", SessionMusicVolume = 0.35 }
local sounds = {}
local SoundService = {}
local ReplicatedStorage = { Shared = { SessionRules = Rules } }
local Audio = { assign = function(sound, channel) sound.channel = channel end }
local script = { Parent = { AudioSettings = Audio } }
local function require(module) return module end
local game = { GetService = function(_, name)
    return if name == "SoundService" then SoundService else ReplicatedStorage
end }
local Instance = { new = function(class)
    assert(class == "Sound")
    local sound = { plays = 0, stops = 0 }
    function sound:Play() self.plays += 1 end
    function sound:Stop() self.stops += 1 end
    table.insert(sounds, sound)
    return sound
end }
local state = { attributes = { Phase = "WaitingAdmin", Started = false }, listeners = {} }
function state:GetAttribute(key) return self.attributes[key] end
function state:GetAttributeChangedSignal(key)
    return { Connect = function(_, callback) self.listeners[key] = callback end }
end
function state:set(key, value)
    self.attributes[key] = value
    if self.listeners[key] then self.listeners[key]() end
end
local Music = (function()
''' + module + '''
end)()
Music.start(state)
assert(#sounds == 1)
local sound = sounds[1]
assert(sound.Parent == SoundService and sound.channel == "Master")
assert(sound.Looped and sound.Volume == 0.35 and sound.SoundId == Rules.SessionMusicSoundId)
assert(sound.plays == 0)
state:set("Phase", "Lobby")
assert(sound.plays == 1)
state:set("TeamMenuOpen", false)
state:set("Phase", "Lobby")
assert(sound.plays == 1 and sound.stops == 0)
state:set("Started", true)
assert(sound.stops == 1)
state:set("Phase", "Preparing")
state:set("Phase", "Active")
state:set("TeamMenuOpen", true)
state:set("Phase", "Lobby") -- Human-only session waiting for players, not setup.
assert(sound.plays == 1 and sound.stops == 1)
state:set("Phase", "WaitingAdmin")
state:set("Started", false)
assert(sound.plays == 1)
state:set("Phase", "Lobby") -- New setup after the administrator returns.
assert(sound.plays == 2)
state:set("Phase", "Preparing") -- Also stop if phase replicates before Started.
assert(sound.stops == 2)
Rules.SessionMusicSoundId = ""
Music.start(state)
assert(#sounds == 1)
''')


if __name__ == '__main__':
    unittest.main()
