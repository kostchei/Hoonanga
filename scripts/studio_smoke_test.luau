local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local function expect(condition, message)
	if not condition then
		error("[SMOKE] " .. message, 2)
	end
end

local shared = ReplicatedStorage:FindFirstChild("Shared")
expect(shared ~= nil, "ReplicatedStorage.Shared is missing")
expect(shared:FindFirstChild("VehiclePhysics") ~= nil, "VehiclePhysics module is missing")
expect(shared:FindFirstChild("Config") ~= nil, "shared configuration folder is missing")

local serverRoot = ServerScriptService:FindFirstChild("Server")
expect(serverRoot ~= nil, "Server root script is missing")
local services = serverRoot:FindFirstChild("Services")
expect(services ~= nil, "Server.Services is missing")

local RemoteService = require(services.RemoteService)
local RoadService = require(services.RoadService)
local VehicleService = require(services.VehicleService)
local PickupService = require(services.PickupService)
local FuelService = require(services.FuelService)
local CombatService = require(services.CombatService)
local AIService = require(services.AIService)

RemoteService.Start()
local remotes = ReplicatedStorage:FindFirstChild("HoonangaRemotes")
expect(remotes ~= nil, "RemoteService did not create HoonangaRemotes")
expect(remotes:FindFirstChild("VehicleInput") ~= nil, "VehicleInput remote is missing")

RoadService.Start()
VehicleService.Start()
PickupService.Start()
FuelService.Start()
CombatService.Start()
AIService.Start()

task.wait(1)

local world = Workspace:FindFirstChild("HoonangaWorld")
expect(world ~= nil, "RoadService did not create HoonangaWorld")

local roadChunks = world:FindFirstChild("RoadChunks")
expect(roadChunks ~= nil, "RoadChunks folder is missing")
expect(#roadChunks:GetChildren() == 21, "expected 21 initial road chunks")

local foundSurfaces = {
	Asphalt = false,
	Mud = false,
	Oil = false,
}
for _, descendant in roadChunks:GetDescendants() do
	local profile = descendant:GetAttribute("SurfaceProfile")
	if typeof(profile) == "string" and foundSurfaces[profile] ~= nil then
		foundSurfaces[profile] = true
	end
end
expect(foundSurfaces.Asphalt, "no playable asphalt surface was generated")
expect(foundSurfaces.Mud, "no playable mud surface was generated")
expect(foundSurfaces.Oil, "no playable oil surface was generated")

local vehicles = world:FindFirstChild("Vehicles")
expect(vehicles ~= nil, "Vehicles folder is missing")
local enemy = vehicles:FindFirstChild("EnemyUte_01")
expect(enemy == nil, "enemy ute should be disabled during initial driving tests")

print(
	string.format(
		"[SMOKE] PASS: %d chunks, %d vehicle(s), asphalt/mud/oil generated",
		#roadChunks:GetChildren(),
		#vehicles:GetChildren()
	)
)
