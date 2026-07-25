local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local services = ServerScriptService.Server.Services
local RoadService = require(services.RoadService)
local ConvoyService = require(services.ConvoyService)
local VehicleBuilder = require(services.VehicleBuilder)

local function expect(condition, message)
	if not condition then
		error("[CONVOY_STRESS] " .. message, 2)
	end
end

VehicleBuilder.SetAssetLoadingEnabledForTests(false)
RoadService.Start(4404)
ConvoyService.Start()
local records = {}
local userId = 9600
for wave = 1, 2 do
	for _, classId in { "Roadtrain", "Ute", "Bike" } do
		userId += 1
		table.insert(
			records,
			ConvoyService.Create(
				userId,
				"Player",
				classId,
				CFrame.new((userId - 9603) * 15, 4, 100 + wave * 42)
			)
		)
	end
end

local vehicles = 0
for _, tagged in CollectionService:GetTagged("HoonangaVehicle") do
	if tagged:IsA("Model") and tagged:GetAttribute("ConvoyId") ~= nil then
		vehicles += 1
	end
end
expect(#ConvoyService.GetAll() == 6, "stress registry lost a convoy")
expect(vehicles == 12, "stress scenario did not create exactly twelve vehicles")

for _, record in records do
	ConvoyService.Remove(record, true)
end
expect(#ConvoyService.GetAll() == 0, "stress cleanup leaked registry records")

print("[CONVOY_STRESS] PASS: twelve vehicles register and clean up without ambiguity")
print("M4_CONVOY_STRESS_OK")
