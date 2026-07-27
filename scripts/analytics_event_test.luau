--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsService = require(ServerScriptService.Server.Services.AnalyticsService)
local EconomyService = require(ServerScriptService.Server.Services.EconomyService)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[ANALYTICS] " .. message, 2)
	end
end

expect(
	EconomyService.CalculatePickupBonus(nil :: any, 2) > 1.0,
	"Trailing players must receive pickup bonus"
)
expect(
	EconomyService.GetTargetAggroMultiplier(nil :: any, 1) > 1.0,
	"Lead convoy must attract higher aggro"
)
expect(
	EconomyService.CalculatePickupBonus(nil :: any, 99) <= 1.15,
	"pickup catch-up bonus exceeded its cap"
)
local credits, xp = EconomyService.ClampRunRewards(math.huge, math.huge)
expect(credits < math.huge and xp < math.huge, "run rewards were not bounded")

AnalyticsService.ClearForTest()
AnalyticsService.LogEvent({ UserId = 55 } :: any, "LaunchReadiness", {
	Value = 3,
	Platform = "Gamepad",
	Nested = { Exploit = true },
	Infinite = math.huge,
})
local events = AnalyticsService.GetLoggedEvents()
expect(#events == 1, "custom telemetry event was not buffered")
expect(events[1].EventName == "LaunchReadiness", "telemetry event name changed")
expect(events[1].Value == 3, "telemetry aggregation value was not retained")
expect(events[1].Data.Nested == nil, "nested untrusted telemetry field was retained")
expect(events[1].Data.Infinite == 0, "non-finite telemetry value was retained")

print("[ANALYTICS] PASS: Analytics transport and bounded economy rules validated cleanly")
