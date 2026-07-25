--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VehiclePhysics = require(ReplicatedStorage.Shared.VehiclePhysics)
local WeaponState = require(ReplicatedStorage.Shared.WeaponState)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local VehicleBuilder = require(script.Parent.VehicleBuilder)
local VehicleService = require(script.Parent.VehicleService)
local WeaponService = require(script.Parent.WeaponService)

local enemyVehicle: Model? = nil
local lastFireAttempt = 0
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

-- Road families vary in drivable width and hazard placement (narrow canyon
-- corridors, mudflat's off-center firm path, the fork's boulder divider),
-- so a fixed steering target would eventually drive the enemy into a wall
-- or a boulder line. RoadService publishes each chunk's safe line as
-- PreferredLaneX for exactly this.
local function currentChunkLaneX(chassis: BasePart): number
	local world = Workspace:FindFirstChild("HoonangaWorld")
	local roadChunks = if world then world:FindFirstChild("RoadChunks") else nil
	if not roadChunks then
		return 0
	end

	local road = WorldConfig.Road
	local approxIndex = math.floor(-chassis.Position.Z / road.ChunkLength + 0.5)
	local chunk = roadChunks:FindFirstChild(string.format("Chunk_%04d", approxIndex))
	if chunk then
		local laneX = chunk:GetAttribute("PreferredLaneX")
		if typeof(laneX) == "number" then
			return laneX
		end
	end
	return 0
end

-- Returns steer (-1..1) and throttle (-1..1). The enemy hunts the player
-- rather than driving one-way down the road forever: once the player is
-- behind it, it commits to a U-turn and comes back for another pass, which
-- is what makes it an opponent instead of a pace car.
local function calculateDriving(chassis: BasePart, target: Model?, now: number): (number, number)
	-- No one to hunt: cruise the chunk's safe line at a relaxed pace.
	if not target or not target.PrimaryPart then
		local lookAhead =
			Vector3.new(currentChunkLaneX(chassis), chassis.Position.Y, chassis.Position.Z - 90)
		local localAhead = chassis.CFrame:PointToObjectSpace(lookAhead)
		return math.clamp(localAhead.X / 18, -1, 1), 0.5
	end

	local targetPosition = target.PrimaryPart.Position
	local distance = (targetPosition - chassis.Position).Magnitude
	local localTarget = chassis.CFrame:PointToObjectSpace(targetPosition)
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
	steer += math.noise(now * STEER_ERROR_RATE) * STEER_ERROR
	return math.clamp(steer, -1, 1), throttle
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

local AIService = {}

function AIService.Start()
	if not WorldConfig.Testing.EnemyEnabled then
		print("[Hoonanga] Enemy ute disabled for initial driving test")
		return
	end

	local vehiclesFolder = Workspace:WaitForChild("HoonangaWorld"):WaitForChild("Vehicles")
	enemyVehicle = VehicleBuilder.CreateUte(
		vehiclesFolder,
		"EnemyUte_01",
		WorldConfig.Spawn.Enemy,
		Color3.fromRGB(58, 91, 122)
	)
	enemyVehicle:SetAttribute("OwnerUserId", 0)
	enemyVehicle:SetAttribute("Team", "Enemy")
	enemyVehicle:SetAttribute("DamageMultiplier", 0.2)
	enemyVehicle:SetAttribute("MaxSpeedScale", AI_MAX_SPEED_SCALE)

	local chassis = enemyVehicle.PrimaryPart
	if chassis and chassis:CanSetNetworkOwnership() then
		chassis:SetNetworkOwner(nil)
	end

	RunService.PreSimulation:Connect(updateEnemy)
end

return AIService
