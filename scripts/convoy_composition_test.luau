local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local services = ServerScriptService.Server.Services
local RoadService = require(services.RoadService)
local ConvoyService = require(services.ConvoyService)
local VehicleBuilder = require(services.VehicleBuilder)
local ConvoyConfig = require(ReplicatedStorage.Shared.Config.ConvoyConfig)
local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)

local function expect(condition, message)
	if not condition then
		error("[CONVOY_COMPOSITION] " .. message, 2)
	end
end

VehicleBuilder.SetAssetLoadingEnabledForTests(false)
RoadService.Start(4404)
ConvoyService.Start()

local expectedCounts = { Roadtrain = 1, Ute = 2, Bike = 3 }
local records = {}
for classId, expectedCount in expectedCounts do
	local record = ConvoyService.Create(
		9000 + expectedCount,
		"Player",
		classId,
		CFrame.new((expectedCount - 2) * 38, 4, 100)
	)
	records[classId] = record
	expect(#record.Members == expectedCount, classId .. " member count is wrong")
	expect(record.Model:GetAttribute("ClassId") == classId, classId .. " class is not replicated")
	expect(record.ControlledVehicle == record.Members[1], classId .. " has no deterministic leader")
	expect(record.Fuel == ConvoyConfig[classId].StartingFuel, classId .. " shared fuel is wrong")
	for index, vehicle in record.Members do
		expect(ConvoyService.GetByVehicle(vehicle) == record, "reverse membership lookup failed")
		expect(vehicle:GetAttribute("ConvoyId") == record.Id, "vehicle has wrong ConvoyId")
		expect(vehicle:GetAttribute("FormationSlot") == index, "vehicle has wrong formation slot")
		expect(vehicle:GetAttribute("Operational") == true, "vehicle did not start operational")
		local config = VehicleConfig[classId]
		expect(vehicle.PrimaryPart ~= nil and not vehicle.PrimaryPart.Anchored, "invalid chassis")
		for _, contact in config.WheelContacts do
			expect(
				vehicle.PrimaryPart:FindFirstChild("SuspensionPoint" .. contact.Name) ~= nil,
				classId .. " is missing suspension " .. contact.Name
			)
		end
		expect(vehicle:FindFirstChild("DriverSeat") ~= nil, classId .. " has no driver seat")
		expect(
			vehicle:FindFirstChild("PersonnelHitbox") ~= nil,
			classId .. " has no personnel interface"
		)
		expect(
			vehicle.PrimaryPart:FindFirstChild("CameraAttachment") ~= nil,
			classId .. " has no camera attachment"
		)
	end
end

for _, record in records do
	ConvoyService.Remove(record, true)
end

print("[CONVOY_COMPOSITION] PASS: roadtrain, two-ute and three-bike records are valid")
print("M4_CONVOY_COMPOSITION_OK")
