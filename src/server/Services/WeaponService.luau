--!strict

-- Server-authoritative firing (GDD 14.3). The client sends an aim direction
-- and nothing else: it never says which weapon fired, how much ammunition it
-- used, what it hit, or how much damage it did. Every one of those is decided
-- here from replicated vehicle state.
--
-- Five gates stand between a fire request and a shot, and all five are
-- covered by scripts/combat_test.luau:
--   1. the requester is actually driving that vehicle (CombatService.Start)
--   2. the weapon's fire interval has elapsed
--   3. the weapon has ammunition loaded and is not reloading
--   4. the muzzle is not obstructed
--   5. the aim is clamped into the mount's traverse range

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponState = require(ReplicatedStorage.Shared.WeaponState)
local CombatService = require(script.Parent.CombatService)
local FireService = require(script.Parent.FireService)
local ProjectileService = require(script.Parent.ProjectileService)
local RemoteService = require(script.Parent.RemoteService)
local VehicleService = require(script.Parent.VehicleService)

-- Keyed per weapon so switching weapons cannot be used to sidestep a fire
-- interval, and so a slow rocket does not share a cooldown with the machine
-- gun.
local lastShotAt: { [Model]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any

local spreadRandom = Random.new()

local WeaponService = {}

local function requireNumber(vehicle: Model, attribute: string): number
	local value = vehicle:GetAttribute(attribute)
	if typeof(value) ~= "number" then
		error(string.format("%s has no numeric %s attribute", vehicle:GetFullName(), attribute), 3)
	end
	return value
end

local function getLastShot(vehicle: Model, weaponId: string): number
	local perWeapon = lastShotAt[vehicle]
	if not perWeapon then
		return 0
	end
	return perWeapon[weaponId] or 0
end

local function setLastShot(vehicle: Model, weaponId: string, now: number)
	local perWeapon = lastShotAt[vehicle]
	if not perWeapon then
		perWeapon = {}
		lastShotAt[vehicle] = perWeapon
	end
	perWeapon[weaponId] = now
end

local function muzzleAttachment(vehicle: Model, name: string): Attachment
	local chassis = vehicle.PrimaryPart
	if not chassis then
		error(string.format("%s has no chassis", vehicle:GetFullName()), 2)
	end
	local attachment = chassis:FindFirstChild(name)
	if not attachment or not attachment:IsA("Attachment") then
		error(string.format("%s has no %s", vehicle:GetFullName(), name), 2)
	end
	return attachment
end

-- GDD 11.3 muzzle obstruction. Tested by raycasting from the chassis centre
-- out to the muzzle: if something that is not part of this vehicle sits in
-- between, the muzzle is buried in it (a canyon wall, a boulder, the deck of
-- a highway you just nosed into) and the weapon must not fire through it.
function WeaponService.IsMuzzleObstructed(vehicle: Model, muzzlePosition: Vector3): boolean
	local chassis = vehicle.PrimaryPart
	if not chassis then
		return true
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { vehicle }
	params.IgnoreWater = true

	local offset = muzzlePosition - chassis.Position
	if offset.Magnitude < 0.05 then
		return false
	end
	return Workspace:Raycast(chassis.Position, offset, params) ~= nil
end

-- GDD 11.3 turret yaw and pitch limits. Out-of-range aim is clamped to the
-- limit rather than refused, so the weapon keeps shooting where it can reach
-- while the crosshair tells the player the mount has run out of travel.
function WeaponService.ClampToTraverse(
	chassis: BasePart,
	config: WeaponConfig.WeaponConfig,
	direction: Vector3
): (Vector3, boolean)
	local localDirection = chassis.CFrame:VectorToObjectSpace(direction).Unit
	local horizontal = math.sqrt(localDirection.X ^ 2 + localDirection.Z ^ 2)
	local yaw = math.atan2(localDirection.X, -localDirection.Z)
	local pitch = math.atan2(localDirection.Y, horizontal)

	local yawLimit = math.rad(config.TraverseYawDegrees)
	local pitchLimit = math.rad(config.TraversePitchDegrees)
	local clampedYaw = math.clamp(yaw, -yawLimit, yawLimit)
	local clampedPitch = math.clamp(pitch, -pitchLimit, pitchLimit)
	if clampedYaw == yaw and clampedPitch == pitch then
		return direction.Unit, false
	end

	local cosPitch = math.cos(clampedPitch)
	local clampedLocal = Vector3.new(
		math.sin(clampedYaw) * cosPitch,
		math.sin(clampedPitch),
		-math.cos(clampedYaw) * cosPitch
	)
	return chassis.CFrame:VectorToWorldSpace(clampedLocal).Unit, true
end

local function applySpread(direction: Vector3, spreadDegrees: number): Vector3
	if spreadDegrees <= 0 then
		return direction
	end
	local angle = math.rad(spreadDegrees) * spreadRandom:NextNumber()
	local roll = spreadRandom:NextNumber() * math.pi * 2
	local reference = if math.abs(direction.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local right = direction:Cross(reference).Unit
	local up = right:Cross(direction).Unit
	local offset = (right * math.cos(roll) + up * math.sin(roll)) * math.tan(angle)
	return (direction + offset).Unit
end

local function ammoAvailable(vehicle: Model, config: WeaponConfig.WeaponConfig): boolean
	if WeaponState.IsReloading(vehicle, config) then
		return false
	end
	return WeaponState.GetLoaded(vehicle, config) >= config.AmmoPerShot
end

local function consumeAmmo(vehicle: Model, config: WeaponConfig.WeaponConfig, shots: number)
	if config.MagazineSize <= 0 then
		WeaponState.SetPool(
			vehicle,
			config.AmmoPool,
			WeaponState.GetPool(vehicle, config.AmmoPool) - config.AmmoPerShot * shots
		)
		return
	end

	local attribute = WeaponState.MagazineAttribute(config.Id)
	vehicle:SetAttribute(
		attribute,
		math.max(0, requireNumber(vehicle, attribute) - config.AmmoPerShot * shots)
	)
end

local function fireRay(
	vehicle: Model,
	config: WeaponConfig.WeaponConfig,
	origin: Vector3,
	direction: Vector3,
	damageMultiplier: number
): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { vehicle }
	params.IgnoreWater = false

	local result = Workspace:Raycast(origin, direction * config.Range, params)
	if not result then
		return origin + direction * config.Range
	end

	local target = CombatService.GetVehicleFromPart(result.Instance)
	if target and target ~= vehicle then
		local region = CombatService.GetHitRegion(result.Instance)
		CombatService.ApplyWeaponHit(target, region, config, vehicle, damageMultiplier)
		if config.HeatPerHit > 0 then
			FireService.AddHeat(target, config.HeatPerHit, vehicle)
		end
	end
	return result.Position
end

local function broadcastShot(
	config: WeaponConfig.WeaponConfig,
	origin: Vector3,
	endPosition: Vector3
)
	RemoteService.Get("WeaponFired"):FireAllClients(config.Id, origin, endPosition)
end

local function fireHitscan(
	vehicle: Model,
	config: WeaponConfig.WeaponConfig,
	origin: Vector3,
	direction: Vector3,
	damageMultiplier: number
)
	local endPosition = fireRay(
		vehicle,
		config,
		origin,
		applySpread(direction, config.SpreadDegrees),
		damageMultiplier
	)
	broadcastShot(config, origin, endPosition)
end

local function fireCone(
	vehicle: Model,
	config: WeaponConfig.WeaponConfig,
	origin: Vector3,
	direction: Vector3,
	damageMultiplier: number
)
	local cone = config.Cone
	if not cone then
		error(string.format("Weapon %s has no cone spec", config.Id), 2)
	end

	-- Every ray in the burst is tested, so a target filling the cone takes
	-- several ticks of heat at once. That is the flamethrower's whole
	-- identity: it is weak per ray and overwhelming point-blank.
	for index = 1, cone.RayCount do
		local spread = if cone.RayCount > 1 then (index - 1) / (cone.RayCount - 1) * 2 - 1 else 0
		local roll = index * 2.399963
		local reference = if math.abs(direction.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
		local right = direction:Cross(reference).Unit
		local up = right:Cross(direction).Unit
		local angle = math.rad(cone.Degrees) * spread
		local offset = (right * math.cos(roll) + up * math.sin(roll)) * math.tan(angle)
		fireRay(vehicle, config, origin, (direction + offset).Unit, damageMultiplier)
	end

	broadcastShot(config, origin, origin + direction * config.Range)
end

-- Returns true when a shot was actually taken. Every early return is a
-- validation gate, not an error: a client that spams fire simply gets false.
function WeaponService.TryFire(vehicle: Model, desiredDirection: Vector3): boolean
	if vehicle:GetAttribute("Destroyed") or desiredDirection.Magnitude < 0.9 then
		return false
	end

	local chassis = vehicle.PrimaryPart
	if not chassis then
		return false
	end

	local config = WeaponState.GetActiveWeapon(vehicle)
	local now = Workspace:GetServerTimeNow()
	-- The 0.9 tolerance absorbs the client's own timing jitter without
	-- letting it fire meaningfully faster than the weapon allows.
	if now - getLastShot(vehicle, config.Id) < config.FireInterval * 0.9 then
		return false
	end

	if not ammoAvailable(vehicle, config) then
		return false
	end

	local muzzle = muzzleAttachment(vehicle, "TurretMuzzleAttachment")
	local blocked = WeaponService.IsMuzzleObstructed(vehicle, muzzle.WorldPosition)
	vehicle:SetAttribute("MuzzleBlocked", blocked)
	if blocked then
		return false
	end

	local aimDirection, outOfTraverse =
		WeaponService.ClampToTraverse(chassis, config, desiredDirection.Unit)
	vehicle:SetAttribute("AimOutOfTraverse", outOfTraverse)

	local damageMultiplier = requireNumber(vehicle, "DamageMultiplier")
	setLastShot(vehicle, config.Id, now)
	consumeAmmo(vehicle, config, 1)

	if config.Kind == "Hitscan" then
		fireHitscan(vehicle, config, muzzle.WorldPosition, aimDirection, damageMultiplier)

		-- The forward gun rides along with the machine gun when the aim is
		-- close to straight ahead. It draws from the same bullet pool, so
		-- charging head-on costs ammunition as well as risk.
		if config.Id == "MachineGun" then
			local alignment = aimDirection:Dot(chassis.CFrame.LookVector)
			local forwardGun = WeaponState.GetWeapon("ForwardGun")
			if
				alignment >= math.cos(math.rad(WeaponConfig.ForwardGunConeDegrees))
				and WeaponState.GetPool(vehicle, forwardGun.AmmoPool) >= forwardGun.AmmoPerShot
			then
				consumeAmmo(vehicle, forwardGun, 1)
				local forwardMuzzle = muzzleAttachment(vehicle, "ForwardMuzzleAttachment")
				if not WeaponService.IsMuzzleObstructed(vehicle, forwardMuzzle.WorldPosition) then
					fireHitscan(
						vehicle,
						forwardGun,
						forwardMuzzle.WorldPosition,
						chassis.CFrame.LookVector,
						damageMultiplier
					)
				end
			end
		end
	elseif config.Kind == "Cone" then
		fireCone(vehicle, config, muzzle.WorldPosition, aimDirection, damageMultiplier)
	elseif config.Kind == "Rocket" or config.Kind == "Thrown" then
		-- Launched a little ahead of the muzzle so the projectile's own first
		-- raycast step cannot start inside the turret geometry.
		local launchOrigin = muzzle.WorldPosition + aimDirection * 2
		local launchDirection = if config.Kind == "Thrown"
			then (aimDirection + Vector3.new(0, 0.28, 0)).Unit
			else aimDirection
		ProjectileService.Launch(vehicle, config, launchOrigin, launchDirection, damageMultiplier)
		broadcastShot(config, muzzle.WorldPosition, launchOrigin)
	else
		error(string.format("Weapon %s has unhandled kind %q", config.Id, config.Kind), 2)
	end

	return true
end

function WeaponService.SelectWeapon(vehicle: Model, weaponId: string): boolean
	if not WeaponState.IsInLoadout(weaponId) then
		return false
	end
	if vehicle:GetAttribute("Destroyed") then
		return false
	end
	vehicle:SetAttribute("ActiveWeapon", weaponId)
	return true
end

function WeaponService.Reload(vehicle: Model)
	if vehicle:GetAttribute("Destroyed") then
		return
	end

	local config = WeaponState.GetActiveWeapon(vehicle)
	if config.MagazineSize <= 0 or WeaponState.IsReloading(vehicle, config) then
		return
	end

	local magazineAttribute = WeaponState.MagazineAttribute(config.Id)
	local reloadingAttribute = WeaponState.ReloadingAttribute(config.Id)
	local magazine = requireNumber(vehicle, magazineAttribute)
	local pool = WeaponState.GetPool(vehicle, config.AmmoPool)
	if magazine >= config.MagazineSize or pool <= 0 then
		return
	end

	vehicle:SetAttribute(reloadingAttribute, true)
	task.delay(config.ReloadTime, function()
		if not vehicle.Parent or vehicle:GetAttribute("Destroyed") then
			return
		end

		local currentMagazine = requireNumber(vehicle, magazineAttribute)
		local currentPool = WeaponState.GetPool(vehicle, config.AmmoPool)
		local loaded = math.min(config.MagazineSize - currentMagazine, currentPool)
		vehicle:SetAttribute(magazineAttribute, currentMagazine + loaded)
		WeaponState.SetPool(vehicle, config.AmmoPool, currentPool - loaded)
		vehicle:SetAttribute(reloadingAttribute, false)
	end)
end

-- Driving over a crate loads the magazines that feed from that pool as well
-- as filling the reserve. Without this the reserve went up but the number the
-- HUD leads with - rounds actually loaded - sat pinned at the magazine size
-- until you pressed reload, which reads as "ammo pickups stop working".
-- It is the crate being loaded on rather than a free reload: a weapon already
-- part-way through a reload is left alone.
local function topUpMagazines(vehicle: Model, pool: string)
	for _, config in WeaponConfig.Weapons do
		if
			config.MagazineSize <= 0
			or config.AmmoPool ~= pool
			or WeaponState.IsReloading(vehicle, config)
		then
			continue
		end
		local attribute = WeaponState.MagazineAttribute(config.Id)
		local magazine = requireNumber(vehicle, attribute)
		local available = WeaponState.GetPool(vehicle, pool)
		local loaded = math.min(config.MagazineSize - magazine, available)
		if loaded > 0 then
			vehicle:SetAttribute(attribute, magazine + loaded)
			WeaponState.SetPool(vehicle, pool, available - loaded)
		end
	end
end

-- Used by ammunition pickups (GDD 12.2). Returns how much was actually taken
-- on, so a pickup can refuse to be consumed by a full vehicle.
function WeaponService.AddAmmo(vehicle: Model, pool: string, amount: number): number
	local poolConfig = WeaponConfig.AmmoPools[pool]
	if not poolConfig then
		error(string.format("Unknown ammo pool %q", pool), 2)
	end

	-- Magazines first: a vehicle sitting on a full reserve with an empty
	-- magazine has somewhere to put the crate, and refusing it there was the
	-- other half of ammunition appearing to cap out.
	topUpMagazines(vehicle, pool)

	local current = WeaponState.GetPool(vehicle, pool)
	local added = math.min(amount, poolConfig.Max - current)
	if added <= 0 then
		return 0
	end
	WeaponState.SetPool(vehicle, pool, current + added)
	topUpMagazines(vehicle, pool)
	return added
end

function WeaponService.Start()
	RemoteService.Get("FireWeapon").OnServerEvent:Connect(function(player, direction)
		if typeof(direction) ~= "Vector3" then
			return
		end

		local vehicle = VehicleService.GetPlayerVehicle(player)
		if
			vehicle
			and vehicle:GetAttribute("MatchInputEnabled") == true
			and VehicleService.IsPlayerDriving(player, vehicle)
		then
			WeaponService.TryFire(vehicle, direction)
		end
	end)

	RemoteService.Get("ReloadWeapon").OnServerEvent:Connect(function(player)
		local vehicle = VehicleService.GetPlayerVehicle(player)
		if
			vehicle
			and vehicle:GetAttribute("MatchInputEnabled") == true
			and VehicleService.IsPlayerDriving(player, vehicle)
		then
			WeaponService.Reload(vehicle)
		end
	end)

	RemoteService.Get("SelectWeapon").OnServerEvent:Connect(function(player, weaponId)
		if typeof(weaponId) ~= "string" then
			return
		end

		local vehicle = VehicleService.GetPlayerVehicle(player)
		if
			vehicle
			and vehicle:GetAttribute("MatchInputEnabled") == true
			and VehicleService.IsPlayerDriving(player, vehicle)
		then
			WeaponService.SelectWeapon(vehicle, weaponId)
		end
	end)
end

return WeaponService
