--!strict

export type WeaponConfig = {
	FireInterval: number,
	Damage: number,
	Range: number,
	MagazineSize: number,
	ReloadTime: number,
	SpreadDegrees: number,
}

local machineGun: WeaponConfig = {
	FireInterval = 0.1,
	Damage = 4,
	Range = 650,
	MagazineSize = 80,
	ReloadTime = 2.4,
	SpreadDegrees = 1.1,
}

return {
	MachineGun = machineGun,
}
