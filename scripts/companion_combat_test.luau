local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local services = ServerScriptService.Server.Services
local RoadService = require(services.RoadService)
local ConvoyService = require(services.ConvoyService)
local RemoteService = require(services.RemoteService)
local AIService = require(services.AIService)
local CombatService = require(services.CombatService)
local VehicleBuilder = require(services.VehicleBuilder)
local WeaponState = require(ReplicatedStorage.Shared.WeaponState)

local function expect(condition, message)
	if not condition then
		error("[COMPANION_COMBAT] " .. message, 2)
	end
end

VehicleBuilder.SetAssetLoadingEnabledForTests(false)
RemoteService.Start()
RoadService.Start(4404)
ConvoyService.Start()
local convoy = ConvoyService.Create(9400, "Player", "Ute", CFrame.new(0, 4, 100))
local enemy =
	ConvoyService.CreateSingleNPC("Player", "Ute", "HostileSameFaction", CFrame.new(0, 4, 20))
local companion = convoy.Members[2]
local target = enemy.Members[1]

expect(not CombatService.IsHostile(convoy.Members[1], companion), "same convoy is hostile")
expect(CombatService.IsHostile(companion, target), "different same-faction convoy is immune")
local friendlyImpactHull = companion:GetAttribute("Hull")
CombatService.ApplyImpactDamage(companion, 5, convoy.Members[1])
expect(
	companion:GetAttribute("Hull") < friendlyImpactHull,
	"same-convoy physical impact was incorrectly immune"
)
expect(
	AIService.FindCompanionTargetForTest(companion) == target,
	"companion chose no hostile target"
)

local active = WeaponState.GetActiveWeapon(companion)
local loadedBefore = WeaponState.GetLoaded(companion, active)
AIService.StepCompanionsForTest(0.1)
local loadedAfter = WeaponState.GetLoaded(companion, active)
expect(loadedAfter < loadedBefore, "companion fire did not consume validated ammunition")

print("[COMPANION_COMBAT] PASS: ConvoyId hostility and server-validated companion fire work")
print("M4_COMPANION_COMBAT_OK")
