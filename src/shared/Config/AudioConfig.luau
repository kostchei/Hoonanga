--!strict

export type SoundEffect = {
	Id: string,
	AssetId: string,
	Volume: number,
	Pitch: number,
	Subtitle: string,
}

-- Uses official Roblox system sound assets that are 100% public & un-privated
local SOUND_EFFECTS: { [string]: SoundEffect } = {
	MachineGunFire = {
		Id = "MachineGunFire",
		AssetId = "rbxassetid://130113322",
		Volume = 0.5,
		Pitch = 1.0,
		Subtitle = "Machine-gun fire",
	},
	PistolFire = {
		Id = "PistolFire",
		AssetId = "rbxassetid://130113322",
		Volume = 0.42,
		Pitch = 1.25,
		Subtitle = "Pistol fire",
	},
	RocketFire = {
		Id = "RocketFire",
		AssetId = "rbxassetid://12222084",
		Volume = 0.72,
		Pitch = 1.25,
		Subtitle = "Rocket launched",
	},
	FlameFire = {
		Id = "FlameFire",
		AssetId = "rbxassetid://12221967",
		Volume = 0.46,
		Pitch = 1.4,
		Subtitle = "Flamethrower",
	},
	MolotovFire = {
		Id = "MolotovFire",
		AssetId = "rbxassetid://12221976",
		Volume = 0.5,
		Pitch = 0.8,
		Subtitle = "Molotov thrown",
	},
	Explosion = {
		Id = "Explosion",
		AssetId = "rbxassetid://12222084",
		Volume = 0.8,
		Pitch = 0.9,
		Subtitle = "Explosion",
	},
	VehicleImpact = {
		Id = "VehicleImpact",
		AssetId = "rbxassetid://12221976",
		Volume = 0.7,
		Pitch = 1.0,
		Subtitle = "Vehicle impact",
	},
	LowFuelAlarm = {
		Id = "LowFuelAlarm",
		AssetId = "rbxassetid://12221976",
		Volume = 0.6,
		Pitch = 1.4,
		Subtitle = "Low fuel warning",
	},
	FireAlarm = {
		Id = "FireAlarm",
		AssetId = "rbxassetid://12221976",
		Volume = 0.66,
		Pitch = 1.65,
		Subtitle = "Critical fire warning",
	},
	PickupCollected = {
		Id = "PickupCollected",
		AssetId = "rbxassetid://12221976",
		Volume = 0.6,
		Pitch = 1.2,
		Subtitle = "Resource collected",
	},
}

return {
	EngineSoundAssetId = "rbxassetid://12221967",
	Effects = SOUND_EFFECTS,
	EngineMinPitch = 0.75,
	EngineMaxPitch = 2.2,
	EngineMaxVolume = 0.62,
	LowFuelRatio = 0.18,
	WarningRepeatSeconds = 6,
	WeaponEffects = {
		MachineGun = "MachineGunFire",
		ForwardGun = "MachineGunFire",
		Pistol = "PistolFire",
		RocketLauncher = "RocketFire",
		Flamethrower = "FlameFire",
		Molotov = "MolotovFire",
	},
}
