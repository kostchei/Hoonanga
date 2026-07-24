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
expect(#roadChunks:GetChildren() == 7, "expected seven initial road chunks")

local vehicles = world:FindFirstChild("Vehicles")
expect(vehicles ~= nil, "Vehicles folder is missing")
local enemy = vehicles:FindFirstChild("EnemyUte_01")
expect(enemy ~= nil, "AIService did not create the enemy ute")
expect(enemy.PrimaryPart ~= nil, "enemy ute has no primary part")
expect(enemy:FindFirstChild("DriverSeat") ~= nil, "enemy ute has no driver seat")
expect(enemy:GetAttribute("Ammo") == 80, "enemy weapon state was not initialized")

print(
	string.format(
		"[SMOKE] PASS: %d chunks, %d vehicle(s), shared modules loaded",
		#roadChunks:GetChildren(),
		#vehicles:GetChildren()
	)
)
