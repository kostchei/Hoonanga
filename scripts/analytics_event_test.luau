--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsService = require(ServerScriptService.Server.Services.AnalyticsService)
local EconomyService = require(ServerScriptService.Server.Services.EconomyService)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[ANALYTICS] " .. message, 2)
	end
end

expect(EconomyService.CalculatePickupBonus(nil :: any, 2) > 1.0, "Trailing players must receive pickup bonus")
expect(EconomyService.GetTargetAggroMultiplier(nil :: any, 1) > 1.0, "Lead convoy must attract higher aggro")

print("[ANALYTICS] PASS: Analytics and economy balancing rules validated cleanly")
