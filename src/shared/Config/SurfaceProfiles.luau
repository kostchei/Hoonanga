--!strict

export type SurfaceProfile = {
	Grip: number,
	Drag: number,
	FuelUse: number,
	BogRate: number,
}

local profiles: { [string]: SurfaceProfile } = {
	Asphalt = {
		Grip = 1,
		Drag = 1,
		FuelUse = 1,
		BogRate = 0,
	},
	WornDirt = {
		Grip = 0.88,
		Drag = 1.1,
		FuelUse = 1.05,
		BogRate = 0,
	},
	LooseStone = {
		Grip = 0.72,
		Drag = 1.2,
		FuelUse = 1.1,
		BogRate = 0,
	},
	Mud = {
		Grip = 0.55,
		Drag = 1.8,
		FuelUse = 1.35,
		BogRate = 0.18,
	},
	Sand = {
		Grip = 0.68,
		Drag = 1.5,
		FuelUse = 1.25,
		BogRate = 0.05,
	},
	-- Dry salt crust: hard, flat and fast - the one off-road surface that
	-- rewards leaving the road rather than punishing it.
	SaltPan = {
		Grip = 0.94,
		Drag = 1,
		FuelUse = 1,
		BogRate = 0,
	},
	Oil = {
		Grip = 0.12,
		Drag = 0.9,
		FuelUse = 1,
		BogRate = 0,
	},
}

return profiles
