--!strict

export type FormationSlot = {
	Lateral: number,
	Behind: number,
	Role: string,
}

export type Composition = {
	DisplayName: string,
	VehicleType: string,
	Count: number,
	StartingFuel: number,
	MaxFuel: number,
	SpawnSpacing: number,
	Slots: { FormationSlot },
}

local compositions: { [string]: Composition } = {
	Roadtrain = {
		DisplayName = "Roadtrain",
		VehicleType = "Roadtrain",
		Count = 1,
		StartingFuel = 500,
		MaxFuel = 500,
		SpawnSpacing = 24,
		Slots = {
			{ Lateral = 0, Behind = 0, Role = "Leader" },
		},
	},
	Ute = {
		DisplayName = "Two Utes",
		VehicleType = "Ute",
		Count = 2,
		StartingFuel = 452,
		MaxFuel = 452,
		SpawnSpacing = 18,
		Slots = {
			{ Lateral = -5, Behind = 0, Role = "Leader" },
			{ Lateral = 7, Behind = 24, Role = "RearRight" },
		},
	},
	Bike = {
		DisplayName = "Three Bikes",
		VehicleType = "Bike",
		Count = 3,
		StartingFuel = 350,
		MaxFuel = 350,
		SpawnSpacing = 12,
		Slots = {
			{ Lateral = 0, Behind = 0, Role = "Leader" },
			{ Lateral = -7, Behind = 18, Role = "RearLeft" },
			{ Lateral = 7, Behind = 18, Role = "RearRight" },
		},
	},
}

return compositions
