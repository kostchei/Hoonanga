--!strict

export type SoundEffect = {
	Id: string,
	AssetId: string,
	Volume: number,
	Pitch: number,
}

local SOUND_EFFECTS: { [string]: SoundEffect } = {
	MachineGunFire = {
		Id = "MachineGunFire",
		AssetId = "rbxassetid://130113322",
		Volume = 0.5,
		Pitch = 1.0,
	},
	Explosion = {
		Id = "Explosion",
		AssetId = "rbxassetid://142070127",
		Volume = 0.8,
		Pitch = 0.9,
	},
	VehicleImpact = {
		Id = "VehicleImpact",
		AssetId = "rbxassetid://260430079",
		Volume = 0.7,
		Pitch = 1.0,
	},
	LowFuelAlarm = {
		Id = "LowFuelAlarm",
		AssetId = "rbxassetid://9114226000",
		Volume = 0.6,
		Pitch = 1.2,
	},
	PickupCollected = {
		Id = "PickupCollected",
		AssetId = "rbxassetid://9114227000",
		Volume = 0.6,
		Pitch = 1.1,
	},
}

return {
	EngineSoundAssetId = "rbxassetid://1847636603",
	Effects = SOUND_EFFECTS,
	EngineMinPitch = 0.75,
	EngineMaxPitch = 2.2,
}
