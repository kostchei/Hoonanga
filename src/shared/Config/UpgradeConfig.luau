--!strict

export type UpgradeDef = {
	Id: string,
	Name: string,
	Description: string,
	Category: string,
	HullMult: number?,
	SpeedMult: number?,
	FuelCapMult: number?,
	GripMult: number?,
	HeatCoolMult: number?,
}

local UPGRADES: { [string]: UpgradeDef } = {
	ReinforcedTires = {
		Id = "ReinforcedTires",
		Name = "Reinforced Tires",
		Description = "+25% off-road grip & mud resistance",
		Category = "Handling",
		GripMult = 1.25,
	},
	ExtraFuelTank = {
		Id = "ExtraFuelTank",
		Name = "Auxiliary Tank",
		Description = "+50% maximum fuel capacity",
		Category = "Survival",
		FuelCapMult = 1.5,
	},
	HeatSinkCooling = {
		Id = "HeatSinkCooling",
		Name = "Overclocked Heatsink",
		Description = "+30% faster weapon cooling rate",
		Category = "Combat",
		HeatCoolMult = 1.3,
	},
	HeavyArmorPlating = {
		Id = "HeavyArmorPlating",
		Name = "Welded Armor Plates",
		Description = "+40% max hull health, -5% top speed",
		Category = "Defense",
		HullMult = 1.4,
		SpeedMult = 0.95,
	},
	TurboCharger = {
		Id = "TurboCharger",
		Name = "Scrap Turbocharger",
		Description = "+15% top speed & acceleration",
		Category = "Speed",
		SpeedMult = 1.15,
	},
	LightweightPanels = {
		Id = "LightweightPanels",
		Name = "Lightweight Panels",
		Description = "+10% speed, -12% maximum hull",
		Category = "Speed",
		SpeedMult = 1.1,
		HullMult = 0.88,
	},
	LongRangeTank = {
		Id = "LongRangeTank",
		Name = "Long-Range Tank",
		Description = "+25% fuel capacity, -3% speed",
		Category = "Survival",
		FuelCapMult = 1.25,
		SpeedMult = 0.97,
	},
	RallySuspension = {
		Id = "RallySuspension",
		Name = "Rally Suspension",
		Description = "+12% grip and +3% speed",
		Category = "Handling",
		GripMult = 1.12,
		SpeedMult = 1.03,
	},
}

return {
	Upgrades = UPGRADES,
}
