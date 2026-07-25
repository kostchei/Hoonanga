--!strict

-- KNOWN LIMITATION (confirmed 2026-07-25): this relies on RunService.
-- PreSimulation actually advancing live physics, which only happens when
-- Studio is in Play/Run mode. Studio's headless `--task RunScript` CLI task
-- opens the place in Edit mode, where physics never simulates on its own
-- (confirmed separately: Workspace:StepPhysics also does nothing there -
-- see vehicle_physics_smoke_test.luau). As a baked-in Script under
-- physics-test.project.json this only does anything when the place is
-- actually played, not when opened for editing.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local services = ServerScriptService.Server.Services
local VehicleBuilder = require(services.VehicleBuilder)
local VehiclePhysics = require(ReplicatedStorage.Shared.VehiclePhysics)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[RUNTIME_PHYSICS] " .. message, 2)
	end
end

local function input(throttle: number): VehiclePhysics.VehicleInput
	return {
		Throttle = throttle,
		Steer = 0,
		Handbrake = false,
	}
end

local function createTestUte(vehicles: Instance, name: string, position: Vector3, color: Color3)
	local ute = VehicleBuilder.CreateUte(vehicles, name, CFrame.new(position), color)
	ute:SetAttribute("Team", name)
	ute:SetAttribute("OwnerUserId", 0)
	local chassis = ute.PrimaryPart
	expect(chassis ~= nil, name .. " has no chassis")
	chassis:SetNetworkOwner(nil)
	return ute
end

local function run()
	local world = Workspace:WaitForChild("HoonangaWorld", 10)
	expect(world ~= nil, "world was not created")
	local vehicles = world:WaitForChild("Vehicles", 5)
	expect(vehicles ~= nil, "vehicle folder was not created")
	task.wait(0.5)

	local barrier = Instance.new("Part")
	barrier.Name = "PhysicsTestBarrier"
	barrier.Anchored = true
	barrier.CanCollide = true
	barrier.Size = Vector3.new(18, 12, 3)
	barrier.Position = Vector3.new(31, 6, 25)
	barrier:SetAttribute("BoundaryType", "TestBarrier")
	barrier.Parent = world
	CollectionService:AddTag(barrier, "RoadHardBoundary")

	local barrierUte = createTestUte(
		vehicles,
		"BarrierTestUte",
		Vector3.new(31, 4, 125),
		Color3.fromRGB(184, 73, 42)
	)
	local barrierStartZ = barrierUte.PrimaryPart.Position.Z
	local barrierConnection = RunService.PreSimulation:Connect(function(deltaTime)
		VehiclePhysics.Step(barrierUte, input(1), deltaTime)
	end)
	print("[RUNTIME_PHYSICS] barrier run started")
	task.wait(3.75)
	barrierConnection:Disconnect()

	local barrierChassis = barrierUte.PrimaryPart
	local barrierTravel = barrierStartZ - barrierChassis.Position.Z
	local barrierHull = barrierUte:GetAttribute("Hull")
	local barrierUp = barrierChassis.CFrame.UpVector:Dot(Vector3.yAxis)
	local groundedWheels = barrierUte:GetAttribute("GroundedWheels")
	print(
		string.format(
			"[RUNTIME_PHYSICS] barrier measured travel=%.1f z=%.1f y=%.1f hull=%s grounded=%s upright=%.2f",
			barrierTravel,
			barrierChassis.Position.Z,
			barrierChassis.Position.Y,
			tostring(barrierHull),
			tostring(groundedWheels),
			barrierUp
		)
	)
	expect(not barrierChassis.Anchored, "chassis remained anchored")
	expect(barrierTravel > 45, "force drivetrain did not move the ute")
	expect(barrierChassis.Position.Z > 25, "ute passed through the solid barrier")
	expect(typeof(barrierHull) == "number" and barrierHull < 100, "barrier impact caused no damage")
	expect(barrierUp > 0.6, "suspension/upright control lost the vehicle")
	expect(typeof(groundedWheels) == "number" and groundedWheels >= 2, "suspension lost the road")
	print("[RUNTIME_PHYSICS] barrier PASS")

	barrierUte:Destroy()
	barrier:Destroy()
	task.wait(0.25)

	local rammer = createTestUte(
		vehicles,
		"RammerTestUte",
		Vector3.new(31, 4, 200),
		Color3.fromRGB(184, 73, 42)
	)
	local target = createTestUte(
		vehicles,
		"TargetTestUte",
		Vector3.new(31, 4, 105),
		Color3.fromRGB(58, 91, 122)
	)
	local targetStartZ = target.PrimaryPart.Position.Z
	local ramConnection = RunService.PreSimulation:Connect(function(deltaTime)
		VehiclePhysics.Step(rammer, input(1), deltaTime)
		VehiclePhysics.Step(target, input(0), deltaTime)
	end)
	print("[RUNTIME_PHYSICS] ram run started")
	task.wait(4.25)
	ramConnection:Disconnect()

	local rammerHull = rammer:GetAttribute("Hull")
	local targetHull = target:GetAttribute("Hull")
	local targetPush = targetStartZ - target.PrimaryPart.Position.Z
	print(
		string.format(
			"[RUNTIME_PHYSICS] ram measured targetPush=%.1f rammerZ=%.1f targetZ=%.1f rammerHull=%s targetHull=%s",
			targetPush,
			rammer.PrimaryPart.Position.Z,
			target.PrimaryPart.Position.Z,
			tostring(rammerHull),
			tostring(targetHull)
		)
	)
	expect(targetPush > 5, "ramming transferred no physical momentum")
	expect(
		(typeof(rammerHull) == "number" and rammerHull < 100)
			or (typeof(targetHull) == "number" and targetHull < 100),
		"ramming caused no impact damage"
	)
	expect(
		rammer.PrimaryPart.Position.Z > target.PrimaryPart.Position.Z - 5,
		"rammer passed through the target vehicle"
	)
	print("[RUNTIME_PHYSICS] ram PASS")

	rammer:Destroy()
	target:Destroy()
	print("[RUNTIME_PHYSICS] PASS")
end

local success, message = xpcall(run, debug.traceback)
if not success then
	warn(message)
end
