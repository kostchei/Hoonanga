--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)

local EconomyService = {}

function EconomyService.Start() end

function EconomyService.CalculatePickupBonus(_player: Player, distanceRank: number): number
	local trailingRanks = math.max(0, math.floor(distanceRank) - 1)
	return math.min(
		EconomyConfig.MaxPickupBonus,
		1 + trailingRanks * EconomyConfig.TrailingPickupBonusPerRank
	)
end

function EconomyService.ApplyPickupBonus(
	player: Player,
	baseAmount: number,
	distanceRank: number
): number
	return math.max(
		0,
		math.floor(baseAmount * EconomyService.CalculatePickupBonus(player, distanceRank) + 0.5)
	)
end

function EconomyService.GetTargetAggroMultiplier(_player: Player, distanceRank: number): number
	if distanceRank == 1 then
		return EconomyConfig.LeaderAggroMultiplier
	end
	return 1
end

function EconomyService.ClampRunRewards(credits: number, masteryXp: number): (number, number)
	return math.clamp(math.floor(credits), 0, EconomyConfig.MaxRunCredits),
		math.clamp(math.floor(masteryXp), 0, EconomyConfig.MaxRunMasteryXp)
end

return EconomyService
