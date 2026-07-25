--!strict

-- The damage authority (GDD 11.1). Every point of damage in the game arrives
-- here through one of the five channels, whoever caused it: bullets, blast,
-- fire ticks, ramming and terrain all converge on ApplyDamage.
--
-- Deliberately at the bottom of the service dependency graph. It requires no
-- weapon, projectile or fire code, which is what lets WeaponService,
-- ProjectileService, FireService and CollisionDamageService all require *it*
-- without a cycle.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VehiclePhysics = require(ReplicatedStorage.Shared.VehiclePhysics)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)

local CombatService = {}

local function requireNumber(vehicle: Model, attribute: string): number
	local value = vehicle:GetAttribute(attribute)
	if typeof(value) ~= "number" then
		error(string.format("%s has no numeric %s attribute", vehicle:GetFullName(), attribute), 3)
	end
	return value
end

function CombatService.GetVehicleFromPart(part: Instance?): Model?
	local current = part
	while current and current ~= Workspace do
		if current:IsA("Model") and CollectionService:HasTag(current, "HoonangaVehicle") then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- GDD 11.2 hit regions. Parts declare what they are with a HitRegion
-- attribute rather than being matched by name, so a Creator Store body part
-- or a future engine/fuel-tank region is a data change and not a new string
-- comparison in the weapon code.
function CombatService.GetHitRegion(part: Instance?): string
	if not part then
		return "Hull"
	end
	local region = part:GetAttribute("HitRegion")
	if typeof(region) == "string" then
		return region
	end
	return "Hull"
end

-- GDD 24.3 friendly-convoy immunity. A nil source is the world itself
-- (terrain, falls, boundary impacts), which is hostile to everyone.
function CombatService.IsHostile(source: Model?, target: Model): boolean
	if not source then
		return true
	end
	if source == target then
		return false
	end
	return source:GetAttribute("Team") ~= target:GetAttribute("Team")
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

	local hull = math.max(0, requireNumber(vehicle, "Hull") - damage)
	vehicle:SetAttribute("Hull", hull)
	if hull <= 0 then
		destroyVehicle(vehicle, sourceVehicle)
	end
end

-- Personnel health is tracked on the vehicle rather than a real Humanoid:
-- the AI enemy has no character at all, and the player's own character is
-- welded into the seat with CanQuery disabled, so neither can be hit
-- directly by a raycast. There is no convoy/control-transfer system to hand
-- off to yet (that is Milestone 4), so per GDD 11.6 a killed operator
-- eliminates the single-vehicle "convoy" the same way hull loss does.
local function applyOperatorDamage(vehicle: Model, damage: number, sourceVehicle: Model?)
	if vehicle:GetAttribute("Destroyed") then
		return
	end

	local operatorHealth = math.max(0, requireNumber(vehicle, "OperatorHealth") - damage)
	vehicle:SetAttribute("OperatorHealth", operatorHealth)
	if operatorHealth <= 0 then
		destroyVehicle(vehicle, sourceVehicle)
	end
end

-- GDD 11.1 impact channel. Ram equipment modifies both the damage dealt and
-- the damage received, so a bull-barred ute wins an exchange it would
-- otherwise trade evenly - which is what makes ramming an equipment choice
-- rather than just a consequence of steering badly.
local function applyImpactDamage(vehicle: Model, damage: number, sourceVehicle: Model?)
	local dealtMultiplier = if sourceVehicle
		then requireNumber(sourceVehicle, "RamDealtMultiplier")
		else 1
	local receivedMultiplier = requireNumber(vehicle, "RamReceivedMultiplier")
	applyHullDamage(vehicle, damage * dealtMultiplier * receivedMultiplier, sourceVehicle)
end

function CombatService.ApplyDamage(
	vehicle: Model,
	channel: WeaponConfig.DamageChannel,
	amount: number,
	sourceVehicle: Model?
)
	-- Rejects NaN as well as non-positive damage: NaN propagates silently
	-- through the hull arithmetic and leaves a vehicle that can never die.
	if not (amount > 0) then
		return
	end

	if channel == "Hull" then
		applyHullDamage(vehicle, amount, sourceVehicle)
	elseif channel == "Personnel" then
		applyOperatorDamage(vehicle, amount, sourceVehicle)
	elseif channel == "Impact" then
		applyImpactDamage(vehicle, amount, sourceVehicle)
	elseif channel == "Fire" then
		-- Fire is not a pool of its own: FireService splits a tick into hull
		-- and personnel portions and sends each through this function.
		error("Fire damage must be applied as its Hull and Personnel components", 2)
	elseif channel == "Terrain" then
		applyHullDamage(vehicle, amount, nil)
	else
		error(string.format("Unknown damage channel %q", tostring(channel)), 2)
	end
end

function CombatService.ApplyHullDamage(vehicle: Model, damage: number, sourceVehicle: Model?)
	CombatService.ApplyDamage(vehicle, "Hull", damage, sourceVehicle)
end

function CombatService.ApplyOperatorDamage(vehicle: Model, damage: number, sourceVehicle: Model?)
	CombatService.ApplyDamage(vehicle, "Personnel", damage, sourceVehicle)
end

function CombatService.ApplyImpactDamage(vehicle: Model, damage: number, sourceVehicle: Model?)
	CombatService.ApplyDamage(vehicle, "Impact", damage, sourceVehicle)
end

-- Routes a weapon hit to the channel the hit region implies. Returns the
-- damage actually dealt so callers can decide whether the shot "connected"
-- for feedback purposes - a pistol round on a hull returns 0, which is the
-- weapon working as designed rather than a miss.
function CombatService.ApplyWeaponHit(
	target: Model,
	hitRegion: string,
	config: WeaponConfig.WeaponConfig,
	sourceVehicle: Model?,
	damageMultiplier: number
): number
	if not CombatService.IsHostile(sourceVehicle, target) then
		return 0
	end

	if hitRegion == "Personnel" then
		local damage = config.PersonnelDamage * damageMultiplier
		CombatService.ApplyDamage(target, "Personnel", damage, sourceVehicle)
		return damage
	end

	local damage = config.HullDamage * damageMultiplier
	CombatService.ApplyDamage(target, "Hull", damage, sourceVehicle)
	return damage
end

-- GDD 12.3. Repairs restore hull and never resurrect a destroyed vehicle.
function CombatService.Repair(vehicle: Model, amount: number): number
	if vehicle:GetAttribute("Destroyed") then
		return 0
	end

	local hull = requireNumber(vehicle, "Hull")
	local maxHull = requireNumber(vehicle, "MaxHull")
	local restored = math.min(amount, maxHull - hull)
	if restored <= 0 then
		return 0
	end
	vehicle:SetAttribute("Hull", hull + restored)
	return restored
end

function CombatService.DestroyVehicle(vehicle: Model, sourceVehicle: Model?)
	destroyVehicle(vehicle, sourceVehicle)
end

function CombatService.StrandVehicle(vehicle: Model)
	strandVehicle(vehicle)
end

return CombatService
