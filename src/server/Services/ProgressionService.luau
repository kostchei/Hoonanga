--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local RemoteService = require(script.Parent.RemoteService)

export type PlayerProfile = {
	Scrap: number,
	Mastery: { [string]: number },
	UnlockedCosmetics: { [string]: boolean },
	EquippedCosmetic: string,
	EquippedClass: string,
	EquippedWeapon: string,
	EquippedSecondary: string,
}

local DATASTORE_KEY = "HoonangaPlayerData_v1"
local profiles: { [Player]: PlayerProfile } = {}
local lastSavedAt: { [number]: number } = {}

local function createDefaultProfile(): PlayerProfile
	return {
		Scrap = 0,
		Mastery = {
			Ute = 0,
			Roadtrain = 0,
			Biker = 0,
		},
		UnlockedCosmetics = {
			Default = true,
		},
		EquippedCosmetic = "Default",
		EquippedClass = "Ute",
		EquippedWeapon = "MachineGun",
		EquippedSecondary = "Pistol",
	}
end

local ProgressionService = {}

function ProgressionService.Start()
	local dataStore = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_KEY)
	end) and DataStoreService:GetDataStore(DATASTORE_KEY) or nil

	Players.PlayerAdded:Connect(function(player)
		local defaultProfile = createDefaultProfile()
		if dataStore and player.UserId > 0 then
			local ok, saved = pcall(function()
				return dataStore:GetAsync(tostring(player.UserId))
			end)
			if ok and typeof(saved) == "table" then
				for k, v in saved do
					(defaultProfile :: any)[k] = v
				end
			end
		end
		profiles[player] = defaultProfile

		task.defer(function()
			RemoteService.Get("ProgressionUpdated"):FireClient(player, defaultProfile)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile and dataStore and player.UserId > 0 then
			local now = os.time()
			local lastSave = lastSavedAt[player.UserId] or 0
			if now - lastSave >= 6 then
				lastSavedAt[player.UserId] = now
				pcall(function()
					dataStore:SetAsync(tostring(player.UserId), profile)
				end)
			end
		end
		profiles[player] = nil
	end)

	game:BindToClose(function()
		if not dataStore then
			return
		end
		for player, profile in profiles do
			if player.UserId > 0 then
				pcall(function()
					dataStore:SetAsync(tostring(player.UserId), profile)
				end)
			end
		end
	end)

	local getFn = RemoteService.GetFunction("GetPlayerData")
	getFn.OnServerInvoke = function(player: Player)
		return ProgressionService.GetProfile(player)
	end

	local buyFn = RemoteService.GetFunction("PurchaseCosmetic")
	buyFn.OnServerInvoke = function(player: Player, cosmeticId: unknown)
		if typeof(cosmeticId) ~= "string" then
			return false, "Invalid argument"
		end
		return ProgressionService.PurchaseCosmetic(player, cosmeticId)
	end
end

function ProgressionService.GetProfile(player: Player): PlayerProfile
	local profile = profiles[player]
	if not profile then
		profile = createDefaultProfile()
		profiles[player] = profile
	end
	return profile
end

function ProgressionService.AwardRunRewards(
	player: Player,
	distanceStuds: number,
	kills: number,
	pickups: number,
	placement: number,
	convoyClass: string
): (number, number)
	local profile = ProgressionService.GetProfile(player)
	local km = distanceStuds / 1000

	local placementBonus = ProgressionConfig.PlacementBonuses[placement] or 0
	local scrapGained = math.floor(
		km * ProgressionConfig.ScrapPerKm
			+ kills * ProgressionConfig.ScrapPerKill
			+ pickups * ProgressionConfig.ScrapPerPickup
			+ placementBonus
	)

	local xpGained = math.floor(
		km * ProgressionConfig.MasteryXpPerKm + kills * ProgressionConfig.MasteryXpPerKill
	)

	profile.Scrap += scrapGained
	local currentXp = profile.Mastery[convoyClass] or 0
	profile.Mastery[convoyClass] = currentXp + xpGained

	RemoteService.Get("ProgressionUpdated"):FireClient(player, profile)
	return scrapGained, xpGained
end

function ProgressionService.PurchaseCosmetic(player: Player, cosmeticId: string): (boolean, string)
	local profile = ProgressionService.GetProfile(player)
	local cosmetic = ProgressionConfig.Cosmetics[cosmeticId]
	if not cosmetic then
		return false, "Cosmetic does not exist"
	end

	if profile.UnlockedCosmetics[cosmeticId] then
		profile.EquippedCosmetic = cosmeticId
		RemoteService.Get("ProgressionUpdated"):FireClient(player, profile)
		return true, "Equipped"
	end

	if profile.Scrap < cosmetic.Cost then
		return false, "Insufficient Scrap"
	end

	profile.Scrap -= cosmetic.Cost
	profile.UnlockedCosmetics[cosmeticId] = true
	profile.EquippedCosmetic = cosmeticId

	RemoteService.Get("ProgressionUpdated"):FireClient(player, profile)
	return true, "Purchased and Equipped"
end

return ProgressionService
