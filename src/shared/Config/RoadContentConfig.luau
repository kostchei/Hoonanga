--!strict

export type VariantDefinition = {
	Id: string,
	Kind: "Normal" | "Hazard" | "Transition",
	ArtSet: string,
	HazardIntensity: number,
}

local function family(artSet: string): { VariantDefinition }
	return {
		{ Id = "NormalA", Kind = "Normal", ArtSet = artSet .. "A", HazardIntensity = 0 },
		{ Id = "NormalB", Kind = "Normal", ArtSet = artSet .. "B", HazardIntensity = 0 },
		{ Id = "NormalC", Kind = "Normal", ArtSet = artSet .. "C", HazardIntensity = 1 },
		{ Id = "NormalD", Kind = "Normal", ArtSet = artSet .. "D", HazardIntensity = 1 },
		{ Id = "HazardA", Kind = "Hazard", ArtSet = artSet .. "HazardA", HazardIntensity = 2 },
		{ Id = "HazardB", Kind = "Hazard", ArtSet = artSet .. "HazardB", HazardIntensity = 3 },
		{
			Id = "TransitionIn",
			Kind = "Transition",
			ArtSet = artSet .. "Entry",
			HazardIntensity = 0,
		},
		{
			Id = "TransitionOut",
			Kind = "Transition",
			ArtSet = artSet .. "Exit",
			HazardIntensity = 0,
		},
	}
end

return {
	Families = {
		BoulderPlain = family("Boulder"),
		SandyDesert = family("Sand"),
		Canyon = family("Canyon"),
		Mudflat = family("Mudflat"),
		RaisedHighway = family("Highway"),
	},
	ForkSets = {
		"FuelMud",
		"AmmoRock",
		"RepairOil",
		"SplitSupplies",
	},
}
