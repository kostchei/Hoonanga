--!strict

local DustConfig = require(script.Parent.Config.DustConfig)

local DRY_SURFACES = {
	WornDirt = true,
	LooseStone = true,
	Sand = true,
	SaltPan = true,
}

local DustPolicy = {}

function DustPolicy.ShouldEmit(
	surfaceProfile: string,
	speed: number,
	groundedWheels: number,
	destroyed: boolean
): boolean
	return not destroyed
		and groundedWheels > 0
		and math.abs(speed) >= DustConfig.MinimumSpeed
		and DRY_SURFACES[surfaceProfile] == true
end

function DustPolicy.EmissionRate(speed: number, lowPerformanceMode: boolean): number
	local alpha = math.clamp(
		(math.abs(speed) - DustConfig.MinimumSpeed)
			/ (DustConfig.FullRateSpeed - DustConfig.MinimumSpeed),
		0,
		1
	)
	local rate = DustConfig.MaxRatePerEmitter * alpha
	return rate * (if lowPerformanceMode then DustConfig.LowPerformanceRateScale else 1)
end

function DustPolicy.RearContactNames(wheelContacts: { any }): { string }
	local rearZ = -math.huge
	for _, contact in wheelContacts do
		if contact.Front == false and typeof(contact.Offset) == "Vector3" then
			rearZ = math.max(rearZ, contact.Offset.Z)
		end
	end
	local names: { string } = {}
	for _, contact in wheelContacts do
		if
			contact.Front == false
			and typeof(contact.Offset) == "Vector3"
			and math.abs(contact.Offset.Z - rearZ) < 0.01
			and typeof(contact.Name) == "string"
		then
			table.insert(names, contact.Name)
		end
	end
	table.sort(names)
	while #names > 2 do
		table.remove(names)
	end
	return names
end

return DustPolicy
