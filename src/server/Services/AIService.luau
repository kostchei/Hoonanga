--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VehiclePhysics = require(ReplicatedStorage.Shared.VehiclePhysics)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local CombatService = require(script.Parent.CombatService)
local VehicleBuilder = require(script.Parent.VehicleBuilder)
local VehicleService = require(script.Parent.VehicleService)

local enemyVehicle: Model? = nil
local lastFireAttempt = 0
local AI_FIRE_INTERVAL = 0.55

local function targetVehicle(): Model?
	for _, player in Players:GetPlayers() do
		local vehicle = VehicleService.GetPlayerVehicle(player)
		if vehicle and vehicle.Parent and not vehicle:GetAttribute("Destroyed") then
			return vehicle
		end
	end
	return nil
end

local function calculateSteering(chassis: BasePart, target: Model?): number
	local desiredX = 10
	if target and target.PrimaryPart then
		local separation = target.PrimaryPart.Position.Z - chassis.Position.Z
		if math.abs(separation) < 70 then
			desiredX = if target.PrimaryPart.Position.X >= chassis.Position.X then -12 else 12
		end
	end

	local lookAhead = Vector3.new(desiredX, chassis.Position.Y, chassis.Position.Z - 90)
	local localTarget = chassis.CFrame:PointToObjectSpace(lookAhead)
	return math.clamp(localTarget.X / 18, -1, 1)
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
	VehiclePhysics.Step(vehicle, {
		Throttle = 0.82,
		Steer = calculateSteering(chassis, target),
		Handbrake = false,
	}, deltaTime)

	if target and target.PrimaryPart then
		local muzzle = chassis:FindFirstChild("TurretMuzzleAttachment")
		if muzzle and muzzle:IsA("Attachment") then
			local now = Workspace:GetServerTimeNow()
			if now - lastFireAttempt >= AI_FIRE_INTERVAL then
				lastFireAttempt = now
				local predictedPosition = target.PrimaryPart.Position
					+ target.PrimaryPart.AssemblyLinearVelocity * 0.08
				local aimError =
					Vector3.new(math.noise(now * 0.7) * 7, math.noise(now * 0.8 + 10) * 4, 0)
				CombatService.TryFire(vehicle, predictedPosition + aimError - muzzle.WorldPosition)
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

	local chassis = enemyVehicle.PrimaryPart
	if chassis and chassis:CanSetNetworkOwnership() then
		chassis:SetNetworkOwner(nil)
	end

	RunService.PreSimulation:Connect(updateEnemy)
end

return AIService
