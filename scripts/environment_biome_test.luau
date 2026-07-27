--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnvironmentConfig = require(ReplicatedStorage.Shared.Config.EnvironmentConfig)
local RoadContentConfig = require(ReplicatedStorage.Shared.Config.RoadContentConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[ENVIRONMENT] " .. message, 2)
	end
end

expect(EnvironmentConfig.Biomes.BoulderPlain ~= nil, "BoulderPlain biome missing")
expect(EnvironmentConfig.Biomes.SandyDesert ~= nil, "SandyDesert biome missing")
expect(EnvironmentConfig.Biomes.Canyon ~= nil, "Canyon biome missing")
expect(EnvironmentConfig.Biomes.Mudflat ~= nil, "Mudflat biome missing")
expect(EnvironmentConfig.Biomes.RaisedHighway ~= nil, "RaisedHighway biome missing")

for familyId in EnvironmentConfig.Biomes do
	local variants = RoadContentConfig.Families[familyId]
	expect(variants ~= nil, familyId .. " has no content library")
	local normal = 0
	local hazard = 0
	local transition = 0
	for _, variant in variants do
		if variant.Kind == "Normal" then
			normal += 1
		elseif variant.Kind == "Hazard" then
			hazard += 1
		elseif variant.Kind == "Transition" then
			transition += 1
		end
	end
	expect(normal >= 4, familyId .. " needs at least four normal variants")
	expect(hazard >= 2, familyId .. " needs at least two hazard variants")
	expect(transition >= 2, familyId .. " needs entry and exit transitions")
end
expect(#RoadContentConfig.ForkSets >= 4, "initial release needs at least four fork sets")
local upgradeCount = 0
for _ in UpgradeConfig.Upgrades do
	upgradeCount += 1
end
expect(upgradeCount >= 8 and upgradeCount <= 12, "temporary upgrade count must be 8-12")

print("[ENVIRONMENT] PASS: Environment biome profiles validated cleanly")
