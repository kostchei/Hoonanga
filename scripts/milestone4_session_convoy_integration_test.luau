--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SessionConfig = require(ReplicatedStorage.Shared.Config.SessionConfig)
local services = ServerScriptService.Server.Services
local AIService = require(services.AIService)
local ConvoyService = require(services.ConvoyService)
local RemoteService = require(services.RemoteService)
local RoadService = require(services.RoadService)
local SessionService = require(services.SessionService)
local VehicleBuilder = require(services.VehicleBuilder)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[M4_SESSION_CONVOY] " .. message, 2)
	end
end

VehicleBuilder.SetAssetLoadingEnabledForTests(false)
RemoteService.Start()
RoadService.Start(7404)
ConvoyService.Start()
AIService.ResetCompetitors()

local human = ConvoyService.Create(7400, "Player", "Ute", CFrame.new(-24, 4, 120))
for _, vehicle in human.Members do
	vehicle:SetAttribute("MatchInputEnabled", true)
end
local rivals = SessionService.SpawnAIRivalsForTest({ "Ute" }, 7404)

expect(SessionConfig.MinPlayers == 1, "solo human play is still blocked")
expect(#rivals == 2, "session did not create exactly two AI rivals")
expect(#ConvoyService.GetAll() == 3, "solo match did not contain three competitor convoys")

local classes = { Ute = true }
local distinctTraitRolls = {}
for _, rival in rivals do
	classes[rival.ClassId] = true
	expect(rival.Model:GetAttribute("CompetitorType") == "AI", "rival lacks AI roster identity")
	for _, vehicle in rival.Members do
		local speed = vehicle:GetAttribute("AISpeed")
		local accuracy = vehicle:GetAttribute("AIAccuracy")
		local aggression = vehicle:GetAttribute("AIAggression")
		local vendetta = vehicle:GetAttribute("AIVendetta")
		expect(typeof(speed) == "number" and speed >= 0.9 and speed <= 0.98, "invalid speed")
		expect(
			typeof(accuracy) == "number" and accuracy >= 0.5 and accuracy <= 0.95,
			"invalid accuracy"
		)
		expect(
			typeof(aggression) == "number" and aggression >= 0.25 and aggression <= 0.95,
			"invalid aggression"
		)
		expect(
			typeof(vendetta) == "number" and vendetta >= 0.25 and vendetta <= 0.95,
			"invalid vendetta"
		)
		distinctTraitRolls[string.format("%.6f", speed)] = true
	end
end
expect(classes.Roadtrain, "solo Ute roster did not fill Roadtrain")
expect(classes.Bike, "solo Ute roster did not fill Bike")

local distinctCount = 0
for _ in distinctTraitRolls do
	distinctCount += 1
end
expect(distinctCount > 1, "AI vehicles received identical speed rolls")

AIService.StepCompetitorsForTest(0.1)
for _, rival in rivals do
	local leader = rival.Members[1]
	expect(
		typeof(leader:GetAttribute("ServerThrottle")) == "number",
		rival.ClassId .. " rival produced no driving throttle"
	)
end

AIService.StepCompanionsForTest(0.1)
expect(
	(human.Members[2]:GetAttribute("ServerThrottle") or 0) > 0,
	"human Ute teammate did not follow its leader"
)

local function clearScenario()
	AIService.ResetCompetitors()
	for _, record in ConvoyService.GetAll() do
		ConvoyService.Remove(record, true)
	end
end

clearScenario()

local fourHumanClasses = { "Bike", "Bike", "Bike", "Bike" }
for index, classId in fourHumanClasses do
	ConvoyService.Create(7500 + index, "Player", classId, CFrame.new((index - 2.5) * 24, 4, 120))
end
local maximumRivals = SessionService.SpawnAIRivalsForTest(fourHumanClasses, 7504)
expect(#maximumRivals == 2, "maximum roster did not retain exactly two AI rivals")
expect(#ConvoyService.GetAll() == 6, "four-human match did not contain six competitors")
local maximumClasses = {
	[maximumRivals[1].ClassId] = true,
	[maximumRivals[2].ClassId] = true,
}
expect(maximumClasses.Roadtrain, "all-Bike human roster did not add a Roadtrain")
expect(maximumClasses.Ute, "all-Bike human roster did not add a Ute")

local vehicleCount = 0
for _, record in ConvoyService.GetAll() do
	vehicleCount += #record.Members
end
expect(vehicleCount == 15, "maximum six-competitor composition did not contain 15 vehicles")

clearScenario()

print("[M4_SESSION_CONVOY] PASS: three-to-six competitors spawn all classes and teammates")
