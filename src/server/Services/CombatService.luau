--!strict

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local VehiclePhysics = require(ReplicatedStorage.Shared.VehiclePhysics)
local RemoteService = require(script.Parent.RemoteService)
local VehicleService = require(script.Parent.VehicleService)

local lastShotAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function getVehicleFromPart(part: Instance?): Model?
	local current = part
	while current and current ~= Workspace do
		if current:IsA("Model") and CollectionService:HasTag(current, "HoonangaVehicle") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function isPlayerDriving(player: Player, vehicle: Model): boolean
	return VehicleService.GetPlayerVehicle(player) == vehicle
		and vehicle:GetAttribute("OwnerUserId") == player.UserId
		and vehicle:GetAttribute("Destroyed") ~= true
end

local function awardKill(sourceVehicle: Model?, targetVehicle: Model)
	if not sourceVehicle or sourceVehicle == targetVehicle then
		return
	end
	if sourceVehicle:GetAttribute("Team") == targetVehicle:GetAttribute("Team") then
		return
	end

	local ownerUserId = sourceVehicle:GetAttribute("OwnerUserId")
	if typeof(ownerUserId) ~= "number" or ownerUserId <= 0 then
		return
	end

	local player = Players:GetPlayerByUserId(ownerUserId)
	if not player then
		return
	end

	local currentKills = player:GetAttribute("Kills")
	if typeof(currentKills) ~= "number" then
		currentKills = 0
	end
	local newKills = currentKills + 1
	player:SetAttribute("Kills", newKills)
	print(
		string.format(
			"[Hoonanga] %s destroyed %s (kills: %d)",
			player.Name,
			targetVehicle.Name,
			newKills
		)
	)
end

-- Shared by both run-ending paths: a violent kill (destroyVehicle) and a
-- non-violent one (strandVehicle, for running out of fuel - GDD 4.2 lists
-- "elimination, fuel loss, or voluntary extraction" as distinct ways a run
-- ends, not fuel loss folded into elimination). Both need the same
-- Destroyed flag, character-respawn trigger, and eventual cleanup; only the
-- combat one adds hull loss, an explosion, and scorch marks.
local function endRun(vehicle: Model): boolean
	if vehicle:GetAttribute("Destroyed") then
		return false
	end
	vehicle:SetAttribute("Destroyed", true)
	VehiclePhysics.Reset(vehicle)

	local seat = vehicle:FindFirstChild("DriverSeat")
	if seat and seat:IsA("VehicleSeat") and seat.Occupant then
		seat.Occupant.Health = 0
	end
	local ownerUserId = vehicle:GetAttribute("OwnerUserId")
	if typeof(ownerUserId) == "number" and ownerUserId > 0 then
		local owner = Players:GetPlayerByUserId(ownerUserId)
		local character = if owner then owner.Character else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			humanoid.Health = 0
		end
	end

	Debris:AddItem(vehicle, 8)
	return true
end

local function destroyVehicle(vehicle: Model, sourceVehicle: Model?)
	if not endRun(vehicle) then
		return
	end

	vehicle:SetAttribute("Hull", 0)
	warn(string.format("[Hoonanga] Destroying %s", vehicle.Name))
	awardKill(sourceVehicle, vehicle)

	local chassis = vehicle.PrimaryPart
	if chassis then
		local explosion = Instance.new("Explosion")
		explosion.BlastPressure = 0
		explosion.BlastRadius = 8
		explosion.DestroyJointRadiusPercent = 0
		explosion.Position = chassis.Position
		explosion.Parent = Workspace

		chassis.AssemblyLinearVelocity += Vector3.new(0, 24, 0)
		chassis.AssemblyAngularVelocity += Vector3.new(1.8, 0.8, -1.2)
	end

	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Color = descendant.Color:Lerp(Color3.fromRGB(35, 30, 27), 0.55)
		end
	end
end

local function strandVehicle(vehicle: Model)
	if not endRun(vehicle) then
		return
	end
	warn(string.format("[Hoonanga] %s ran out of fuel and was stranded", vehicle.Name))
end

local function applyHullDamage(vehicle: Model, damage: number, sourceVehicle: Model?)
	if vehicle:GetAttribute("Destroyed") then
		return
	end

	local hull = vehicle:GetAttribute("Hull")
	if typeof(hull) ~= "number" then
		return
	end

	hull = math.max(0, hull - damage)
	vehicle:SetAttribute("Hull", hull)
	if hull <= 0 then
		destroyVehicle(vehicle, sourceVehicle)
	end
end

-- Personnel health is tracked on the vehicle rather than a real Humanoid:
-- the AI enemy has no character at all, and the player's own character is
-- welded into the seat with CanQuery disabled, so neither can be hit
-- directly by a raycast. Milestone 1 has no convoy/control-transfer system
-- to hand off to (that's Milestone 4), so per GDD 11.6 a killed operator
-- eliminates the single-vehicle "convoy" the same way hull loss does.
local function applyOperatorDamage(vehicle: Model, damage: number, sourceVehicle: Model?)
	if vehicle:GetAttribute("Destroyed") then
		return
	end

	local operatorHealth = vehicle:GetAttribute("OperatorHealth")
	if typeof(operatorHealth) ~= "number" then
		return
	end

	operatorHealth = math.max(0, operatorHealth - damage)
	vehicle:SetAttribute("OperatorHealth", operatorHealth)
	if operatorHealth <= 0 then
		destroyVehicle(vehicle, sourceVehicle)
	end
end

local CombatService = {}

function CombatService.ApplyHullDamage(vehicle: Model, damage: number, sourceVehicle: Model?)
	if damage <= 0 or damage ~= damage then
		return
	end
	applyHullDamage(vehicle, damage, sourceVehicle)
end

function CombatService.ApplyOperatorDamage(vehicle: Model, damage: number, sourceVehicle: Model?)
	if damage <= 0 or damage ~= damage then
		return
	end
	applyOperatorDamage(vehicle, damage, sourceVehicle)
end

function CombatService.DestroyVehicle(vehicle: Model, sourceVehicle: Model?)
	destroyVehicle(vehicle, sourceVehicle)
end

function CombatService.StrandVehicle(vehicle: Model)
	strandVehicle(vehicle)
end

local function fireRay(
	vehicle: Model,
	origin: Vector3,
	direction: Vector3,
	config: WeaponConfig.WeaponConfig
)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { vehicle }
	params.IgnoreWater = false

	local result = Workspace:Raycast(origin, direction * config.Range, params)
	local endPosition = origin + direction * config.Range
	if result then
		endPosition = result.Position
		local targetVehicle = getVehicleFromPart(result.Instance)
		if targetVehicle and targetVehicle ~= vehicle then
			local sameTeam = targetVehicle:GetAttribute("Team") == vehicle:GetAttribute("Team")
			if not sameTeam then
				local damageMultiplier = vehicle:GetAttribute("DamageMultiplier")
				if typeof(damageMultiplier) ~= "number" then
					damageMultiplier = 1
				end
				if result.Instance.Name == "PersonnelHitbox" then
					applyOperatorDamage(
						targetVehicle,
						config.PersonnelDamage * damageMultiplier,
						vehicle
					)
				else
					applyHullDamage(targetVehicle, config.Damage * damageMultiplier, vehicle)
				end
			end
		end
	end

	RemoteService.Get("WeaponFired"):FireAllClients(origin, endPosition)
end

function CombatService.TryFire(vehicle: Model, desiredDirection: Vector3): boolean
	if vehicle:GetAttribute("Destroyed") or desiredDirection.Magnitude < 0.9 then
		return false
	end

	local chassis = vehicle.PrimaryPart
	if not chassis then
		return false
	end

	local turretConfig = WeaponConfig.MachineGun
	local now = Workspace:GetServerTimeNow()
	local lastShot = lastShotAt[vehicle] or 0
	if now - lastShot < turretConfig.FireInterval * 0.9 then
		return false
	end

	local ammo = vehicle:GetAttribute("Ammo")
	if typeof(ammo) ~= "number" or ammo <= 0 or vehicle:GetAttribute("Reloading") then
		return false
	end

	local turretMuzzle = chassis:FindFirstChild("TurretMuzzleAttachment")
	if not turretMuzzle or not turretMuzzle:IsA("Attachment") then
		return false
	end

	local aimDirection = desiredDirection.Unit
	local forwardAlignment = aimDirection:Dot(chassis.CFrame.LookVector)
	local forwardGunActive = forwardAlignment
			>= math.cos(math.rad(WeaponConfig.ForwardGunConeDegrees))
		and ammo >= 2

	lastShotAt[vehicle] = now
	vehicle:SetAttribute("Ammo", ammo - (if forwardGunActive then 2 else 1))
	fireRay(vehicle, turretMuzzle.WorldPosition, aimDirection, turretConfig)

	if forwardGunActive then
		local forwardMuzzle = chassis:FindFirstChild("ForwardMuzzleAttachment")
		if forwardMuzzle and forwardMuzzle:IsA("Attachment") then
			fireRay(
				vehicle,
				forwardMuzzle.WorldPosition,
				chassis.CFrame.LookVector,
				WeaponConfig.ForwardGun
			)
		end
	end

	return true
end

function CombatService.Reload(vehicle: Model)
	if vehicle:GetAttribute("Destroyed") or vehicle:GetAttribute("Reloading") then
		return
	end

	local config = WeaponConfig.MachineGun
	local ammo = vehicle:GetAttribute("Ammo")
	local reserve = vehicle:GetAttribute("ReserveAmmo")
	if typeof(ammo) ~= "number" or typeof(reserve) ~= "number" then
		return
	end
	if ammo >= config.MagazineSize or reserve <= 0 then
		return
	end

	vehicle:SetAttribute("Reloading", true)
	task.delay(config.ReloadTime, function()
		if not vehicle.Parent or vehicle:GetAttribute("Destroyed") then
			return
		end

		local currentAmmo = vehicle:GetAttribute("Ammo")
		local currentReserve = vehicle:GetAttribute("ReserveAmmo")
		if typeof(currentAmmo) ~= "number" or typeof(currentReserve) ~= "number" then
			return
		end

		local required = config.MagazineSize - currentAmmo
		local loaded = math.min(required, currentReserve)
		vehicle:SetAttribute("Ammo", currentAmmo + loaded)
		vehicle:SetAttribute("ReserveAmmo", currentReserve - loaded)
		vehicle:SetAttribute("Reloading", false)
	end)
end

function CombatService.Start()
	RemoteService.Get("FireWeapon").OnServerEvent:Connect(function(player, direction)
		if typeof(direction) ~= "Vector3" then
			return
		end

		local vehicle = VehicleService.GetPlayerVehicle(player)
		if vehicle and isPlayerDriving(player, vehicle) then
			CombatService.TryFire(vehicle, direction)
		end
	end)

	RemoteService.Get("ReloadWeapon").OnServerEvent:Connect(function(player)
		local vehicle = VehicleService.GetPlayerVehicle(player)
		if vehicle and isPlayerDriving(player, vehicle) then
			CombatService.Reload(vehicle)
		end
	end)
end

return CombatService
