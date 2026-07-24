--!strict

export type SuspensionConfig = {
	RideHeight: number,
	RayLength: number,
	SpringStrength: number,
	SpringDamping: number,
}

export type VehicleConfig = {
	MaxForwardSpeed: number,
	MaxReverseSpeed: number,
	Acceleration: number,
	ReverseAcceleration: number,
	BrakeDeceleration: number,
	CoastDeceleration: number,
	SteeringRate: number,
	HighSpeedSteeringFactor: number,
	LateralGrip: number,
	Downforce: number,
	MaxHull: number,
	FuelCapacity: number,
	IdleFuelPerSecond: number,
	ThrottleFuelPerSecond: number,
	Suspension: SuspensionConfig,
}

local ute: VehicleConfig = {
	MaxForwardSpeed = 112,
	MaxReverseSpeed = 28,
	Acceleration = 52,
	ReverseAcceleration = 28,
	BrakeDeceleration = 82,
	CoastDeceleration = 12,
	SteeringRate = math.rad(72),
	HighSpeedSteeringFactor = 0.42,
	LateralGrip = 7.5,
	Downforce = 1.8,
	MaxHull = 100,
	FuelCapacity = 300,
	IdleFuelPerSecond = 0.12,
	ThrottleFuelPerSecond = 0.82,
	Suspension = {
		RideHeight = 2.8,
		RayLength = 4.5,
		SpringStrength = 52,
		SpringDamping = 8,
	},
}

return {
	Ute = ute,
}
