--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local UpgradeService = require(ServerScriptService.Server.Services.UpgradeService)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[M5_UPGRADE] " .. message, 2)
	end
end

local first = UpgradeService.BuildRandomOfferForTest(3, 5505)
local repeated = UpgradeService.BuildRandomOfferForTest(3, 5505)
expect(#first == 3, "server offer does not contain three choices")
expect(table.concat(first, ",") == table.concat(repeated, ","), "offer seed is not deterministic")

local seen: { [string]: boolean } = {}
for _, upgradeId in first do
	expect(UpgradeConfig.Upgrades[upgradeId] ~= nil, "offer contains an unknown upgrade")
	expect(not seen[upgradeId], "offer contains a duplicate upgrade")
	seen[upgradeId] = true
end

local capped = UpgradeService.BuildRandomOfferForTest(100, 7)
local available = 0
for _ in UpgradeConfig.Upgrades do
	available += 1
end
expect(#capped == available, "oversized offer was not capped to available upgrades")

print("[M5_UPGRADE] PASS: server-generated temporary upgrade offers are valid")
