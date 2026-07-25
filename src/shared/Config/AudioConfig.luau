--!strict

export type SoundEffect = {
	Id: string,
	AssetId: string,
	Volume: number,
	Pitch: number,
}

-- Uses official Roblox system sound assets that are 100% public & un-privated
local SOUND_EFFECTS: { [string]: SoundEffect } = {
	MachineGunFire = {
		Id = "MachineGunFire",
		AssetId = "rbxassetid://130113322",
		Volume = 0.5,
		Pitch = 1.0,
	},
	Explosion = {
		Id = "Explosion",
		AssetId = "rbxassetid://12222084",
		Volume = 0.8,
		Pitch = 0.9,
	},
	VehicleImpact = {
		Id = "VehicleImpact",
		AssetId = "rbxassetid://12221976",
		Volume = 0.7,
		Pitch = 1.0,
	},
	LowFuelAlarm = {
		Id = "LowFuelAlarm",
		AssetId = "rbxassetid://12221976",
		Volume = 0.6,
		Pitch = 1.4,
	},
	PickupCollected = {
		Id = "PickupCollected",
		AssetId = "rbxassetid://12221976",
		Volume = 0.6,
		Pitch = 1.2,
	},
}

return {
	EngineSoundAssetId = "rbxassetid://12221967",
	Effects = SOUND_EFFECTS,
	EngineMinPitch = 0.75,
	EngineMaxPitch = 2.2,
}
