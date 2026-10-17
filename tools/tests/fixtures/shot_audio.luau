-- Execute the real audio effect with small Roblox object/service stubs.
local created, cleanup = {}, {}
local Instance = {new = function(class)
	local object = {ClassName=class, Parent=nil}
	function object:Destroy() self.Parent = nil; self.destroyed = true end
	if class == "Sound" then
		object.Ended = {Once=function(_, callback) object.finish = callback end}
		function object:Play() self.played = true end
	end
	table.insert(created, object)
	return object
end}
local game = {GetService=function(_, name)
	if name == "Debris" then return {AddItem=function(_, object, lifetime) cleanup[object] = lifetime end} end
	return {}
end}
local workspace = {}
local Random = {new=function() return {} end}
local Vector3 = {new=function(...) return {...} end}
local CFrame = {new=function(...) return {...} end}
local Color3 = {new=function(...) return {...} end}
local Enum = {Material={SmoothPlastic=1}, RollOffMode={InverseTapered=2}}
local Effects = (function()
-- EFFECTS_MODULE_HERE
end)()
local definition = {ShotSound="rbxassetid://123", ShotVolume=.65, ShotPlaybackSpeed=1.1}
local function shot()
	Effects.sound({0,0,0}, definition)
	return created[#created-1], created[#created]
end
local emitter, sound = shot()
assert(sound.ClassName == "Sound" and sound.Parent == emitter and sound.played)
assert(sound.SoundId == definition.ShotSound and sound.Volume == .65 and sound.PlaybackSpeed == 1.1)
assert(emitter.Transparency == 1 and not emitter.CanCollide and not emitter.CanQuery)
assert(sound.RollOffMode == 2 and sound.RollOffMinDistance == 8 and sound.RollOffMaxDistance == 180)
assert(cleanup[emitter] == 5, "unloaded audio must still be cleaned up")
local nextEmitter, nextSound = shot()
assert(nextSound ~= sound and not emitter.destroyed, "rapid shots overlap")
sound.finish()
assert(emitter.destroyed, "finished audio emitter cleaned up")
for i = 1, 40 do shot() end
assert(nextEmitter.destroyed, "concurrent audio bounded to 32 emitters")
local before = #created
Effects.sound({}, {})
assert(#created == before, "weapons without shot audio are ignored")
print("Shot audio: playback, overlap, spatial falloff, cleanup and bounds OK")
