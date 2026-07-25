local ServerScriptService = game:GetService("ServerScriptService")

local services = ServerScriptService.Server.Services
local RoadService = require(services.RoadService)
local ConvoyService = require(services.ConvoyService)
local CombatService = require(services.CombatService)
local FuelService = require(services.FuelService)
local PickupService = require(services.PickupService)
local VehicleBuilder = require(services.VehicleBuilder)

local function expect(condition, message)
	if not condition then
		error("[SHARED_FUEL] " .. message, 2)
	end
end

local function pickup(kind, amount)
	local part = Instance.new("Part")
	part:SetAttribute("PickupType", kind)
	part:SetAttribute("PickupAmount", amount)
	return part
end

VehicleBuilder.SetAssetLoadingEnabledForTests(false)
RoadService.Start(4404)
ConvoyService.Start()
local convoy = ConvoyService.Create(9200, "Player", "Bike", CFrame.new(0, 4, 100))
for _, member in convoy.Members do
	member:SetAttribute("ServerThrottle", 1)
	member:SetAttribute("SurfaceFuelMultiplier", 1)
end

local initialFuel = convoy.Fuel
FuelService.StepForTest(1)
local threeMemberUse = initialFuel - convoy.Fuel
expect(threeMemberUse > 0, "operational members consumed no fuel")
expect(convoy.Members[2]:GetAttribute("Fuel") == convoy.Fuel, "shared fuel was not mirrored")

CombatService.DestroyVehicle(convoy.Members[3], nil)
ConvoyService.SetFuel(convoy, initialFuel)
FuelService.StepForTest(1)
local twoMemberUse = initialFuel - convoy.Fuel
expect(twoMemberUse > 0 and twoMemberUse < threeMemberUse, "wreck still consumes shared fuel")

ConvoyService.SetFuel(convoy, 10)
local fuelPickup = pickup("Fuel", 30)
expect(
	PickupService.CollectForTest(fuelPickup, convoy.Members[2]),
	"companion could not collect fuel"
)
expect(convoy.Fuel == 40, "fuel pickup did not replenish the convoy pool")
expect(convoy.Members[1]:GetAttribute("Fuel") == 40, "fuel pickup was not mirrored to leader")

convoy.Members[1]:SetAttribute("Hull", 50)
convoy.Members[2]:SetAttribute("Hull", 20)
local repairPickup = pickup("Repair", 25)
expect(PickupService.CollectForTest(repairPickup, convoy.Members[1]), "repair pickup was rejected")
expect(convoy.Members[2]:GetAttribute("Hull") == 45, "repair did not target most damaged survivor")
expect(convoy.Members[1]:GetAttribute("Hull") == 50, "repair touched the wrong member")

print("[SHARED_FUEL] PASS: aggregate consumption, convoy fuel and deterministic repair work")
print("M4_SHARED_FUEL_OK")
