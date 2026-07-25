-- KNOWN LIMITATION (confirmed 2026-07-25): Workspace:StepPhysics does not
-- integrate motion at all when this script runs via Studio's headless
-- `--task RunScript` CLI task (confirmed with a bare unanchored part under
-- gravity with zero custom forces - position never changes across 30 manual
-- steps). That means the travel/velocity assertions below cannot produce a
-- real PASS in that execution mode regardless of whether VehiclePhysics
-- itself is correct - they will report "measured travel=0.0" every time.
-- Use this script only when driving Studio interactively (Play/Run mode, or
-- a live MCP playtest session), not through run_studio_test.sh.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local FIXED_DELTA = 1 / 60

local function expect(condition, message)
	if not condition then
		error("[PHYSICS] " .. message, 2)
	end
end

local services = ServerScriptService.Server.Services
local RemoteService = require(services.RemoteService)
local RoadService = require(services.RoadService)
local CombatService = require(services.CombatService)
local CollisionDamageService = require(services.CollisionDamageService)
local VehicleBuilder = require(services.VehicleBuilder)
local VehiclePhysics = require(ReplicatedStorage.Shared.VehiclePhysics)

RemoteService.Start()
RoadService.Start()
CombatService.Start()
CollisionDamageService.Start()

local world = Workspace:WaitForChild("HoonangaWorld")
local vehicles = world:WaitForChild("Vehicles")

local function createTestUte(name, position, color)
	local ute = VehicleBuilder.CreateUte(vehicles, name, CFrame.new(position), color)
	ute:SetAttribute("Team", name)
	ute:SetAttribute("OwnerUserId", 0)
	local chassis = ute.PrimaryPart
	expect(chassis ~= nil, name .. " has no chassis")
	chassis:SetNetworkOwner(nil)
	return ute
end

local barrier = Instance.new("Part")
barrier.Name = "PhysicsTestBarrier"
barrier.Anchored = true
barrier.CanCollide = true
barrier.Size = Vector3.new(36, 12, 3)
barrier.Position = Vector3.new(0, 6, 35)
barrier:SetAttribute("BoundaryType", "TestBarrier")
barrier.Parent = world
CollectionService:AddTag(barrier, "RoadHardBoundary")

local barrierUte =
	createTestUte("BarrierTestUte", Vector3.new(0, 4, 125), Color3.fromRGB(184, 73, 42))
local barrierStartZ = barrierUte.PrimaryPart.Position.Z
print("[PHYSICS] barrier run started")
for _ = 1, 165 do
	CollisionDamageService.CaptureVelocitiesForTest()
	VehiclePhysics.Step(barrierUte, {
		Throttle = 1,
		Steer = 0,
		Handbrake = false,
	}, FIXED_DELTA)
	Workspace:StepPhysics(FIXED_DELTA, { barrierUte.PrimaryPart })
end
task.wait()

local barrierChassis = barrierUte.PrimaryPart
local barrierTravel = barrierStartZ - barrierChassis.Position.Z
local barrierHull = barrierUte:GetAttribute("Hull")
local barrierUp = barrierChassis.CFrame.UpVector:Dot(Vector3.yAxis)
print(
	string.format(
		"[PHYSICS] barrier measured travel=%.1f z=%.1f y=%.1f hull=%s grounded=%s",
		barrierTravel,
		barrierChassis.Position.Z,
		barrierChassis.Position.Y,
		tostring(barrierHull),
		tostring(barrierUte:GetAttribute("GroundedWheels"))
	)
)
expect(not barrierChassis.Anchored, "chassis remained anchored")
expect(barrierTravel > 35, "force drivetrain did not move the ute")
expect(barrierChassis.Position.Z > 35, "ute passed through the solid barrier")
expect(typeof(barrierHull) == "number" and barrierHull < 100, "barrier impact caused no damage")
expect(barrierUp > 0.65, "suspension/upright control lost the vehicle")
expect(
	(barrierUte:GetAttribute("GroundedWheels") or 0) >= 2,
	"suspension did not report grounded wheels"
)
print(
	string.format(
		"[PHYSICS] barrier PASS travel=%.1f z=%.1f hull=%.1f upright=%.2f",
		barrierTravel,
		barrierChassis.Position.Z,
		barrierHull,
		barrierUp
	)
)

barrierUte:Destroy()
barrier:Destroy()
task.wait()

local rammer = createTestUte("RammerTestUte", Vector3.new(0, 4, 190), Color3.fromRGB(184, 73, 42))
local target = createTestUte("TargetTestUte", Vector3.new(0, 4, 105), Color3.fromRGB(58, 91, 122))
local targetStartZ = target.PrimaryPart.Position.Z
print("[PHYSICS] ram run started")
for _ = 1, 210 do
	CollisionDamageService.CaptureVelocitiesForTest()
	VehiclePhysics.Step(rammer, {
		Throttle = 1,
		Steer = 0,
		Handbrake = false,
	}, FIXED_DELTA)
	VehiclePhysics.Step(target, {
		Throttle = 0,
		Steer = 0,
		Handbrake = false,
	}, FIXED_DELTA)
	Workspace:StepPhysics(FIXED_DELTA, { rammer.PrimaryPart, target.PrimaryPart })
end
task.wait()

local rammerHull = rammer:GetAttribute("Hull")
local targetHull = target:GetAttribute("Hull")
local targetPush = targetStartZ - target.PrimaryPart.Position.Z
expect(targetPush > 3, "ramming transferred no physical momentum")
expect(
	(typeof(rammerHull) == "number" and rammerHull < 100)
		or (typeof(targetHull) == "number" and targetHull < 100),
	"ramming caused no impact damage"
)
expect(
	rammer.PrimaryPart.Position.Z > target.PrimaryPart.Position.Z - 5,
	"rammer passed through the target vehicle"
)
print(
	string.format(
		"[PHYSICS] ram PASS targetPush=%.1f rammerHull=%.1f targetHull=%.1f",
		targetPush,
		rammerHull,
		targetHull
	)
)

rammer:Destroy()
target:Destroy()
print("[PHYSICS] PASS")
