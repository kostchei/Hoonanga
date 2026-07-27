--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DustPolicy = require(ReplicatedStorage.Shared.DustPolicy)
local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local services = ServerScriptService.Server.Services
local RoadService = require(services.RoadService)
local VehicleBuilder = require(services.VehicleBuilder)
local VehicleService = require(services.VehicleService)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[M6_DUST] " .. message, 2)
	end
end

for vehicleType, config in VehicleConfig do
	local rearContacts = DustPolicy.RearContactNames(config.WheelContacts)
	expect(#rearContacts == 2, vehicleType .. " must emit from two rear contacts")
	for _, name in rearContacts do
		expect(
			string.sub(name, 1, 1) == "R",
			vehicleType .. " selected a non-rear contact: " .. name
		)
	end
end

expect(not DustPolicy.ShouldEmit("Mud", 80, 4, false), "mud emitted dry dust")
expect(not DustPolicy.ShouldEmit("Asphalt", 80, 4, false), "asphalt emitted dry dust")
expect(not DustPolicy.ShouldEmit("Oil", 80, 4, false), "oil emitted dry dust")
expect(not DustPolicy.ShouldEmit("Air", 80, 0, false), "airborne vehicle emitted dust")
expect(not DustPolicy.ShouldEmit("Sand", 4, 4, false), "stationary vehicle emitted dust")
expect(not DustPolicy.ShouldEmit("Sand", 80, 4, true), "destroyed vehicle emitted dust")
expect(DustPolicy.ShouldEmit("WornDirt", 80, 4, false), "worn dirt emitted no dust")
expect(DustPolicy.ShouldEmit("LooseStone", 80, 4, false), "loose stone emitted no dust")
expect(DustPolicy.ShouldEmit("Sand", 80, 4, false), "sand emitted no dust")
expect(DustPolicy.ShouldEmit("SaltPan", 80, 4, false), "salt pan emitted no dust")
expect(
	DustPolicy.EmissionRate(80, true) < DustPolicy.EmissionRate(80, false),
	"low-performance mode did not reduce dust"
)

VehicleBuilder.SetAssetLoadingEnabledForTests(false)
RoadService.Start(6613)
local vehicles = Workspace.HoonangaWorld.Vehicles
local vehicle = VehicleBuilder.CreateUte(
	vehicles,
	"DustSurfaceProbe",
	WorldConfig.Spawn.Player,
	Color3.new(1, 1, 1)
)
expect(vehicle.PrimaryPart ~= nil, "surface probe has no chassis")
vehicle.PrimaryPart.Anchored = true

local function findSurface(profile: string): BasePart?
	for _, chunk in Workspace.HoonangaWorld.RoadChunks:GetChildren() do
		for _, descendant in chunk:GetDescendants() do
			if
				descendant:IsA("BasePart")
				and descendant:GetAttribute("SurfaceProfile") == profile
			then
				return descendant
			end
		end
	end
	return nil
end

for _, profile in { "Mud", "Asphalt" } do
	local surface = findSurface(profile)
	expect(surface ~= nil, "generated road is missing " .. profile)
	vehicle:PivotTo((surface :: BasePart).CFrame * CFrame.new(0, 4, 0))
	VehicleService.UpdateServerSurfaceForTest(vehicle)
	expect(
		vehicle:GetAttribute("ServerSurfaceProfile") == profile,
		"server surface sampler did not report " .. profile
	)
	expect(
		(vehicle:GetAttribute("ServerGroundedWheels") or 0) > 0,
		"server surface sampler reported no grounded wheels"
	)
end

vehicle:Destroy()
print("[M6_DUST] PASS: rear dry-surface dust excludes mud and asphalt")
