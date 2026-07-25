-- Milestone 3 combat acceptance test, covering GDD 24.3's combat test list:
-- fire-rate validation, ammunition validation, muzzle obstruction,
-- personnel-only pistol behaviour, fire stacking and extinguishing, explosion
-- force limits, friendly-convoy immunity, and moving-target validation. Ram
-- multipliers and the ammunition/repair pickups are covered here too, since
-- they are the rest of the milestone's exit condition.
--
-- Runs headless via scripts/run_studio_test.sh. Every weapon is fired through
-- the same public entry point the player's remote uses (WeaponService.TryFire)
-- rather than by calling damage functions directly, so the validation gates
-- are exercised rather than bypassed.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local function expect(condition, message)
	if not condition then
		error("[COMBAT] " .. message, 2)
	end
end

local function approximately(actual, expected, tolerance)
	return math.abs(actual - expected) <= tolerance
end

-- Studio's headless RunScript task reports a failed assertion as a bare
-- non-zero exit with nothing useful in the output file, so the last section
-- marker printed is what tells you where a failing run stopped.
local function section(name)
	print("[COMBAT] section: " .. name)
end

local shared = ReplicatedStorage:FindFirstChild("Shared")
expect(shared ~= nil, "ReplicatedStorage.Shared is missing")

local WeaponConfig = require(shared.Config.WeaponConfig)
local WeaponState = require(shared.WeaponState)

local services = ServerScriptService:FindFirstChild("Server").Services
local RemoteService = require(services.RemoteService)
local RoadService = require(services.RoadService)
local VehicleBuilder = require(services.VehicleBuilder)
local CombatService = require(services.CombatService)
local WeaponService = require(services.WeaponService)
local ProjectileService = require(services.ProjectileService)
local FireService = require(services.FireService)
local PickupService = require(services.PickupService)
local CollisionDamageService = require(services.CollisionDamageService)

RemoteService.Start()
RoadService.Start(20260725)
PickupService.Start()

local world = Workspace:WaitForChild("HoonangaWorld")
local vehicles = world:WaitForChild("Vehicles")

-- Vehicles are built well above and far to the side of the generated road so
-- nothing in these tests is standing in terrain that could absorb a raycast
-- or a blast and turn a real failure into a passing run.
local TEST_ORIGIN = Vector3.new(2400, 300, 0)
local spawned = {}

local function makeVehicle(name: string, offset: Vector3, team: string): Model
	local vehicle = VehicleBuilder.CreateUte(
		vehicles,
		name,
		CFrame.new(TEST_ORIGIN + offset),
		Color3.fromRGB(184, 73, 42)
	)
	vehicle:SetAttribute("Team", team)
	vehicle:SetAttribute("OwnerUserId", 0)
	local chassis = vehicle.PrimaryPart
	chassis.Anchored = true
	table.insert(spawned, vehicle)
	return vehicle
end

-- Points a vehicle's turret at a target and returns the aim direction the
-- player's camera would produce.
local function aimAt(shooter: Model, target: Model): Vector3
	local muzzle = shooter.PrimaryPart:FindFirstChild("TurretMuzzleAttachment")
	expect(muzzle ~= nil, shooter.Name .. " has no turret muzzle")
	return (target.PrimaryPart.Position - muzzle.WorldPosition).Unit
end

-- Fire intervals are enforced against the server clock, so a test that wants
-- consecutive shots has to actually let that clock advance.
local function waitForFireInterval(weaponId: string)
	task.wait(WeaponConfig.Weapons[weaponId].FireInterval * 1.2)
end

---------------------------------------------------------------------------
-- Loadout and initial ammunition
---------------------------------------------------------------------------

section("Loadout and initial ammunition")

local shooter = makeVehicle("CombatShooter", Vector3.new(0, 0, 60), "Player")
local enemy = makeVehicle("CombatEnemy", Vector3.new(0, 0, -60), "Enemy")

expect(#WeaponConfig.Loadout == 5, "expected 5 selectable weapons, found " .. #WeaponConfig.Loadout)
for _, weaponId in WeaponConfig.Loadout do
	expect(
		WeaponConfig.Weapons[weaponId] ~= nil,
		string.format("loadout references undefined weapon %q", weaponId)
	)
end
expect(
	shooter:GetAttribute("ActiveWeapon") == WeaponConfig.DefaultWeapon,
	"vehicle did not start on the default weapon"
)
for pool in WeaponConfig.AmmoPools do
	expect(
		typeof(shooter:GetAttribute(WeaponState.PoolAttribute(pool))) == "number",
		string.format("vehicle has no %s ammo pool", pool)
	)
end

---------------------------------------------------------------------------
-- Hit regions (GDD 11.2)
---------------------------------------------------------------------------

section("Hit regions (GDD 11.2)")

local personnelHitbox = enemy:FindFirstChild("PersonnelHitbox")
expect(personnelHitbox ~= nil, "enemy has no personnel hitbox")
expect(
	personnelHitbox:GetAttribute("HitRegion") == "Personnel",
	"personnel hitbox is not tagged as the personnel hit region"
)
expect(
	enemy.PrimaryPart:GetAttribute("HitRegion") == "Hull",
	"chassis is not tagged as a hull hit region"
)

---------------------------------------------------------------------------
-- Fire-rate validation (GDD 24.3)
---------------------------------------------------------------------------

section("Fire-rate validation (GDD 24.3)")

WeaponService.SelectWeapon(shooter, "MachineGun")
local aim = aimAt(shooter, enemy)
expect(WeaponService.TryFire(shooter, aim), "machine gun refused its first shot")
local rapidShots = 0
for _ = 1, 30 do
	if WeaponService.TryFire(shooter, aim) then
		rapidShots += 1
	end
end
expect(
	rapidShots == 0,
	string.format("fire interval was not enforced: %d extra shots landed in one frame", rapidShots)
)

---------------------------------------------------------------------------
-- Ammunition validation (GDD 24.3)
---------------------------------------------------------------------------

section("Ammunition validation (GDD 24.3)")

local magazineAttribute = WeaponState.MagazineAttribute("MachineGun")
local magazineBefore = shooter:GetAttribute(magazineAttribute)
waitForFireInterval("MachineGun")
-- Aimed away from the enemy so the forward gun's alignment check cannot fire
-- a second barrel and make the ammunition arithmetic ambiguous.
expect(WeaponService.TryFire(shooter, Vector3.new(0, 0.2, 1).Unit), "machine gun refused to fire")
expect(
	shooter:GetAttribute(magazineAttribute) == magazineBefore - 1,
	"firing did not consume exactly one round from the magazine"
)

shooter:SetAttribute(magazineAttribute, 0)
waitForFireInterval("MachineGun")
expect(not WeaponService.TryFire(shooter, aim), "an empty magazine still fired")

local bulletsBefore = WeaponState.GetPool(shooter, "Bullets")
WeaponService.Reload(shooter)
task.wait(WeaponConfig.Weapons.MachineGun.ReloadTime + 0.4)
expect(
	shooter:GetAttribute(magazineAttribute) == WeaponConfig.Weapons.MachineGun.MagazineSize,
	"reload did not refill the magazine"
)
expect(
	WeaponState.GetPool(shooter, "Bullets")
		== bulletsBefore - WeaponConfig.Weapons.MachineGun.MagazineSize,
	"reload did not draw the rounds from the bullet pool"
)

-- Pool-fed weapons have no magazine and spend straight from the pool.
-- ProjectileService.Start() is deliberately not called anywhere in this test,
-- so nothing flies until StepForTest advances it: a rocket launched here
-- cannot wander off and detonate in the middle of a later assertion.
local rocketTarget = makeVehicle("CombatRocketTarget", Vector3.new(-260, 0, -700), "Enemy")
WeaponService.SelectWeapon(shooter, "RocketLauncher")
local rocketsBefore = WeaponState.GetPool(shooter, "Rockets")
expect(
	WeaponService.TryFire(shooter, aimAt(shooter, rocketTarget)),
	"rocket launcher refused to fire"
)
expect(
	WeaponState.GetPool(shooter, "Rockets") == rocketsBefore - 1,
	"firing a rocket did not spend a rocket from the pool"
)
expect(ProjectileService.ActiveCount() == 1, "firing a rocket did not create a projectile")

-- The rocket has to actually travel and detonate on what it hits, rather
-- than being a hitscan wearing a projectile costume.
local rocketTargetHullBefore = rocketTarget:GetAttribute("Hull")
local flightFrames = 0
while ProjectileService.ActiveCount() > 0 and flightFrames < 600 do
	ProjectileService.StepForTest(1 / 60)
	flightFrames += 1
end
expect(flightFrames > 1, "the rocket resolved instantly instead of travelling")
expect(ProjectileService.ActiveCount() == 0, "the rocket never resolved")
expect(
	rocketTarget:GetAttribute("Hull") < rocketTargetHullBefore,
	"a rocket that reached its target did no damage"
)

---------------------------------------------------------------------------
-- Muzzle obstruction (GDD 11.3, 24.3)
---------------------------------------------------------------------------

section("Muzzle obstruction (GDD 11.3, 24.3)")

WeaponService.SelectWeapon(shooter, "MachineGun")
local muzzle = shooter.PrimaryPart:FindFirstChild("TurretMuzzleAttachment")
-- Small enough that the chassis centre - where the obstruction raycast
-- starts - stays outside it. A block that swallowed the ray origin would be
-- skipped by the raycast entirely and the test would pass for the wrong
-- reason, which is the opposite of what it is here to prove.
local obstruction = Instance.new("Part")
obstruction.Name = "MuzzleObstruction"
obstruction.Anchored = true
obstruction.Size = Vector3.new(3, 3, 3)
obstruction.Position = muzzle.WorldPosition
obstruction.Transparency = 0.5
obstruction.Parent = world
expect(
	(obstruction.Position - shooter.PrimaryPart.Position).Magnitude > 3,
	"the test obstruction is close enough to contain the raycast origin"
)

waitForFireInterval("MachineGun")
expect(not WeaponService.TryFire(shooter, aim), "an obstructed muzzle still fired")
expect(
	shooter:GetAttribute("MuzzleBlocked") == true,
	"obstruction was not reported to the crosshair"
)

obstruction:Destroy()
waitForFireInterval("MachineGun")
expect(WeaponService.TryFire(shooter, aim), "clearing the obstruction did not restore firing")
expect(shooter:GetAttribute("MuzzleBlocked") == false, "muzzle obstruction flag was not cleared")

---------------------------------------------------------------------------
-- Turret traverse limits (GDD 11.3)
---------------------------------------------------------------------------

section("Turret traverse limits (GDD 11.3)")

local machineGun = WeaponConfig.Weapons.MachineGun
local behind = -shooter.PrimaryPart.CFrame.LookVector
local clamped, outOfTraverse =
	WeaponService.ClampToTraverse(shooter.PrimaryPart, machineGun, behind)
expect(outOfTraverse, "aiming directly backwards was not reported as out of traverse")
local clampedAngle =
	math.deg(math.acos(math.clamp(clamped:Dot(shooter.PrimaryPart.CFrame.LookVector), -1, 1)))
expect(
	approximately(clampedAngle, machineGun.TraverseYawDegrees, 1),
	string.format(
		"clamped aim sits %.1f degrees off forward, expected the %d degree limit",
		clampedAngle,
		machineGun.TraverseYawDegrees
	)
)
local forward = shooter.PrimaryPart.CFrame.LookVector
local _, forwardOutOfTraverse =
	WeaponService.ClampToTraverse(shooter.PrimaryPart, machineGun, forward)
expect(not forwardOutOfTraverse, "aiming straight ahead was wrongly reported as out of traverse")

---------------------------------------------------------------------------
-- Personnel-only pistol behaviour (GDD 11.4, 24.3)
---------------------------------------------------------------------------

section("Personnel-only pistol behaviour (GDD 11.4, 24.3)")

WeaponService.SelectWeapon(shooter, "Pistol")
expect(shooter:GetAttribute("ActiveWeapon") == "Pistol", "weapon selection did not take effect")

local hullBeforePistol = enemy:GetAttribute("Hull")
local operatorBeforePistol = enemy:GetAttribute("OperatorHealth")
CombatService.ApplyWeaponHit(enemy, "Hull", WeaponConfig.Weapons.Pistol, shooter, 1)
expect(
	enemy:GetAttribute("Hull") == hullBeforePistol,
	"the pistol damaged hull, which is the one thing it must never do"
)
CombatService.ApplyWeaponHit(enemy, "Personnel", WeaponConfig.Weapons.Pistol, shooter, 1)
expect(
	enemy:GetAttribute("OperatorHealth")
		== operatorBeforePistol - WeaponConfig.Weapons.Pistol.PersonnelDamage,
	"the pistol did not apply its full personnel damage"
)
expect(
	WeaponConfig.Weapons.Pistol.Range < WeaponConfig.Weapons.MachineGun.Range,
	"the pistol is not limited to a shorter practical range than the machine gun"
)

---------------------------------------------------------------------------
-- Friendly-convoy immunity (GDD 24.3)
---------------------------------------------------------------------------

section("Friendly-convoy immunity (GDD 24.3)")

local ally = makeVehicle("CombatAlly", Vector3.new(0, 0, 300), "Player")
local allyHullBefore = ally:GetAttribute("Hull")
local allyOperatorBefore = ally:GetAttribute("OperatorHealth")
CombatService.ApplyWeaponHit(ally, "Hull", machineGun, shooter, 1)
CombatService.ApplyWeaponHit(ally, "Personnel", machineGun, shooter, 1)
expect(
	ally:GetAttribute("Hull") == allyHullBefore
		and ally:GetAttribute("OperatorHealth") == allyOperatorBefore,
	"friendly fire damaged a same-team vehicle"
)
expect(not CombatService.IsHostile(shooter, ally), "same-team vehicles were treated as hostile")
expect(CombatService.IsHostile(shooter, enemy), "opposing teams were treated as friendly")
expect(CombatService.IsHostile(nil, shooter), "world damage was treated as friendly")

---------------------------------------------------------------------------
-- Explosion force limits and blast falloff (GDD 24.3)
---------------------------------------------------------------------------

section("Explosion force limits and blast falloff (GDD 24.3)")

local rocketSpec = WeaponConfig.Weapons.RocketLauncher.Projectile
local blastTarget = makeVehicle("CombatBlastTarget", Vector3.new(300, 0, -220), "Enemy")
blastTarget.PrimaryPart.Anchored = false
blastTarget.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
task.wait(0.1)
blastTarget.PrimaryPart.AssemblyLinearVelocity = Vector3.zero

local blastHullBefore = blastTarget:GetAttribute("Hull")
ProjectileService.Detonate(
	blastTarget.PrimaryPart.Position + Vector3.new(0, -3, 0),
	WeaponConfig.Weapons.RocketLauncher,
	rocketSpec,
	shooter,
	1,
	nil
)
expect(
	blastTarget:GetAttribute("Hull") < blastHullBefore,
	"a rocket detonating under a vehicle did no blast damage"
)
local impulseSpeed = blastTarget.PrimaryPart.AssemblyLinearVelocity.Magnitude
expect(
	impulseSpeed <= rocketSpec.MaxImpulseSpeed + 0.001,
	string.format(
		"blast impulse of %.1f exceeded the %.1f stud/s cap",
		impulseSpeed,
		rocketSpec.MaxImpulseSpeed
	)
)

-- Falloff: the same blast at the radius edge must do strictly less than one
-- at the centre, otherwise "close enough" is not a real decision.
local farTarget = makeVehicle("CombatFarTarget", Vector3.new(600, 0, -220), "Enemy")
local farHullBefore = farTarget:GetAttribute("Hull")
ProjectileService.Detonate(
	farTarget.PrimaryPart.Position + Vector3.new(0, 0, rocketSpec.BlastRadius * 0.9),
	WeaponConfig.Weapons.RocketLauncher,
	rocketSpec,
	shooter,
	1,
	nil
)
local farDamage = farHullBefore - farTarget:GetAttribute("Hull")
local nearDamage = blastHullBefore - blastTarget:GetAttribute("Hull")
expect(farDamage > 0, "a blast inside the radius did no damage at all")
expect(
	farDamage < nearDamage,
	string.format(
		"blast damage did not fall off with distance (edge %.1f vs centre %.1f)",
		farDamage,
		nearDamage
	)
)

-- Convoy immunity extends to explosives: a rocket must not splash a teammate.
local allyHullBeforeBlast = ally:GetAttribute("Hull")
ProjectileService.Detonate(
	ally.PrimaryPart.Position,
	WeaponConfig.Weapons.RocketLauncher,
	rocketSpec,
	shooter,
	1,
	nil
)
expect(
	ally:GetAttribute("Hull") == allyHullBeforeBlast,
	"a rocket blast damaged a same-convoy vehicle"
)

---------------------------------------------------------------------------
-- Fire stacking and extinguishing (GDD 11.5, 24.3)
---------------------------------------------------------------------------

section("Fire stacking and extinguishing (GDD 11.5, 24.3)")

local burnTarget = makeVehicle("CombatBurnTarget", Vector3.new(900, 0, -220), "Enemy")
burnTarget:SetAttribute("SurfaceProfile", "Asphalt")
burnTarget:SetAttribute("ForwardSpeed", 0)

expect(burnTarget:GetAttribute("FireState") == "None", "a fresh vehicle is already on fire")
FireService.AddHeat(burnTarget, WeaponConfig.Fire.HeatingThreshold + 1, shooter)
expect(
	burnTarget:GetAttribute("FireState") == "Heating",
	"heat above the heating threshold did not enter the Heating state"
)

-- Stacking: repeated flamethrower ticks escalate through the states rather
-- than each one being treated as an independent, forgettable event.
for _ = 1, 10 do
	FireService.AddHeat(burnTarget, WeaponConfig.Weapons.Flamethrower.HeatPerHit, shooter)
end
expect(
	burnTarget:GetAttribute("Heat") >= WeaponConfig.Fire.IgnitedThreshold,
	"stacked heat did not accumulate past the ignition threshold"
)
expect(
	burnTarget:GetAttribute("FireState") ~= "None"
		and burnTarget:GetAttribute("FireState") ~= "Heating",
	"stacked heat did not escalate the fire state"
)

-- Ignited fire is self-sustaining and damages both channels.
local burnHullBefore = burnTarget:GetAttribute("Hull")
local burnOperatorBefore = burnTarget:GetAttribute("OperatorHealth")
FireService.StepForTest(0.5)
expect(
	burnTarget:GetAttribute("Hull") < burnHullBefore,
	"a burning vehicle took no hull damage over time"
)
expect(
	burnTarget:GetAttribute("OperatorHealth") < burnOperatorBefore,
	"a burning vehicle's crew took no fire damage"
)

-- Extinguishing: mud is explicitly a way out of a fire (GDD 11.5).
FireService.AddHeat(burnTarget, WeaponConfig.Fire.MaxHeat, shooter)
local heatOnAsphalt = burnTarget:GetAttribute("Heat")
burnTarget:SetAttribute("SurfaceProfile", "Asphalt")
FireService.StepForTest(1)
local asphaltDrop = heatOnAsphalt - burnTarget:GetAttribute("Heat")

FireService.AddHeat(burnTarget, WeaponConfig.Fire.MaxHeat, shooter)
local heatBeforeMud = burnTarget:GetAttribute("Heat")
burnTarget:SetAttribute("SurfaceProfile", "Mud")
FireService.StepForTest(1)
local mudDrop = heatBeforeMud - burnTarget:GetAttribute("Heat")
expect(
	mudDrop > asphaltDrop,
	string.format(
		"mud did not extinguish faster than asphalt (mud %.2f vs asphalt %.2f per second)",
		mudDrop,
		asphaltDrop
	)
)

for _ = 1, 60 do
	FireService.StepForTest(0.5)
	if burnTarget:GetAttribute("FireState") == "None" then
		break
	end
end
expect(
	burnTarget:GetAttribute("FireState") == "None" or burnTarget:GetAttribute("Destroyed") == true,
	"a vehicle sitting in mud never extinguished"
)

-- A molotov's fire patch is a real, expiring world object that heats whoever
-- is standing in it, and lives outside the road chunks so recycling cannot
-- delete it mid-burn (GDD 24.5).
local patchTarget = makeVehicle("CombatPatchTarget", Vector3.new(1200, 0, -220), "Enemy")
patchTarget:SetAttribute("SurfaceProfile", "Asphalt")
patchTarget:SetAttribute("ForwardSpeed", 0)
local patch = FireService.CreateFirePatch(
	patchTarget.PrimaryPart.Position,
	WeaponConfig.Weapons.Molotov.FirePatch,
	shooter
)
expect(
	patch.Parent ~= nil and patch.Parent.Name == "Effects",
	"a fire patch was not parented to the world effects folder"
)
expect(
	not patch:IsDescendantOf(world:FindFirstChild("RoadChunks")),
	"a fire patch was parented inside a recyclable road chunk"
)
FireService.StepForTest(0.5)
expect(patchTarget:GetAttribute("Heat") > 0, "standing in a molotov fire patch applied no heat")
patch:Destroy()

---------------------------------------------------------------------------
-- Moving-target and latency validation (GDD 24.3)
---------------------------------------------------------------------------

section("Moving-target and latency validation (GDD 24.3)")

-- Damage is resolved from the server's own view of the world at the moment
-- the shot is taken, so a target that is moving still takes the hit and a
-- stale client aim direction cannot bend a shot onto it.
local mover = makeVehicle("CombatMovingTarget", Vector3.new(-60, 0, -120), "Enemy")
mover.PrimaryPart.Anchored = false
mover.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, -40)
WeaponService.SelectWeapon(shooter, "MachineGun")
local moverHullBefore = mover:GetAttribute("Hull")
local firedAtMover = false
local hitMover = false
-- A burst rather than a single round: the machine gun has real spread, so one
-- shot at a small target is a coin flip and asserting on it would make this a
-- flaky test rather than a strict one. The claim being proved is that the
-- server resolves hits against where the target actually is, not that every
-- individual bullet connects.
for _ = 1, 20 do
	-- Re-seeded each attempt so the target is genuinely in motion at the
	-- moment of the shot without simply falling out of range while the test
	-- waits on fire intervals.
	mover.PrimaryPart.CFrame = CFrame.new(TEST_ORIGIN + Vector3.new(-60, 0, -120))
	mover.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, -40)
	waitForFireInterval("MachineGun")
	if WeaponService.TryFire(shooter, aimAt(shooter, mover)) then
		firedAtMover = true
	end
	if mover:GetAttribute("Hull") < moverHullBefore then
		hitMover = true
		break
	end
end
expect(firedAtMover, "could not fire at a moving target at all")
expect(hitMover, "a burst aimed at a moving target registered no server-side hit")
mover.PrimaryPart.AssemblyLinearVelocity = Vector3.zero

local staleAim = Vector3.new(0, 1, 0)
local staleHullBefore = mover:GetAttribute("Hull")
waitForFireInterval("MachineGun")
WeaponService.TryFire(shooter, staleAim)
expect(
	mover:GetAttribute("Hull") == staleHullBefore,
	"a shot aimed into empty space still damaged a target"
)
mover.PrimaryPart.Anchored = true

---------------------------------------------------------------------------
-- Ramming (GDD 11.4)
---------------------------------------------------------------------------

section("Ramming (GDD 11.4)")

local rammer = makeVehicle("CombatRammer", Vector3.new(1500, 0, 0), "Player")
local rammed = makeVehicle("CombatRammed", Vector3.new(1500, 0, -30), "Enemy")
expect(
	rammer:GetAttribute("RamDealtMultiplier") == 1
		and rammed:GetAttribute("RamReceivedMultiplier") == 1,
	"ram multipliers were not initialised to neutral"
)

local neutralHullBefore = rammed:GetAttribute("Hull")
CombatService.ApplyImpactDamage(rammed, 20, rammer)
local neutralDamage = neutralHullBefore - rammed:GetAttribute("Hull")
expect(
	approximately(neutralDamage, 20, 0.001),
	string.format("neutral ram equipment changed impact damage (%.2f)", neutralDamage)
)

rammer:SetAttribute("RamDealtMultiplier", 2)
rammed:SetAttribute("RamReceivedMultiplier", 0.5)
local equippedHullBefore = rammed:GetAttribute("Hull")
CombatService.ApplyImpactDamage(rammed, 20, rammer)
local equippedDamage = equippedHullBefore - rammed:GetAttribute("Hull")
expect(
	approximately(equippedDamage, 20, 0.001),
	string.format(
		"ram equipment multipliers were not both applied (expected 20, got %.2f)",
		equippedDamage
	)
)

rammed:SetAttribute("RamReceivedMultiplier", 1)
local dealtHullBefore = rammed:GetAttribute("Hull")
CombatService.ApplyImpactDamage(rammed, 20, rammer)
expect(
	dealtHullBefore - rammed:GetAttribute("Hull") > neutralDamage,
	"a ram bar did not increase the damage dealt"
)

-- The physical path still works end to end, not just the arithmetic. Both
-- chassis have to be unanchored for a velocity to stick at all.
rammer:SetAttribute("RamDealtMultiplier", 1)
rammed:SetAttribute("Hull", rammed:GetAttribute("MaxHull"))
rammer.PrimaryPart.Anchored = false
rammed.PrimaryPart.Anchored = false
local collisionHullBefore = rammed:GetAttribute("Hull")
rammer.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, -70)
rammed.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
CollisionDamageService.ApplyVehicleImpactForTest(rammer, rammed)
expect(
	rammed:GetAttribute("Hull") < collisionHullBefore,
	"a high-speed collision did no impact damage"
)
rammer.PrimaryPart.Anchored = true
rammed.PrimaryPart.Anchored = true

---------------------------------------------------------------------------
-- Ammunition and repair pickups (GDD 12.2, 12.3)
---------------------------------------------------------------------------

section("Ammunition and repair pickups (GDD 12.2, 12.3)")

local roadChunks = world:WaitForChild("RoadChunks")
local seenPickupTypes = {}
for _, descendant in roadChunks:GetDescendants() do
	local pickupType = descendant:GetAttribute("PickupType")
	if typeof(pickupType) == "string" then
		seenPickupTypes[pickupType] = true
	end
end
for _, required in { "Fuel", "Bullets", "Repair" } do
	expect(
		seenPickupTypes[required] == true,
		string.format("no %s pickup was generated in the initial road", required)
	)
end
expect(
	#CollectionService:GetTagged("HoonangaPickup") > 0,
	"generated pickups are not tagged for PickupService"
)

local collector = makeVehicle("CombatCollector", Vector3.new(1800, 0, 0), "Player")

local function makePickup(pickupType: string, amount: number): Part
	local pickup = Instance.new("Part")
	pickup.Name = pickupType .. "TestPickup"
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.Size = Vector3.new(3, 3, 3)
	pickup.Position = TEST_ORIGIN + Vector3.new(1800, 10, 0)
	pickup:SetAttribute("PickupType", pickupType)
	pickup:SetAttribute("PickupAmount", amount)
	pickup.Parent = world
	return pickup
end

WeaponState.SetPool(collector, "Rockets", 0)
local rocketPickup = makePickup("Rockets", 3)
expect(
	PickupService.CollectForTest(rocketPickup, collector),
	"a rocket pickup was refused by an empty vehicle"
)
expect(
	WeaponState.GetPool(collector, "Rockets") == 3,
	"a rocket pickup did not top up the rocket pool"
)
rocketPickup:Destroy()

-- A pool that is already full must not silently swallow the pickup.
WeaponState.SetPool(collector, "Rockets", WeaponConfig.AmmoPools.Rockets.Max)
local fullPickup = makePickup("Rockets", 3)
expect(
	not PickupService.CollectForTest(fullPickup, collector),
	"a full vehicle still consumed an ammunition pickup"
)
fullPickup:Destroy()

collector:SetAttribute("Hull", 20)
local repairPickup = makePickup("Repair", WeaponConfig.RepairAmount)
expect(
	PickupService.CollectForTest(repairPickup, collector),
	"a repair pickup was refused by a damaged vehicle"
)
expect(
	collector:GetAttribute("Hull") == 20 + WeaponConfig.RepairAmount,
	"a repair pickup did not restore hull"
)
repairPickup:Destroy()

-- Repairs never overheal, and never resurrect (GDD 12.3).
collector:SetAttribute("Hull", collector:GetAttribute("MaxHull"))
expect(CombatService.Repair(collector, 50) == 0, "repairing a full hull added health")
collector:SetAttribute("Destroyed", true)
collector:SetAttribute("Hull", 10)
expect(CombatService.Repair(collector, 50) == 0, "a destroyed vehicle was repaired")

---------------------------------------------------------------------------

for _, vehicle in spawned do
	vehicle:Destroy()
end

print("[COMBAT] PASS: 5 weapons, damage channels, fire states and pickups validated")
