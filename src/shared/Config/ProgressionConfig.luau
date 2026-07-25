--!strict

export type PaintColorOption = {
	Name: string,
	Color: Color3,
}

export type CosmeticPreset = {
	Id: string,
	Name: string,
	Cost: number,
	PrimaryColor: Color3,
	SecondaryColor: Color3,
}

local PAINT_PALETTE: { PaintColorOption } = {
	{ Name = "Rust Red", Color = Color3.fromRGB(184, 73, 42) },
	{ Name = "Dust Yellow", Color = Color3.fromRGB(214, 158, 64) },
	{ Name = "Desert Sand", Color = Color3.fromRGB(195, 172, 138) },
	{ Name = "Scrap Iron", Color = Color3.fromRGB(85, 90, 95) },
	{ Name = "Oil Black", Color = Color3.fromRGB(30, 32, 35) },
	{ Name = "War Paint Orange", Color = Color3.fromRGB(235, 95, 30) },
}

local COSMETICS: { [string]: CosmeticPreset } = {
	Default = {
		Id = "Default",
		Name = "Factory Wasteland",
		Cost = 0,
		PrimaryColor = Color3.fromRGB(184, 73, 42),
		SecondaryColor = Color3.fromRGB(64, 56, 52),
	},
	Scavenger = {
		Id = "Scavenger",
		Name = "Scavenger Rust",
		Cost = 150,
		PrimaryColor = Color3.fromRGB(150, 82, 48),
		SecondaryColor = Color3.fromRGB(35, 30, 25),
	},
	WarRig = {
		Id = "WarRig",
		Name = "War Rig Matte",
		Cost = 400,
		PrimaryColor = Color3.fromRGB(40, 42, 45),
		SecondaryColor = Color3.fromRGB(215, 80, 40),
	},
	SaltRunner = {
		Id = "SaltRunner",
		Name = "Salt Runner White",
		Cost = 230,
		PrimaryColor = Color3.fromRGB(230, 225, 215),
		SecondaryColor = Color3.fromRGB(160, 90, 45),
	},
}

return {
	ScrapPerKm = 50,
	ScrapPerKill = 25,
	ScrapPerPickup = 10,
	PlacementBonuses = {
		[1] = 100, -- 1st place
		[2] = 50, -- 2nd place
		[3] = 25, -- 3rd place
		[4] = 10, -- 4th place
	},
	MasteryXpPerKm = 100,
	MasteryXpPerKill = 50,
	MasteryLevels = {
		[1] = 0,
		[2] = 500,
		[3] = 1200,
		[4] = 2500,
		[5] = 5000,
	},
	PaintPalette = PAINT_PALETTE,
	Cosmetics = COSMETICS,
}
