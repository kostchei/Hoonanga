--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[AUDIO] " .. message, 2)
	end
end

expect(AudioConfig.EngineMinPitch > 0, "EngineMinPitch must be positive")
expect(AudioConfig.EngineMaxPitch > AudioConfig.EngineMinPitch, "EngineMaxPitch must exceed EngineMinPitch")
expect(AudioConfig.Effects.Explosion ~= nil, "Explosion effect missing")

print("[AUDIO] PASS: Sound engine and audio effect configurations validated cleanly")
