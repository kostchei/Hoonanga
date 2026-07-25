local ServerScriptService = game:GetService("ServerScriptService")

local services = ServerScriptService.Server.Services
local RoadService = require(services.RoadService)
local ConvoyService = require(services.ConvoyService)
local CombatService = require(services.CombatService)
local VehicleBuilder = require(services.VehicleBuilder)

local function expect(condition, message)
	if not condition then
		error("[CONVOY_FAILURE] " .. message, 2)
	end
end

VehicleBuilder.SetAssetLoadingEnabledForTests(false)
RoadService.Start(4404)
ConvoyService.Start()
local convoy = ConvoyService.Create(9500, "Player", "Roadtrain", CFrame.new(0, 4, 100))
local roadtrain = convoy.Members[1]
local protectedOperatorHealth = roadtrain:GetAttribute("OperatorHealth")
CombatService.ApplyOperatorDamage(roadtrain, 500, nil)
expect(
	roadtrain:GetAttribute("OperatorHealth") == protectedOperatorHealth,
	"roadtrain operator was damaged through protected hull"
)
ConvoyService.SetFuel(convoy, 0)
expect(roadtrain:GetAttribute("OutOfFuel") == true, "zero shared fuel did not stop engines")
ConvoyService.AddFuel(convoy, 15)
expect(not convoy.Ended and roadtrain:GetAttribute("OutOfFuel") == false, "fuel recovery failed")

ConvoyService.SetFuel(convoy, 0)
CombatService.StrandVehicle(roadtrain)
expect(convoy.Ended, "unrecovered zero fuel did not end the convoy")
expect(convoy.State == "Stranded", "fuel failure was reported as combat elimination")
expect(roadtrain:GetAttribute("Destroyed") ~= true, "stranding fabricated a destroyed hull")

print("[CONVOY_FAILURE] PASS: recovery window state and convoy stranding are distinct")
print("M4_CONVOY_FAILURE_OK")
