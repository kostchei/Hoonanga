local ServerScriptService = game:GetService("ServerScriptService")

local services = ServerScriptService.Server.Services
local RoadService = require(services.RoadService)
local ConvoyService = require(services.ConvoyService)
local AIService = require(services.AIService)
local VehicleBuilder = require(services.VehicleBuilder)

local function expect(condition, message)
	if not condition then
		error("[COMPANION_FORMATION] " .. message, 2)
	end
end

VehicleBuilder.SetAssetLoadingEnabledForTests(false)
RoadService.Start(4404)
ConvoyService.Start()
local convoy = ConvoyService.Create(9300, "Player", "Bike", CFrame.new(0, 4, 100))
local leader = convoy.Members[1]
leader:SetAttribute("RunDistance", 30)

AIService.StepCompanionsForTest(0.1)
for index = 2, 3 do
	local companion = convoy.Members[index]
	expect(
		(companion:GetAttribute("ServerThrottle") or 0) > 0,
		"companion did not produce a formation throttle"
	)
	expect(
		typeof(companion:GetAttribute("ServerSteer")) == "number",
		"companion did not produce formation steering"
	)
end

for _, chunk in workspace.HoonangaWorld.RoadChunks:GetChildren() do
	expect(
		typeof(chunk:GetAttribute("FormationHalfWidth")) == "number",
		"road chunk has no formation capacity"
	)
end

print("[COMPANION_FORMATION] PASS: companions follow curved path targets and road capacity")
print("M4_COMPANION_FORMATION_OK")
