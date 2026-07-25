local ServerScriptService = game:GetService("ServerScriptService")

local services = ServerScriptService.Server.Services
local RoadService = require(services.RoadService)
local ConvoyService = require(services.ConvoyService)
local CombatService = require(services.CombatService)
local VehicleBuilder = require(services.VehicleBuilder)

local function expect(condition, message)
	if not condition then
		error("[CONTROL_TRANSFER] " .. message, 2)
	end
end

VehicleBuilder.SetAssetLoadingEnabledForTests(false)
RoadService.Start(4404)
ConvoyService.Start()
local convoy = ConvoyService.Create(9100, "Player", "Ute", CFrame.new(0, 4, 100))
local first = convoy.Members[1]
local second = convoy.Members[2]
CombatService.DestroyVehicle(first, nil)
expect(first:GetAttribute("Destroyed") == true, "lost vehicle was not made a wreck")
expect(first:GetAttribute("Operational") == false, "lost vehicle remains operational")
expect(convoy.ControlledVehicle == second, "control did not transfer to the survivor")
expect(second:GetAttribute("ControlledByUserId") == 9100, "replacement control is not replicated")
expect(not convoy.Ended, "partial loss ended the convoy")
expect(first:GetAttribute("ServerThrottle") == 0, "old input was not cleared")

local hullBefore = second:GetAttribute("Hull")
CombatService.ApplyOperatorDamage(second, 500, nil)
expect(second:GetAttribute("OperatorAlive") == false, "operator loss was not recorded")
expect(second:GetAttribute("Destroyed") ~= true, "operator loss incorrectly destroyed the hull")
expect(second:GetAttribute("Hull") == hullBefore, "operator loss incorrectly reduced hull")
expect(convoy.Ended, "last operational pair did not end the convoy")
local endReason = convoy.Model:GetAttribute("EndReason")

CombatService.DestroyVehicle(second, nil)
ConvoyService.End(convoy, "UnexpectedSecondEnd")
expect(convoy.Model:GetAttribute("EndReason") == endReason, "convoy ending was not idempotent")

print("[CONTROL_TRANSFER] PASS: partial loss transfers control and final loss ends once")
print("M4_CONTROL_TRANSFER_OK")
