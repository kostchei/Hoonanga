--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PerformanceConfig = require(ReplicatedStorage.Shared.Config.PerformanceConfig)
local PerformancePolicy = require(ReplicatedStorage.Shared.PerformancePolicy)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[M6_PERFORMANCE] " .. message, 2)
	end
end

local low, recovery = PerformancePolicy.NextState(
	false,
	0,
	30,
	PerformanceConfig.EnterLowFps,
	PerformanceConfig.ExitLowFps,
	PerformanceConfig.RecoverySamples
)
expect(low and recovery == 0, "low-performance mode did not engage")

for _ = 1, PerformanceConfig.RecoverySamples - 1 do
	low, recovery = PerformancePolicy.NextState(
		low,
		recovery,
		60,
		PerformanceConfig.EnterLowFps,
		PerformanceConfig.ExitLowFps,
		PerformanceConfig.RecoverySamples
	)
	expect(low, "low-performance mode exited without hysteresis")
end
low, recovery = PerformancePolicy.NextState(
	low,
	recovery,
	60,
	PerformanceConfig.EnterLowFps,
	PerformanceConfig.ExitLowFps,
	PerformanceConfig.RecoverySamples
)
expect(not low and recovery == 0, "low-performance mode did not recover")
expect(PerformanceConfig.Budgets.MaxActiveChunks >= 21, "chunk budget is below initial road")
expect(
	PerformanceConfig.Budgets.MaxCombatVehiclesM6 >= 12,
	"vehicle budget is below M6 stress target"
)

print("[M6_PERFORMANCE] PASS: adaptive performance policy and budgets are valid")
