--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnvironmentConfig = require(ReplicatedStorage.Shared.Config.EnvironmentConfig)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[ENVIRONMENT] " .. message, 2)
	end
end

expect(EnvironmentConfig.Biomes.BoulderPlain ~= nil, "BoulderPlain biome missing")
expect(EnvironmentConfig.Biomes.SandyDesert ~= nil, "SandyDesert biome missing")
expect(EnvironmentConfig.Biomes.Canyon ~= nil, "Canyon biome missing")
expect(EnvironmentConfig.Biomes.Mudflats ~= nil, "Mudflats biome missing")
expect(EnvironmentConfig.Biomes.RaisedHighway ~= nil, "RaisedHighway biome missing")

print("[ENVIRONMENT] PASS: Environment biome profiles validated cleanly")
