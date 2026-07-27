--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[AUDIO] " .. message, 2)
	end
end

expect(AudioConfig.EngineMinPitch > 0, "EngineMinPitch must be positive")
expect(
	AudioConfig.EngineMaxPitch > AudioConfig.EngineMinPitch,
	"EngineMaxPitch must exceed EngineMinPitch"
)
expect(AudioConfig.Effects.Explosion ~= nil, "Explosion effect missing")
for _, weaponId in { "MachineGun", "Pistol", "RocketLauncher", "Flamethrower", "Molotov" } do
	local effectId = AudioConfig.WeaponEffects[weaponId]
	expect(effectId ~= nil, weaponId .. " has no audio mapping")
	expect(AudioConfig.Effects[effectId] ~= nil, weaponId .. " maps to a missing effect")
	expect(AudioConfig.Effects[effectId].Subtitle ~= "", weaponId .. " has no subtitle cue")
end
expect(AudioConfig.Effects.LowFuelAlarm.Subtitle ~= "", "low fuel warning has no subtitle")
expect(AudioConfig.Effects.FireAlarm.Subtitle ~= "", "fire warning has no subtitle")

print("[AUDIO] PASS: Sound engine and audio effect configurations validated cleanly")
