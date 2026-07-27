--!strict

export type AITraits = {
	Speed: number,
	Accuracy: number,
	Aggression: number,
	Vendetta: number,
}

local CLASS_IDS = { "Roadtrain", "Ute", "Bike" }
local VALID_CLASSES = {
	Roadtrain = true,
	Ute = true,
	Bike = true,
}
local MAX_SEED = 2 ^ 31 - 1

local function stableSeed(parts: { string }): number
	local hash = 17
	for _, part in parts do
		for index = 1, #part do
			hash = (hash * 131 + string.byte(part, index)) % MAX_SEED
		end
	end
	return math.max(1, hash)
end

local AIRosterPolicy = {}

function AIRosterPolicy.AllocateClasses(
	humanClasses: { string },
	aiCount: number,
	matchSeed: number
): { string }
	local counts = {
		Roadtrain = 0,
		Ute = 0,
		Bike = 0,
	}
	for _, classId in humanClasses do
		if VALID_CLASSES[classId] then
			counts[classId] += 1
		end
	end

	local random = Random.new(math.abs(math.floor(matchSeed)) % MAX_SEED)
	local result = {}
	for _ = 1, math.max(0, aiCount) do
		local candidates = {}
		for _, classId in CLASS_IDS do
			if counts[classId] == 0 then
				table.insert(candidates, classId)
			end
		end
		if #candidates == 0 then
			local least = math.huge
			for _, classId in CLASS_IDS do
				least = math.min(least, counts[classId])
			end
			for _, classId in CLASS_IDS do
				if counts[classId] == least then
					table.insert(candidates, classId)
				end
			end
		end

		local classId = candidates[random:NextInteger(1, #candidates)]
		counts[classId] += 1
		table.insert(result, classId)
	end
	return result
end

function AIRosterPolicy.RollTraits(
	matchSeed: number,
	aiSlot: number,
	classId: string,
	vehicleSlot: number
): AITraits
	local identity = {
		tostring(math.floor(matchSeed)),
		tostring(aiSlot),
		classId,
		tostring(vehicleSlot),
	}
	local function roll(trait: string, minimum: number, maximum: number): number
		local parts = table.clone(identity)
		table.insert(parts, trait)
		local random = Random.new(stableSeed(parts))
		return minimum + random:NextNumber() * (maximum - minimum)
	end
	return {
		Speed = roll("Speed", 0.9, 0.98),
		Accuracy = roll("Accuracy", 0.5, 0.95),
		Aggression = roll("Aggression", 0.25, 0.95),
		Vendetta = roll("Vendetta", 0.25, 0.95),
	}
end

return AIRosterPolicy
