--!strict

export type BiomeProfile = {
	Name: string,
	GroundColor: Color3,
	AccentColor: Color3,
	FogColor: Color3,
	FogEnd: number,
	Material: Enum.Material,
}

local BIOMES: { [string]: BiomeProfile } = {
	BoulderPlain = {
		Name = "Boulder Plain",
		GroundColor = Color3.fromRGB(150, 82, 48),
		AccentColor = Color3.fromRGB(198, 84, 38),
		FogColor = Color3.fromRGB(210, 160, 120),
		FogEnd = 1200,
		Material = Enum.Material.Slate,
	},
	SandyDesert = {
		Name = "Sandy Desert",
		GroundColor = Color3.fromRGB(214, 148, 84),
		AccentColor = Color3.fromRGB(230, 175, 110),
		FogColor = Color3.fromRGB(230, 190, 140),
		FogEnd = 1000,
		Material = Enum.Material.Sand,
	},
	Canyon = {
		Name = "Canyon Pass",
		GroundColor = Color3.fromRGB(142, 70, 45),
		AccentColor = Color3.fromRGB(110, 50, 30),
		FogColor = Color3.fromRGB(140, 90, 70),
		FogEnd = 800,
		Material = Enum.Material.Rock,
	},
	Mudflats = {
		Name = "Mudflats",
		GroundColor = Color3.fromRGB(56, 38, 25),
		AccentColor = Color3.fromRGB(35, 24, 15),
		FogColor = Color3.fromRGB(90, 75, 60),
		FogEnd = 900,
		Material = Enum.Material.Mud,
	},
	RaisedHighway = {
		Name = "Raised Highway",
		GroundColor = Color3.fromRGB(64, 56, 52),
		AccentColor = Color3.fromRGB(45, 40, 38),
		FogColor = Color3.fromRGB(180, 170, 160),
		FogEnd = 1400,
		Material = Enum.Material.Concrete,
	},
}

return {
	Biomes = BIOMES,
}
