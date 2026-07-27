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
local ConvoyService = require(services.ConvoyService)
local VehicleService = require(services.VehicleService)
local PickupService = require(services.PickupService)
local FuelService = require(services.FuelService)
local CombatService = require(services.CombatService)
local WeaponService = require(services.WeaponService)
local ProjectileService = require(services.ProjectileService)
local FireService = require(services.FireService)
local CollisionDamageService = require(services.CollisionDamageService)
local AIService = require(services.AIService)
local VehicleBuilder = require(services.VehicleBuilder)
local WeaponState = require(shared.WeaponState)
local WeaponConfig = require(shared.Config.WeaponConfig)
local WorldConfig = require(shared.Config.WorldConfig)

-- Creator Store loading has a separate concurrent-loading regression gate.
-- Keep the broad smoke test deterministic and exercise the safe graybox path.
VehicleBuilder.SetAssetLoadingEnabledForTests(false)
RemoteService.Start()
local remotes = ReplicatedStorage:FindFirstChild("HoonangaRemotes")
expect(remotes ~= nil, "RemoteService did not create HoonangaRemotes")
expect(remotes:FindFirstChild("VehicleInput") ~= nil, "VehicleInput remote is missing")
expect(remotes:FindFirstChild("SelectWeapon") ~= nil, "SelectWeapon remote is missing")

RoadService.Start()
ConvoyService.Start()
VehicleService.Start()
PickupService.Start()
FuelService.Start()
WeaponService.Start()
ProjectileService.Start()
FireService.Start()
CollisionDamageService.Start()
AIService.Start()

-- Rival convoys are session-owned. The smoke test has no real lobby roster,
-- so register one explicitly instead of relying on the removed pre-session
-- singleton enemy.
local smokeEnemyConvoy =
	ConvoyService.CreateSingleNPC("Enemy", "Ute", "EnemyUte_01", WorldConfig.Spawn.Enemy)
local smokeEnemy = smokeEnemyConvoy.Members[1]
smokeEnemy.Name = "EnemyUte_01"
AIService.RegisterCompetitor(smokeEnemyConvoy, 4840, 1)

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
	"no fork chunk was generated within the first 21 chunks (fork interval is 6-10)"
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
expect(typeof(forkChunk:GetAttribute("ForkSet")) == "string", "fork chunk has no set ID")
local forkHasResource = forkChunk:FindFirstChild("FuelPickup") ~= nil
	or forkChunk:FindFirstChild("BulletsPickup") ~= nil
	or forkChunk:FindFirstChild("RepairPickup") ~= nil
expect(forkHasResource, "fork chunk has no resource tradeoff")

-- GDD 8.2 chunk metadata. Nothing consumes most of these yet, so without an
-- assertion they would silently rot as families are added and changed.
for _, chunkModel in roadChunks:GetChildren() do
	for _, attribute in
		{
			"ChunkId",
			"RoadFamily",
			"Difficulty",
			"Length",
			"EntryHeading",
			"ExitHeading",
			"AllowsFork",
			"MinSpeed",
			"MaxActiveEnemies",
			"Weight",
		}
	do
		expect(
			chunkModel:GetAttribute(attribute) ~= nil,
			string.format("chunk %s is missing metadata %s", chunkModel.Name, attribute)
		)
	end
end

local vehicles = world:FindFirstChild("Vehicles")
expect(vehicles ~= nil, "Vehicles folder is missing")
local enemy = smokeEnemy
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
expect(
	personnelHitbox:GetAttribute("HitRegion") == "Personnel",
	"personnel hitbox is not tagged as the personnel hit region"
)
expect(
	enemy.PrimaryPart:GetAttribute("HitRegion") == "Hull",
	"enemy chassis is not tagged as a hull hit region"
)
expect(enemy:GetAttribute("OperatorHealth") == 100, "enemy ute operator health not initialized")
expect(enemy:GetAttribute("Heat") == 0, "enemy ute fire heat not initialized")
expect(enemy:GetAttribute("FireState") == "None", "enemy ute fire state not initialized")
expect(
	enemy:GetAttribute("ActiveWeapon") == WeaponConfig.DefaultWeapon,
	"enemy ute did not start on the default weapon"
)
for pool in WeaponConfig.AmmoPools do
	expect(
		typeof(enemy:GetAttribute(WeaponState.PoolAttribute(pool))) == "number",
		string.format("enemy ute has no %s ammunition pool", pool)
	)
end
expect(enemy:FindFirstChild("Body") ~= nil, "enemy ute has no safe fallback body")

local playerVisualTest = VehicleBuilder.CreateUte(
	vehicles,
	"SmokePlayerVisual",
	CFrame.new(0, 4, 300),
	Color3.fromRGB(184, 73, 42)
)
expect(playerVisualTest:FindFirstChild("Body") ~= nil, "player ute has no safe fallback body")

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
local hullBeforeOperatorLoss = enemy:GetAttribute("Hull")
CombatService.ApplyOperatorDamage(enemy, 21, nil)
expect(
	typeof(operatorHealthBeforeShot) == "number"
		and (enemy:GetAttribute("OperatorHealth") :: number) < operatorHealthBeforeShot
		and enemy:GetAttribute("Destroyed") ~= true,
	"personnel damage below the kill threshold did not reduce operator health"
)
CombatService.ApplyOperatorDamage(enemy, 100, nil)
expect(
	enemy:GetAttribute("OperatorAlive") == false
		and enemy:GetAttribute("Destroyed") ~= true
		and enemy:GetAttribute("Hull") == hullBeforeOperatorLoss,
	"convoy operator loss did not preserve the intact hull"
)
local enemyConvoy = ConvoyService.GetByVehicle(enemy)
expect(enemyConvoy ~= nil and enemyConvoy.Ended, "final NPC operator loss did not end its convoy")

local strandTest = VehicleBuilder.CreateUte(
	vehicles,
	"SmokeStrandTest",
	CFrame.new(0, 4, 400),
	Color3.new(1, 1, 1)
)
strandTest:SetAttribute("OutOfFuel", true)
CombatService.StrandVehicle(strandTest)
expect(
	strandTest:GetAttribute("Destroyed") == true,
	"stranding a vehicle did not mark it destroyed"
)
expect(
	strandTest:GetAttribute("Hull") == 100,
	"stranding a vehicle incorrectly damaged its hull like a combat kill"
)
strandTest:Destroy()

print(
	string.format(
		"[SMOKE] PASS: %d chunks, %d vehicle(s), asphalt/mud/oil generated",
		#roadChunks:GetChildren(),
		#vehicles:GetChildren()
	)
)
print("SMOKE_RUNTIME_OK")
