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
		AssetId = "rbxassetid://9114223179",
		Volume = 0.5,
		Pitch = 1.0,
	},
	Explosion = {
		Id = "Explosion",
		AssetId = "rbxassetid://9114224000",
		Volume = 0.8,
		Pitch = 0.9,
	},
	VehicleImpact = {
		Id = "VehicleImpact",
		AssetId = "rbxassetid://9114225000",
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
	Effects = SOUND_EFFECTS,
	EngineMinPitch = 0.75,
	EngineMaxPitch = 2.2,
}
