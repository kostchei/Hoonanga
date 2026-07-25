--!strict

local EconomyService = {}

function EconomyService.Start()
	-- EconomyService ready
end

function EconomyService.CalculatePickupBonus(_player: Player, distanceRank: number): number
	if distanceRank > 1 then
		return 1.15
	end
	return 1.0
end

function EconomyService.GetTargetAggroMultiplier(_player: Player, distanceRank: number): number
	if distanceRank == 1 then
		return 1.25
	end
	return 1.0
end

return EconomyService
