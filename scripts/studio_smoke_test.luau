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
local VehicleBuilder = require(services.VehicleBuilder)

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
expect(enemy ~= nil, "AIService did not create the enemy ute")
expect(enemy.PrimaryPart ~= nil, "enemy ute has no primary part")
expect(
	enemy:GetAttribute("VisualAssetId") == 6418225759,
	"enemy ute did not mount the audited pickup body"
)
expect(
	enemy:GetAttribute("VisualVariant") == "Pickup Truck (blue)",
	"enemy ute did not select the blue pickup variant"
)
local creatorStoreBody = enemy:FindFirstChild("CreatorStoreBody")
expect(
	creatorStoreBody ~= nil and creatorStoreBody:IsA("Model"),
	"enemy ute has no Creator Store body model"
)
local visualPartCount = 0
for _, descendant in creatorStoreBody:GetDescendants() do
	expect(
		not descendant:IsA("LuaSourceContainer"),
		"Creator Store body retained executable source"
	)
	expect(
		not descendant:IsA("VehicleSeat"),
		"Creator Store body retained its original chassis seat"
	)
	if descendant:IsA("BasePart") then
		visualPartCount += 1
		expect(not descendant.Anchored, "Creator Store visual part is anchored")
		expect(not descendant.CanCollide, "Creator Store visual part retained collision")
	end
end
expect(visualPartCount >= 30, "Creator Store pickup body is incomplete")

local playerVisualTest = VehicleBuilder.CreateUte(
	vehicles,
	"SmokePlayerVisual",
	CFrame.new(0, 4, 300),
	Color3.fromRGB(184, 73, 42)
)
expect(
	playerVisualTest:GetAttribute("VisualVariant") == "Pickup Truck (bronze)",
	"player ute did not select the bronze pickup variant"
)
local playerBody = playerVisualTest:FindFirstChild("CreatorStoreBody")
expect(playerBody ~= nil and playerBody:IsA("Model"), "player ute has no Creator Store body model")
for _, descendant in playerBody:GetDescendants() do
	expect(not descendant:IsA("LuaSourceContainer"), "player body retained executable source")
	expect(not descendant:IsA("VehicleSeat"), "player body retained its original chassis seat")
end
playerVisualTest:Destroy()

expect(
	enemy.PrimaryPart:FindFirstChild("TurretMuzzleAttachment") ~= nil,
	"enemy ute has no turret muzzle"
)
expect(
	enemy.PrimaryPart:FindFirstChild("ForwardMuzzleAttachment") ~= nil,
	"enemy ute has no forward muzzle"
)

print(
	string.format(
		"[SMOKE] PASS: %d chunks, %d vehicle(s), asphalt/mud/oil generated",
		#roadChunks:GetChildren(),
		#vehicles:GetChildren()
	)
)
