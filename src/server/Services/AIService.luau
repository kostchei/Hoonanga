--!strict

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VehiclePhysics = require(ReplicatedStorage.Shared.VehiclePhysics)
local WeaponState = require(ReplicatedStorage.Shared.WeaponState)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local RoadService = require(script.Parent.RoadService)
local CombatService = require(script.Parent.CombatService)
local ConvoyService = require(script.Parent.ConvoyService)
local VehicleService = require(script.Parent.VehicleService)
local WeaponService = require(script.Parent.WeaponService)

local enemyVehicle: Model? = nil
local lastFireAttempt = 0
local companionLastFire: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
-- How often the AI *decides* to shoot, not how fast it shoots: WeaponService
-- still enforces each weapon's own fire interval on top of this. Deliberately
-- slower than the machine gun's 0.1s so the enemy reads as an opponent
-- squeezing off bursts rather than a continuous stream of damage.
local AI_FIRE_INTERVAL = 0.25

-- Below 1 so the player can actually run the enemy down; without this the
-- enemy shares the player's top speed and, having spawned ahead, can never
-- be caught.
local AI_MAX_SPEED_SCALE = 0.88
-- Inside this range the enemy stops charging and fights alongside instead
-- of overshooting past the player and having to loop back every pass.
local ENGAGE_RANGE = 110
-- How wrong the AI's steering is allowed to be. Deliberate imperfection:
-- a perfectly-tracking enemy reads as a homing missile, not a driver.
local STEER_ERROR = 0.22
local STEER_ERROR_RATE = 0.45

local function targetVehicle(): Model?
	for _, player in Players:GetPlayers() do
		local vehicle = VehicleService.GetPlayerVehicle(player)
		if vehicle and vehicle.Parent and not vehicle:GetAttribute("Destroyed") then
			return vehicle
		end
	end
	return nil
end

-- How far ahead the AI looks when it has nothing to chase. Long enough to
-- read a bend and start turning into it, short enough that it does not cut
-- the corner across the scenery.
local ROAD_LOOK_AHEAD = 110

local function imperfectSteer(steer: number, now: number): number
	steer += math.noise(now * STEER_ERROR_RATE) * STEER_ERROR
	return math.clamp(steer, -1, 1)
end

local function steerToward(chassis: BasePart, targetPosition: Vector3, fallbackSide: number): number
	local localTarget = chassis.CFrame:PointToObjectSpace(targetPosition)
	if localTarget.Z > 0 then
		local side = if math.abs(localTarget.X) > 1 then localTarget.X else fallbackSide
		return if side >= 0 then 1 else -1
	end
	return math.clamp(localTarget.X / 18, -1, 1)
end

-- Returns steer (-1..1) and throttle (-1..1). The enemy hunts the player
-- rather than driving one-way down the road forever: once the player is
-- behind it, it commits to a U-turn and comes back for another pass, which
-- is what makes it an opponent instead of a pace car.
local function calculateDriving(chassis: BasePart, target: Model?, now: number): (number, number)
	-- No one to hunt: cruise the road's own drivable line at a relaxed pace.
	-- Road families vary in width and hazard placement (narrow canyon
	-- corridors, mudflat's off-centre firm path, the fork's boulder divider)
	-- and the road now bends, so the steering target has to come from the
	-- road itself rather than from a fixed direction in world space.
	if not target or not target.PrimaryPart then
		local lookAhead = RoadService.GetLaneTarget(chassis.Position, ROAD_LOOK_AHEAD)
		if not lookAhead then
			return 0, 0.5
		end
		return imperfectSteer(steerToward(chassis, lookAhead, 1), now), 0.5
	end

	local targetPosition = target.PrimaryPart.Position
	local distance = (targetPosition - chassis.Position).Magnitude
	local localTarget = chassis.CFrame:PointToObjectSpace(targetPosition)
	local roadLocation = RoadService.LocateOnPath(chassis.Position)
	local targetRoadLocation = RoadService.LocateOnPath(targetPosition)

	-- At long path separation, follow the road toward the player instead of
	-- steering across the chord of a bend. On a ninety-degree chunk that chord
	-- runs through the scenery; the road target keeps the enemy on the actual
	-- drivable line while preserving its ability to turn around and hunt.
	if roadLocation and targetRoadLocation then
		local pathDelta = targetRoadLocation.Distance - roadLocation.Distance
		if math.abs(pathDelta) > ENGAGE_RANGE then
			local direction = if pathDelta >= 0 then 1 else -1
			local roadTarget =
				RoadService.GetLaneTarget(chassis.Position, ROAD_LOOK_AHEAD * direction)
			if roadTarget then
				local steer = steerToward(chassis, roadTarget, localTarget.X)
				local roadTargetLocal = chassis.CFrame:PointToObjectSpace(roadTarget)
				local throttle = if roadTargetLocal.Z > 0 then 0.45 else 1
				return imperfectSteer(steer, now), throttle
			end
		end
	end

	-- Roblox LookVector points down -Z, so a positive local Z means the
	-- player is behind us.
	local targetIsBehind = localTarget.Z > 0

	local steer, throttle
	if targetIsBehind then
		-- Full-lock U-turn. Throttle is held back so the turn radius stays
		-- inside the road rather than arcing off into the scenery.
		steer = if localTarget.X >= 0 then 1 else -1
		throttle = 0.45
	elseif distance > ENGAGE_RANGE then
		steer = math.clamp(localTarget.X / 26, -1, 1)
		throttle = 1
	else
		-- Alongside: ease off so it fights the player instead of blowing
		-- past and immediately needing another U-turn.
		steer = math.clamp(localTarget.X / 34, -1, 1)
		throttle = 0.62
	end

	-- Wandering steering error, so the enemy drifts and corrects like a
	-- driver rather than tracking perfectly.
	return imperfectSteer(steer, now), throttle
end

-- GDD 13.5 combat AI: the enemy picks a weapon for the range it is at, which
-- is what makes each weapon's role legible from the other side of the fight.
-- Rockets are checked against the pool rather than fired hopefully, so an
-- enemy out of rockets closes to gun range instead of dry-firing.
local ROCKET_RANGE = 210
local FLAME_RANGE = 42

local function chooseWeapon(vehicle: Model, distance: number): string
	if distance <= FLAME_RANGE and WeaponState.GetPool(vehicle, "FlameFuel") > 0 then
		return "Flamethrower"
	end
	if distance >= ROCKET_RANGE and WeaponState.GetPool(vehicle, "Rockets") > 0 then
		return "RocketLauncher"
	end
	return "MachineGun"
end

local function updateEnemy(deltaTime: number)
	local vehicle = enemyVehicle
	if not vehicle or not vehicle.Parent or vehicle:GetAttribute("Destroyed") then
		return
	end

	local chassis = vehicle.PrimaryPart
	if not chassis then
		return
	end

	local target = targetVehicle()
	local now = Workspace:GetServerTimeNow()
	local steer, throttle = calculateDriving(chassis, target, now)
	vehicle:SetAttribute("ServerThrottle", throttle)
	vehicle:SetAttribute("ServerSteer", steer)
	vehicle:SetAttribute("ServerHandbrake", false)
	VehiclePhysics.Step(vehicle, {
		Throttle = throttle,
		Steer = steer,
		Handbrake = false,
	}, deltaTime)

	if target and target.PrimaryPart then
		local muzzle = chassis:FindFirstChild("TurretMuzzleAttachment")
		if muzzle and muzzle:IsA("Attachment") then
			if now - lastFireAttempt >= AI_FIRE_INTERVAL then
				lastFireAttempt = now
				local distance = (target.PrimaryPart.Position - chassis.Position).Magnitude
				WeaponService.SelectWeapon(vehicle, chooseWeapon(vehicle, distance))
				local predictedPosition = target.PrimaryPart.Position
					+ target.PrimaryPart.AssemblyLinearVelocity * 0.08
				local aimError =
					Vector3.new(math.noise(now * 0.7) * 7, math.noise(now * 0.8 + 10) * 4, 0)
				WeaponService.TryFire(vehicle, predictedPosition + aimError - muzzle.WorldPosition)
			end
		end
	end
end

local function findCompanionTarget(vehicle: Model): Model?
	local chassis = vehicle.PrimaryPart
	if not chassis then
		return nil
	end
	local best: Model? = nil
	local bestScore = -math.huge
	for _, candidate in CollectionService:GetTagged("HoonangaVehicle") do
		if
			not candidate:IsA("Model")
			or not candidate.PrimaryPart
			or candidate:GetAttribute("Destroyed")
			or candidate:GetAttribute("Operational") == false
			or not CombatService.IsHostile(vehicle, candidate)
		then
			continue
		end
		local offset = candidate.PrimaryPart.Position - chassis.Position
		local distance = offset.Magnitude
		if distance > 280 or distance < 0.1 then
			continue
		end
		local aim = chassis.CFrame.LookVector:Dot(offset.Unit)
		local hull = candidate:GetAttribute("Hull")
		local maxHull = candidate:GetAttribute("MaxHull")
		local vulnerability = if typeof(hull) == "number"
				and typeof(maxHull) == "number"
				and maxHull > 0
			then 1 - hull / maxHull
			else 0
		local score = -distance + aim * 70 + vulnerability * 25
		if score > bestScore then
			bestScore = score
			best = candidate
		end
	end
	return best
end

local function obstacleAdjustment(
	vehicle: Model,
	_record: ConvoyService.ConvoyRecord
): (number, number)
	local chassis = vehicle.PrimaryPart
	if not chassis then
		return 0, 1
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { vehicle }
	local result = Workspace:Raycast(
		chassis.Position + chassis.CFrame.UpVector * 1.5,
		chassis.CFrame.LookVector * 34,
		params
	)
	if not result then
		return 0, 1
	end
	local localHit = chassis.CFrame:PointToObjectSpace(result.Position)
	return if localHit.X >= 0 then -0.75 else 0.75, 0.35
end

local function updateCompanion(
	record: ConvoyService.ConvoyRecord,
	vehicle: Model,
	leader: Model,
	deltaTime: number,
	now: number
)
	local chassis = vehicle.PrimaryPart
	local leaderChassis = leader.PrimaryPart
	if not chassis or not leaderChassis then
		return
	end
	local leaderLocation = RoadService.LocateOnPath(leaderChassis.Position)
	local followerLocation = RoadService.LocateOnPath(chassis.Position)
	if not leaderLocation or not followerLocation then
		return
	end
	local lateral = vehicle:GetAttribute("FormationLateral")
	local behind = vehicle:GetAttribute("FormationBehind")
	lateral = if typeof(lateral) == "number" then lateral else 0
	behind = if typeof(behind) == "number" then behind else 20
	local halfWidth = leaderLocation.Record.Model:GetAttribute("FormationHalfWidth")
	if typeof(halfWidth) == "number" then
		lateral = math.clamp(lateral, -halfWidth, halfWidth)
	end
	local targetDistance = math.max(0, leaderLocation.Distance - behind)
	local target = RoadService.GetPathTarget(targetDistance, lateral)
	if not target then
		return
	end
	local distanceToTarget = (target - chassis.Position).Magnitude
	local pathLag = targetDistance - followerLocation.Distance
	local steer = steerToward(chassis, target, lateral)
	local obstacleSteer, obstacleThrottle = obstacleAdjustment(vehicle, record)
	steer = math.clamp(steer + obstacleSteer, -1, 1)
	local throttle = if distanceToTarget < 9
		then 0.1
		elseif pathLag > 100 then 1
		elseif pathLag < -15 then 0.25
		else 0.72
	throttle *= obstacleThrottle
	vehicle:SetAttribute("MaxSpeedScale", if pathLag > 120 then 1.1 else 1)
	vehicle:SetAttribute("CatchUpActive", pathLag > 120)
	vehicle:SetAttribute("ServerThrottle", throttle)
	vehicle:SetAttribute("ServerSteer", steer)
	vehicle:SetAttribute("ServerHandbrake", false)
	VehiclePhysics.Step(vehicle, {
		Throttle = throttle,
		Steer = steer,
		Handbrake = false,
	}, deltaTime)

	-- Do not let combat override a close obstacle or narrow-section correction.
	if obstacleThrottle < 1 then
		return
	end
	local combatTarget = findCompanionTarget(vehicle)
	if not combatTarget or not combatTarget.PrimaryPart then
		return
	end
	local lastAttempt = companionLastFire[vehicle] or 0
	if now - lastAttempt < 0.38 then
		return
	end
	companionLastFire[vehicle] = now
	local distance = (combatTarget.PrimaryPart.Position - chassis.Position).Magnitude
	WeaponService.SelectWeapon(vehicle, chooseWeapon(vehicle, distance))
	local aimError = Vector3.new(
		math.noise(now * 0.6, vehicle:GetAttribute("FormationSlot") or 0) * 9,
		math.noise(now * 0.7 + 11) * 5,
		0
	)
	local prediction = combatTarget.PrimaryPart.Position
		+ combatTarget.PrimaryPart.AssemblyLinearVelocity * 0.1
	local muzzle = chassis:FindFirstChild("TurretMuzzleAttachment")
	if muzzle and muzzle:IsA("Attachment") then
		WeaponService.TryFire(vehicle, prediction + aimError - muzzle.WorldPosition)
	end
end

local function updateCompanions(deltaTime: number)
	local now = Workspace:GetServerTimeNow()
	for _, record in ConvoyService.GetAll() do
		if record.Ended or record.Faction ~= "Player" then
			continue
		end
		local leader = record.ControlledVehicle
		if not leader or not ConvoyService.IsOperational(leader) then
			continue
		end
		for _, vehicle in record.Members do
			if vehicle ~= leader and ConvoyService.IsOperational(vehicle) then
				updateCompanion(record, vehicle, leader, deltaTime, now)
			end
		end
	end
end

local AIService = {}

function AIService.StepCompanionsForTest(deltaTime: number)
	updateCompanions(deltaTime)
end

function AIService.FindCompanionTargetForTest(vehicle: Model): Model?
	return findCompanionTarget(vehicle)
end

function AIService.Start()
	if not WorldConfig.Testing.EnemyEnabled then
		print("[Hoonanga] Enemy ute disabled for initial driving test")
	else
		local enemyConvoy =
			ConvoyService.CreateSingleNPC("Enemy", "Ute", "EnemyUte_01", WorldConfig.Spawn.Enemy)
		enemyVehicle = enemyConvoy.Members[1]
		enemyVehicle:SetAttribute("DamageMultiplier", 0.2)
		enemyVehicle:SetAttribute("MaxSpeedScale", AI_MAX_SPEED_SCALE)

		local chassis = enemyVehicle.PrimaryPart
		if chassis and chassis:CanSetNetworkOwnership() then
			chassis:SetNetworkOwner(nil)
		end
	end

	RunService.PreSimulation:Connect(function(deltaTime)
		updateEnemy(deltaTime)
		updateCompanions(deltaTime)
	end)
end

return AIService
