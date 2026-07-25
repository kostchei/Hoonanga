--!strict

-- GDD 11.4. Every weapon is one entry in this table; CombatService dispatches
-- on Kind rather than knowing any weapon by name, so adding a weapon is a
-- data change plus (at most) a new Kind handler.
--
-- The five weapons plus ramming are GDD 21's content target for weapons.
-- Ramming is deliberately absent here: it is not an inventory weapon and has
-- no ammunition, fire rate or muzzle, so it lives entirely in
-- CollisionDamageService.

-- GDD 11.1. Fire is not applied directly through this channel: FireService
-- splits each burn tick into its Hull and Personnel components, because a
-- fire that damages "fire health" would need a third health pool nothing else
-- can read.
export type DamageChannel = "Hull" | "Personnel" | "Fire" | "Impact" | "Terrain"

-- Hitscan  - instant ray (machine gun, forward gun, pistol)
-- Cone     - a spread of short rays tested every shot (flamethrower)
-- Rocket   - fast flat-flying projectile that detonates on impact
-- Thrown   - ballistic projectile that leaves a fire patch where it lands
export type WeaponKind = "Hitscan" | "Cone" | "Rocket" | "Thrown"

export type AmmoPool = "Bullets" | "Rockets" | "FlameFuel" | "Throwables"

export type ProjectileSpec = {
	Speed: number,
	Gravity: number,
	Lifetime: number,
	BlastRadius: number,
	BlastHullDamage: number,
	BlastPersonnelDamage: number,
	BlastHeat: number,
	-- GDD 24.3 "explosion force limits": the hard ceiling on the speed change
	-- a single blast may impart. Without it a rocket landing under a chassis
	-- launches it into orbit, which is both unreadable and a physics hazard.
	MaxImpulseSpeed: number,
}

export type ConeSpec = {
	Degrees: number,
	RayCount: number,
}

export type FirePatchSpec = {
	Radius: number,
	Duration: number,
	HeatPerSecond: number,
}

export type WeaponConfig = {
	Id: string,
	DisplayName: string,
	Kind: WeaponKind,
	AmmoPool: AmmoPool,
	AmmoPerShot: number,
	-- 0 means the weapon feeds straight from its pool and never reloads.
	MagazineSize: number,
	ReloadTime: number,
	FireInterval: number,
	Range: number,
	SpreadDegrees: number,
	Automatic: boolean,
	HullDamage: number,
	PersonnelDamage: number,
	HeatPerHit: number,
	-- GDD 11.3 mounted aiming. Yaw is measured off the chassis forward axis,
	-- pitch off the chassis horizontal plane. Aim outside these is clamped
	-- back to the limit rather than rejected, and the crosshair is told.
	TraverseYawDegrees: number,
	TraversePitchDegrees: number,
	Projectile: ProjectileSpec?,
	Cone: ConeSpec?,
	FirePatch: FirePatchSpec?,
}

-- Baseline weapon: the one you always have and mostly use. Moderate hull
-- damage, strong on a direct personnel hit.
local machineGun: WeaponConfig = {
	Id = "MachineGun",
	DisplayName = "MACHINE GUN",
	Kind = "Hitscan",
	AmmoPool = "Bullets",
	AmmoPerShot = 1,
	MagazineSize = 80,
	ReloadTime = 2.4,
	FireInterval = 0.1,
	Range = 650,
	SpreadDegrees = 1.1,
	Automatic = true,
	HullDamage = 4,
	PersonnelDamage = 22,
	HeatPerHit = 0,
	TraverseYawDegrees = 170,
	TraversePitchDegrees = 40,
}

-- Not selectable. Fires together with the machine gun when the aim is close
-- enough to straight ahead, which is what makes charging an enemy head-on a
-- real tactic rather than just a way to get rammed.
local forwardGun: WeaponConfig = {
	Id = "ForwardGun",
	DisplayName = "FORWARD GUN",
	Kind = "Hitscan",
	AmmoPool = "Bullets",
	AmmoPerShot = 1,
	MagazineSize = 0,
	ReloadTime = 0,
	FireInterval = 0.1,
	Range = 750,
	SpreadDegrees = 0.55,
	Automatic = true,
	HullDamage = 8,
	PersonnelDamage = 38,
	HeatPerHit = 0,
	TraverseYawDegrees = 0,
	TraversePitchDegrees = 0,
}

-- GDD 11.4: personnel damage only, cannot damage ordinary hull. HullDamage 0
-- is not a tuning value here, it is the weapon's entire identity - the pistol
-- is the answer to exposed riders and the wrong answer to everything else.
local pistol: WeaponConfig = {
	Id = "Pistol",
	DisplayName = "PISTOL",
	Kind = "Hitscan",
	AmmoPool = "Bullets",
	AmmoPerShot = 1,
	MagazineSize = 12,
	ReloadTime = 1.5,
	FireInterval = 0.3,
	Range = 190,
	SpreadDegrees = 1.6,
	Automatic = false,
	HullDamage = 0,
	PersonnelDamage = 34,
	HeatPerHit = 0,
	-- Held in a hand rather than mounted, so it traverses freely.
	TraverseYawDegrees = 180,
	TraversePitchDegrees = 60,
}

-- Slow, visible, scarce, and genuinely dangerous to fire into nearby terrain:
-- the blast does not care whose vehicle is inside the radius except for
-- convoy immunity, so a rocket into a canyon wall you are hugging hurts.
local rocketLauncher: WeaponConfig = {
	Id = "RocketLauncher",
	DisplayName = "ROCKET",
	Kind = "Rocket",
	AmmoPool = "Rockets",
	AmmoPerShot = 1,
	MagazineSize = 0,
	ReloadTime = 0,
	FireInterval = 2.2,
	Range = 900,
	SpreadDegrees = 0.4,
	Automatic = false,
	HullDamage = 45,
	PersonnelDamage = 30,
	HeatPerHit = 10,
	TraverseYawDegrees = 120,
	TraversePitchDegrees = 45,
	Projectile = {
		Speed = 185,
		Gravity = 0,
		Lifetime = 6,
		BlastRadius = 24,
		BlastHullDamage = 55,
		BlastPersonnelDamage = 40,
		BlastHeat = 28,
		MaxImpulseSpeed = 55,
	},
}

-- Short-range area denial. A single tick barely scratches anything; the
-- weapon works by stacking heat until the target ignites and the fire does
-- the killing (GDD 11.5).
local flamethrower: WeaponConfig = {
	Id = "Flamethrower",
	DisplayName = "FLAMETHROWER",
	Kind = "Cone",
	AmmoPool = "FlameFuel",
	AmmoPerShot = 1,
	MagazineSize = 0,
	ReloadTime = 0,
	FireInterval = 0.08,
	Range = 58,
	SpreadDegrees = 0,
	Automatic = true,
	HullDamage = 1.1,
	PersonnelDamage = 2.4,
	HeatPerHit = 4.5,
	TraverseYawDegrees = 150,
	TraversePitchDegrees = 30,
	Cone = {
		Degrees = 17,
		RayCount = 7,
	},
}

-- Thrown, arcing, and area-denying: the choke-point and fork weapon. Damages
-- personnel quickly and hull slowly because the patch applies heat rather
-- than direct damage, and heat hurts crew faster than structure.
local molotov: WeaponConfig = {
	Id = "Molotov",
	DisplayName = "MOLOTOV",
	Kind = "Thrown",
	AmmoPool = "Throwables",
	AmmoPerShot = 1,
	MagazineSize = 0,
	ReloadTime = 0,
	FireInterval = 1.1,
	Range = 260,
	SpreadDegrees = 0,
	Automatic = false,
	HullDamage = 0,
	PersonnelDamage = 0,
	HeatPerHit = 20,
	TraverseYawDegrees = 180,
	TraversePitchDegrees = 60,
	Projectile = {
		Speed = 105,
		Gravity = 130,
		Lifetime = 8,
		BlastRadius = 6,
		BlastHullDamage = 0,
		BlastPersonnelDamage = 0,
		BlastHeat = 18,
		MaxImpulseSpeed = 0,
	},
	FirePatch = {
		Radius = 17,
		Duration = 12,
		HeatPerSecond = 17,
	},
}

local weapons: { [string]: WeaponConfig } = {
	MachineGun = machineGun,
	ForwardGun = forwardGun,
	Pistol = pistol,
	RocketLauncher = rocketLauncher,
	Flamethrower = flamethrower,
	Molotov = molotov,
}

-- Order is the weapon-select order (keys 1-5 on the client), so it is
-- gameplay-facing rather than incidental.
local loadout: { string } = {
	"MachineGun",
	"Pistol",
	"RocketLauncher",
	"Flamethrower",
	"Molotov",
}

export type AmmoPoolConfig = {
	Initial: number,
	Max: number,
	PickupAmount: number,
	DisplayName: string,
}

-- GDD 12.2: four readable categories rather than per-weapon ammo counts.
local ammoPools: { [string]: AmmoPoolConfig } = {
	Bullets = { Initial = 320, Max = 600, PickupAmount = 160, DisplayName = "BULLETS" },
	Rockets = { Initial = 5, Max = 12, PickupAmount = 3, DisplayName = "ROCKETS" },
	FlameFuel = { Initial = 260, Max = 500, PickupAmount = 150, DisplayName = "FLAME" },
	Throwables = { Initial = 4, Max = 8, PickupAmount = 2, DisplayName = "MOLOTOV" },
}

export type FireStateName = "None" | "Heating" | "Ignited" | "Burning" | "Critical"

-- GDD 11.5. Heat is the single accumulator; the five states are thresholds on
-- it, so "fire stacking" is just heat arriving faster than it decays and
-- "extinguishing" is the reverse. Nothing sets a state directly.
local fire = {
	MaxHeat = 130,
	HeatingThreshold = 12,
	IgnitedThreshold = 40,
	BurningThreshold = 70,
	CriticalThreshold = 100,
	-- Below Ignited the fire is not self-sustaining and simply decays. At and
	-- above it, the fire feeds itself, which is what makes reaching ignition
	-- a threshold worth fighting rather than a number that ticks back down.
	SelfHeatPerSecond = {
		Ignited = 2.6,
		Burning = 4.2,
		Critical = 5,
	},
	DecayPerSecond = 7,
	-- GDD 11.5: "mud and water-like terrain can accelerate extinguishing".
	SurfaceDecayMultiplier = {
		Mud = 6,
		Oil = 0.25,
	},
	-- "High speed may reduce small external flames but should not trivially
	-- remove a fully developed vehicle fire", so the speed contribution is
	-- capped and then scaled away once the fire is established.
	SpeedDecayPerSecond = 4.5,
	SpeedDecayReferenceSpeed = 90,
	EstablishedSpeedDecayScale = 0.2,
	DamagePerSecond = {
		Ignited = { Hull = 2.4, Personnel = 1.6 },
		Burning = { Hull = 5, Personnel = 3.6 },
		Critical = { Hull = 9, Personnel = 7 },
	},
	-- GDD 11.5 critical: "high chance of operator loss or vehicle
	-- destruction". Rolled per second, so sitting in a critical fire is
	-- survivable for a few seconds if you can reach mud.
	CriticalOperatorLossChancePerSecond = 0.14,
	CriticalOperatorLossDamage = 45,
}

return {
	Weapons = weapons,
	Loadout = loadout,
	AmmoPools = ammoPools,
	Fire = fire,
	DefaultWeapon = "MachineGun",
	-- The forward gun joins the machine gun's burst when the aim is inside
	-- this cone of the chassis forward axis.
	ForwardGunConeDegrees = 14,
	-- Repair pickup restore, GDD 12.3.
	RepairAmount = 45,
}
