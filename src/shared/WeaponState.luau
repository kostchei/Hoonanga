--!strict

-- Weapon and ammunition state lives in vehicle attributes so it replicates to
-- every client for free and can be inspected in the explorer during a
-- playtest. This module is the single place that knows the attribute names,
-- so the server and the HUD cannot drift apart on spelling.
--
-- Everything here errors rather than defaulting when state is missing: an
-- absent ammo pool means the vehicle was built wrong, and silently reading it
-- as zero would present as "weapon mysteriously never fires" a long way from
-- the actual bug.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)

local WeaponState = {}

function WeaponState.MagazineAttribute(weaponId: string): string
	return "Mag_" .. weaponId
end

function WeaponState.PoolAttribute(pool: string): string
	return "Pool_" .. pool
end

function WeaponState.ReloadingAttribute(weaponId: string): string
	return "Reloading_" .. weaponId
end

function WeaponState.GetWeapon(weaponId: string): WeaponConfig.WeaponConfig
	local config = WeaponConfig.Weapons[weaponId]
	if not config then
		error(string.format("Unknown weapon %q", weaponId), 2)
	end
	return config
end

function WeaponState.IsInLoadout(weaponId: string): boolean
	return table.find(WeaponConfig.Loadout, weaponId) ~= nil
end

function WeaponState.GetActiveWeapon(vehicle: Model): WeaponConfig.WeaponConfig
	local active = vehicle:GetAttribute("ActiveWeapon")
	if typeof(active) ~= "string" then
		error(string.format("%s has no ActiveWeapon attribute", vehicle:GetFullName()), 2)
	end
	return WeaponState.GetWeapon(active)
end

local function readNumber(vehicle: Model, attribute: string): number
	local value = vehicle:GetAttribute(attribute)
	if typeof(value) ~= "number" then
		error(string.format("%s has no numeric %s attribute", vehicle:GetFullName(), attribute), 3)
	end
	return value
end

function WeaponState.GetPool(vehicle: Model, pool: string): number
	return readNumber(vehicle, WeaponState.PoolAttribute(pool))
end

function WeaponState.SetPool(vehicle: Model, pool: string, amount: number)
	local poolConfig = WeaponConfig.AmmoPools[pool]
	if not poolConfig then
		error(string.format("Unknown ammo pool %q", pool), 2)
	end
	vehicle:SetAttribute(WeaponState.PoolAttribute(pool), math.clamp(amount, 0, poolConfig.Max))
end

-- Magazine-fed weapons report their magazine; pool-fed weapons report the pool
-- itself, so "how many shots do I have loaded" has one answer for every
-- weapon and the HUD does not need to branch.
function WeaponState.GetLoaded(vehicle: Model, config: WeaponConfig.WeaponConfig): number
	if config.MagazineSize <= 0 then
		return WeaponState.GetPool(vehicle, config.AmmoPool)
	end
	return readNumber(vehicle, WeaponState.MagazineAttribute(config.Id))
end

function WeaponState.IsReloading(vehicle: Model, config: WeaponConfig.WeaponConfig): boolean
	if config.MagazineSize <= 0 then
		return false
	end
	return vehicle:GetAttribute(WeaponState.ReloadingAttribute(config.Id)) == true
end

-- Initialises every ammo attribute a vehicle needs. Called once at build time;
-- every read afterwards is allowed to assume these exist.
function WeaponState.Initialise(vehicle: Model)
	vehicle:SetAttribute("ActiveWeapon", WeaponConfig.DefaultWeapon)

	for pool, poolConfig in WeaponConfig.AmmoPools do
		vehicle:SetAttribute(WeaponState.PoolAttribute(pool), poolConfig.Initial)
	end

	for _, config in WeaponConfig.Weapons do
		if config.MagazineSize > 0 then
			vehicle:SetAttribute(WeaponState.MagazineAttribute(config.Id), config.MagazineSize)
			vehicle:SetAttribute(WeaponState.ReloadingAttribute(config.Id), false)
			-- The magazine is loaded from the pool at build time so the
			-- displayed reserve matches what the vehicle can actually shoot.
			WeaponState.SetPool(
				vehicle,
				config.AmmoPool,
				WeaponState.GetPool(vehicle, config.AmmoPool) - config.MagazineSize
			)
		end
	end
end

return WeaponState
