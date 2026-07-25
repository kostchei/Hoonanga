local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ConvoyConfig = require(ReplicatedStorage.Shared.Config.ConvoyConfig)
local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
local RoadService = require(ServerScriptService.Server.Services.RoadService)

local function expect(condition, message)
	if not condition then
		error("[CONVOY_BALANCE] " .. message, 2)
	end
end

RoadService.Start(4404)
expect(RoadService.GetSeed() == 4404, "representative seed is not reproducible")

local speeds = {}
for classId, composition in ConvoyConfig do
	local config = VehicleConfig[composition.VehicleType]
	local fullDemand = composition.Count
		* (config.IdleFuelPerSecond + config.ThrottleFuelPerSecond)
		* config.FuelConsumptionMultiplier
	local minutes = composition.StartingFuel / fullDemand / 60
	expect(minutes >= 4 and minutes <= 6.1, classId .. " misses the initial fuel-duration band")
	speeds[classId] = config.MaxForwardSpeed
end

expect(
	speeds.Bike > speeds.Ute and speeds.Ute > speeds.Roadtrain,
	"class speed identities collapsed"
)
expect(
	VehicleConfig.Roadtrain.MaxHull > VehicleConfig.Ute.MaxHull
		and VehicleConfig.Ute.MaxHull > VehicleConfig.Bike.MaxHull,
	"class durability identities collapsed"
)

print("[CONVOY_BALANCE] PASS: fixed seed and distinct four-to-six-minute class baselines")
print("M4_CONVOY_BALANCE_OK")
