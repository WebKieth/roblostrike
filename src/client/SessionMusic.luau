--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Rules = require(ReplicatedStorage.Shared.SessionRules)
local Audio = require(script.Parent.AudioSettings)
local SessionMusic = {}

function SessionMusic.start(state: Instance)
	if Rules.SessionMusicSoundId == "" then return end
	local sound = Instance.new("Sound")
	sound.Name = "SessionSetupMusic"
	sound.SoundId, sound.Volume, sound.Looped = Rules.SessionMusicSoundId, Rules.SessionMusicVolume, true
	Audio.assign(sound, "Master")
	sound.Parent = SoundService
	local playing = false
	local function update()
		local active = state:GetAttribute("Phase") == "Lobby" and state:GetAttribute("Started") ~= true
		if active == playing then return end
		playing = active
		if active then sound:Play() else sound:Stop() end
	end
	state:GetAttributeChangedSignal("Phase"):Connect(update)
	state:GetAttributeChangedSignal("Started"):Connect(update)
	update()
end

return SessionMusic
