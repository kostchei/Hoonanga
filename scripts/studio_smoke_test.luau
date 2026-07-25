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
local CollisionDamageService = require(services.CollisionDamageService)
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
CollisionDamageService.Start()
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

local seenFamilies = {}
for _, chunkModel in roadChunks:GetChildren() do
	local family = chunkModel:GetAttribute("RoadFamily")
	if typeof(family) == "string" then
		seenFamilies[family] = true
	end
end
local familyCount = 0
for _ in seenFamilies do
	familyCount += 1
end
expect(
	familyCount >= 2,
	"expected at least 2 road families across the initial chunks, found " .. familyCount
)
expect(
	seenFamilies.Fork == true,
	"no fork chunk was generated within the first 21 chunks (fork interval is 10-16)"
)

local forkChunk
for _, chunkModel in roadChunks:GetChildren() do
	if chunkModel:GetAttribute("RoadFamily") == "Fork" then
		forkChunk = chunkModel
		break
	end
end
expect(forkChunk ~= nil, "fork chunk marked in seenFamilies but not found by lookup")
expect(forkChunk:FindFirstChild("ForkLaneLeft") ~= nil, "fork chunk has no left lane")
expect(forkChunk:FindFirstChild("ForkLaneRight") ~= nil, "fork chunk has no right lane")
expect(
	forkChunk:FindFirstChild("FuelPickup") ~= nil,
	"fork chunk's left-lane fuel tradeoff is missing"
)

local vehicles = world:FindFirstChild("Vehicles")
expect(vehicles ~= nil, "Vehicles folder is missing")
local enemy = vehicles:FindFirstChild("EnemyUte_01")
expect(enemy ~= nil, "AIService did not create the enemy ute")
expect(enemy.PrimaryPart ~= nil, "enemy ute has no primary part")
expect(not enemy.PrimaryPart.Anchored, "enemy chassis is still kinematic/anchored")
expect(enemy.PrimaryPart.CanCollide, "enemy chassis has no physical collision body")
for _, corner in { "FL", "FR", "RL", "RR" } do
	expect(
		enemy.PrimaryPart:FindFirstChild("SuspensionPoint" .. corner) ~= nil,
		"enemy ute has no " .. corner .. " suspension raycast point"
	)
end
local personnelHitbox = enemy:FindFirstChild("PersonnelHitbox")
expect(personnelHitbox ~= nil, "enemy ute has no personnel hitbox")
expect(personnelHitbox.CanQuery, "personnel hitbox cannot be hit by weapon raycasts")
expect(not personnelHitbox.CanCollide, "personnel hitbox physically collides")
expect(enemy:GetAttribute("OperatorHealth") == 100, "enemy ute operator health not initialized")
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

expect(playerVisualTest.PrimaryPart ~= nil, "player physics test ute has no chassis")
local enemyHullBeforeImpact = enemy:GetAttribute("Hull")
playerVisualTest.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, -65)
enemy.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
CollisionDamageService.ApplyVehicleImpactForTest(playerVisualTest, enemy)
expect(
	typeof(enemyHullBeforeImpact) == "number"
		and (enemy:GetAttribute("Hull") :: number) < enemyHullBeforeImpact,
	"ramming impact did not damage the enemy"
)
playerVisualTest:Destroy()

expect(
	enemy.PrimaryPart:FindFirstChild("TurretMuzzleAttachment") ~= nil,
	"enemy ute has no turret muzzle"
)
expect(
	enemy.PrimaryPart:FindFirstChild("ForwardMuzzleAttachment") ~= nil,
	"enemy ute has no forward muzzle"
)

local operatorHealthBeforeShot = enemy:GetAttribute("OperatorHealth")
CombatService.ApplyOperatorDamage(enemy, 21, nil)
expect(
	typeof(operatorHealthBeforeShot) == "number"
		and (enemy:GetAttribute("OperatorHealth") :: number) < operatorHealthBeforeShot
		and enemy:GetAttribute("Destroyed") ~= true,
	"personnel damage below the kill threshold did not reduce operator health"
)
CombatService.ApplyOperatorDamage(enemy, 100, nil)
expect(
	enemy:GetAttribute("Destroyed") == true,
	"operator health reaching zero did not destroy the vehicle"
)

print(
	string.format(
		"[SMOKE] PASS: %d chunks, %d vehicle(s), asphalt/mud/oil generated",
		#roadChunks:GetChildren(),
		#vehicles:GetChildren()
	)
)
