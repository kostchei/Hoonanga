--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessibilityConfig = require(ReplicatedStorage.Shared.Config.AccessibilityConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local AnalyticsService = require(script.Parent.AnalyticsService)
local EconomyService = require(script.Parent.EconomyService)
local RemoteService = require(script.Parent.RemoteService)

export type PlayerProfile = {
	Version: number,
	Credits: number,
	Wins: number,
	Races: number,
	Podiums: number,
	DNFs: number,
	BestDistance: number,
	TotalDistance: number,
	TotalKills: number,
	Mastery: { [string]: number },
	OwnedVehicles: { [string]: boolean },
	UnlockedCosmetics: { [string]: boolean },
	EquippedCosmetic: string,
	EquippedClass: string,
	EquippedWeapon: string,
	EquippedSecondary: string,
	Accessibility: AccessibilityConfig.AccessibilitySettings,
	TutorialCompleted: boolean,
	ProcessedRunIds: { string },
}

local PROFILE_VERSION = 3
local DATASTORE_KEY = "HoonangaPlayerData_v2"
local LEGACY_DATASTORE_KEY = "HoonangaPlayerData_v1"
local AUTOSAVE_INTERVAL = 60
local MAX_PROCESSED_RUN_IDS = 50
local SAVE_ATTEMPTS = 3
local LOAD_ATTEMPTS = 3
local SETTINGS_REQUEST_INTERVAL = 0.25
local VALID_PRIMARY_WEAPONS = {
	MachineGun = true,
	RocketLauncher = true,
	Flamethrower = true,
}
local VALID_SECONDARY_WEAPONS = {
	Pistol = true,
	Molotov = true,
}

local profiles: { [Player]: PlayerProfile } = {}
local profilesSafeToSave: { [Player]: boolean } = {}
local lastSettingsRequestAt: { [Player]: number } = {}
local dataStore: GlobalDataStore? = nil
local legacyDataStore: GlobalDataStore? = nil
local started = false

local function finiteNonNegative(value: unknown, fallback: number): number
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return math.max(0, value)
end

local function defaultAccessibility(): AccessibilityConfig.AccessibilitySettings
	local defaults = AccessibilityConfig.DefaultSettings
	return {
		FieldOfView = defaults.FieldOfView,
		ScreenShakeMultiplier = defaults.ScreenShakeMultiplier,
		ColorblindMode = defaults.ColorblindMode,
		SubtitlesEnabled = defaults.SubtitlesEnabled,
		ReducedFlashing = defaults.ReducedFlashing,
	}
end

local function normalizeAccessibility(
	saved: unknown,
	fallback: AccessibilityConfig.AccessibilitySettings?
): AccessibilityConfig.AccessibilitySettings
	local settings = if fallback
		then {
			FieldOfView = fallback.FieldOfView,
			ScreenShakeMultiplier = fallback.ScreenShakeMultiplier,
			ColorblindMode = fallback.ColorblindMode,
			SubtitlesEnabled = fallback.SubtitlesEnabled,
			ReducedFlashing = fallback.ReducedFlashing,
		}
		else defaultAccessibility()
	if typeof(saved) ~= "table" then
		return settings
	end
	local data = saved :: { [any]: any }
	if typeof(data.FieldOfView) == "number" then
		settings.FieldOfView =
			math.clamp(data.FieldOfView, AccessibilityConfig.MinFOV, AccessibilityConfig.MaxFOV)
	end
	if typeof(data.ScreenShakeMultiplier) == "number" then
		settings.ScreenShakeMultiplier = math.clamp(data.ScreenShakeMultiplier, 0, 1)
	end
	if
		data.ColorblindMode == "None"
		or data.ColorblindMode == "Protanopia"
		or data.ColorblindMode == "Deuteranopia"
		or data.ColorblindMode == "Tritanopia"
	then
		settings.ColorblindMode = data.ColorblindMode
	end
	if typeof(data.SubtitlesEnabled) == "boolean" then
		settings.SubtitlesEnabled = data.SubtitlesEnabled
	end
	if typeof(data.ReducedFlashing) == "boolean" then
		settings.ReducedFlashing = data.ReducedFlashing
	end
	return settings
end

local function createDefaultProfile(): PlayerProfile
	return {
		Version = PROFILE_VERSION,
		Credits = 0,
		Wins = 0,
		Races = 0,
		Podiums = 0,
		DNFs = 0,
		BestDistance = 0,
		TotalDistance = 0,
		TotalKills = 0,
		Mastery = {
			Ute = 0,
			Roadtrain = 0,
			Bike = 0,
		},
		OwnedVehicles = {
			Ute = true,
			Roadtrain = true,
			Bike = true,
		},
		UnlockedCosmetics = {
			Default = true,
		},
		EquippedCosmetic = "Default",
		EquippedClass = "Ute",
		EquippedWeapon = "MachineGun",
		EquippedSecondary = "Pistol",
		Accessibility = defaultAccessibility(),
		TutorialCompleted = false,
		ProcessedRunIds = {},
	}
end

local function normalizeProfile(saved: unknown): PlayerProfile
	local profile = createDefaultProfile()
	if typeof(saved) ~= "table" then
		return profile
	end
	local data = saved :: { [any]: any }

	profile.Credits = finiteNonNegative(data.Credits, finiteNonNegative(data.Scrap, 0))
	profile.Wins = finiteNonNegative(data.Wins, 0)
	profile.Races = finiteNonNegative(data.Races, 0)
	profile.Podiums = finiteNonNegative(data.Podiums, 0)
	profile.DNFs = finiteNonNegative(data.DNFs, 0)
	profile.BestDistance = finiteNonNegative(data.BestDistance, 0)
	profile.TotalDistance = finiteNonNegative(data.TotalDistance, 0)
	profile.TotalKills = finiteNonNegative(data.TotalKills, 0)
	profile.Accessibility = normalizeAccessibility(data.Accessibility)
	profile.TutorialCompleted = data.TutorialCompleted == true

	if typeof(data.Mastery) == "table" then
		local mastery = data.Mastery :: { [any]: any }
		profile.Mastery.Ute = finiteNonNegative(mastery.Ute, 0)
		profile.Mastery.Roadtrain = finiteNonNegative(mastery.Roadtrain, 0)
		profile.Mastery.Bike = finiteNonNegative(mastery.Bike, finiteNonNegative(mastery.Biker, 0))
	end

	if typeof(data.OwnedVehicles) == "table" then
		for _, classId in { "Ute", "Roadtrain", "Bike" } do
			if data.OwnedVehicles[classId] == true then
				profile.OwnedVehicles[classId] = true
			end
		end
	end

	if typeof(data.UnlockedCosmetics) == "table" then
		for cosmeticId, unlocked in data.UnlockedCosmetics do
			if
				typeof(cosmeticId) == "string"
				and unlocked == true
				and ProgressionConfig.Cosmetics[cosmeticId] ~= nil
			then
				profile.UnlockedCosmetics[cosmeticId] = true
			end
		end
	end

	if
		typeof(data.EquippedClass) == "string"
		and (
			data.EquippedClass == "Ute"
			or data.EquippedClass == "Roadtrain"
			or data.EquippedClass == "Bike"
			or data.EquippedClass == "Biker"
		)
	then
		profile.EquippedClass = if data.EquippedClass == "Biker" then "Bike" else data.EquippedClass
	end
	if
		typeof(data.EquippedCosmetic) == "string"
		and profile.UnlockedCosmetics[data.EquippedCosmetic]
	then
		profile.EquippedCosmetic = data.EquippedCosmetic
	end
	if
		typeof(data.EquippedWeapon) == "string"
		and VALID_PRIMARY_WEAPONS[data.EquippedWeapon] == true
		and WeaponConfig.Weapons[data.EquippedWeapon] ~= nil
	then
		profile.EquippedWeapon = data.EquippedWeapon
	end
	if
		typeof(data.EquippedSecondary) == "string"
		and VALID_SECONDARY_WEAPONS[data.EquippedSecondary] == true
		and WeaponConfig.Weapons[data.EquippedSecondary] ~= nil
	then
		profile.EquippedSecondary = data.EquippedSecondary
	end

	if typeof(data.ProcessedRunIds) == "table" then
		for _, runId in data.ProcessedRunIds do
			if typeof(runId) == "string" and #runId <= 80 then
				table.insert(profile.ProcessedRunIds, runId)
				if #profile.ProcessedRunIds >= MAX_PROCESSED_RUN_IDS then
					break
				end
			end
		end
	end

	return profile
end

local function notify(player: Player)
	local profile = profiles[player]
	if profile then
		RemoteService.Get("ProgressionUpdated"):FireClient(player, profile)
	end
end

local function saveProfile(player: Player): boolean
	local profile = profiles[player]
	if not profile or not dataStore or player.UserId <= 0 or profilesSafeToSave[player] ~= true then
		return profile ~= nil
	end

	local lastMessage: unknown = nil
	for attempt = 1, SAVE_ATTEMPTS do
		local success, message = pcall(function()
			dataStore:UpdateAsync(tostring(player.UserId), function()
				return profile
			end)
		end)
		if success then
			return true
		end
		lastMessage = message
		if attempt < SAVE_ATTEMPTS then
			task.wait(attempt * 0.5)
		end
	end

	warn(
		string.format(
			"[Hoonanga] Failed to save profile for %s after %d attempts: %s",
			player.Name,
			SAVE_ATTEMPTS,
			tostring(lastMessage)
		)
	)
	return false
end

local function loadPlayer(player: Player)
	local saved: unknown = nil
	local primaryLoadSucceeded = false
	if dataStore and player.UserId > 0 then
		local lastMessage: unknown = nil
		for attempt = 1, LOAD_ATTEMPTS do
			local success, result = pcall(function()
				return dataStore:GetAsync(tostring(player.UserId))
			end)
			if success then
				saved = result
				primaryLoadSucceeded = true
				break
			end
			lastMessage = result
			if attempt < LOAD_ATTEMPTS then
				task.wait(attempt * 0.5)
			end
		end
		if not primaryLoadSucceeded then
			warn(
				string.format(
					"[Hoonanga] Failed to load profile for %s after %d attempts: %s",
					player.Name,
					LOAD_ATTEMPTS,
					tostring(lastMessage)
				)
			)
		end
	end
	local legacyLookupResolved = legacyDataStore == nil
	if primaryLoadSucceeded and saved == nil and legacyDataStore and player.UserId > 0 then
		local success, result = pcall(function()
			return legacyDataStore:GetAsync(tostring(player.UserId))
		end)
		if success then
			saved = result
			legacyLookupResolved = true
		else
			warn(
				string.format(
					"[Hoonanga] Failed to load legacy profile for %s: %s",
					player.Name,
					tostring(result)
				)
			)
		end
	end
	profiles[player] = normalizeProfile(saved)
	profilesSafeToSave[player] = primaryLoadSucceeded and (saved ~= nil or legacyLookupResolved)
	task.defer(notify, player)
end

local ProgressionService = {}

function ProgressionService.Start()
	if started then
		return
	end
	started = true

	local success, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_KEY)
	end)
	if success then
		dataStore = result
	else
		warn(string.format("[Hoonanga] DataStore unavailable: %s", tostring(result)))
	end
	local legacySuccess, legacyResult = pcall(function()
		return DataStoreService:GetDataStore(LEGACY_DATASTORE_KEY)
	end)
	if legacySuccess then
		legacyDataStore = legacyResult
	else
		warn(string.format("[Hoonanga] Legacy DataStore unavailable: %s", tostring(legacyResult)))
	end

	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player)
		profiles[player] = nil
		profilesSafeToSave[player] = nil
		lastSettingsRequestAt[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(saveProfile, player)
			end
		end
	end)

	game:BindToClose(function()
		for player in profiles do
			saveProfile(player)
		end
	end)

	RemoteService.GetFunction("GetPlayerData").OnServerInvoke = function(player: Player)
		return ProgressionService.GetProfile(player)
	end

	RemoteService.GetFunction("PurchaseCosmetic").OnServerInvoke = function(
		player: Player,
		cosmeticId: unknown
	)
		if typeof(cosmeticId) ~= "string" then
			return false, "Invalid argument"
		end
		return ProgressionService.PurchaseCosmetic(player, cosmeticId)
	end

	RemoteService.Get("UpdateAccessibilitySettings").OnServerEvent
		:Connect(function(player: Player, payload: unknown)
			local now = os.clock()
			if
				typeof(payload) ~= "table"
				or now - (lastSettingsRequestAt[player] or 0) < SETTINGS_REQUEST_INTERVAL
			then
				return
			end
			lastSettingsRequestAt[player] = now
			ProgressionService.UpdateAccessibility(player, payload)
		end)
end

function ProgressionService.GetProfile(player: Player): PlayerProfile
	local profile = profiles[player]
	if not profile then
		profile = createDefaultProfile()
		profiles[player] = profile
		profilesSafeToSave[player] = false
	end
	return profile
end

function ProgressionService.Notify(player: Player)
	notify(player)
end

function ProgressionService.Save(player: Player): boolean
	return saveProfile(player)
end

function ProgressionService.UpdateAccessibility(player: Player, payload: unknown)
	local profile = ProgressionService.GetProfile(player)
	profile.Accessibility = normalizeAccessibility(payload, profile.Accessibility)
	notify(player)
	task.spawn(saveProfile, player)
end

function ProgressionService.MarkTutorialCompleted(player: Player)
	local profile = ProgressionService.GetProfile(player)
	if profile.TutorialCompleted then
		return
	end
	profile.TutorialCompleted = true
	notify(player)
	task.spawn(saveProfile, player)
end

function ProgressionService.AwardRunRewards(
	player: Player,
	distanceStuds: number,
	kills: number,
	pickups: number,
	placement: number,
	convoyClass: string,
	runId: string?,
	didWin: boolean?,
	wasDnf: boolean?
): (number, number)
	local profile = ProgressionService.GetProfile(player)
	if runId and table.find(profile.ProcessedRunIds, runId) then
		return 0, 0
	end

	local classId = if convoyClass == "Biker" then "Bike" else convoyClass
	if profile.Mastery[classId] == nil then
		classId = "Ute"
	end
	local distance = finiteNonNegative(distanceStuds, 0)
	local safeKills = finiteNonNegative(kills, 0)
	local safePickups = finiteNonNegative(pickups, 0)
	local km = distance / 1000

	local placementBonus = ProgressionConfig.PlacementBonuses[placement] or 0
	local rawCredits = math.floor(
		km * ProgressionConfig.ScrapPerKm
			+ safeKills * ProgressionConfig.ScrapPerKill
			+ safePickups * ProgressionConfig.ScrapPerPickup
			+ placementBonus
	)
	local rawXp = math.floor(
		km * ProgressionConfig.MasteryXpPerKm + safeKills * ProgressionConfig.MasteryXpPerKill
	)
	local creditsGained, xpGained = EconomyService.ClampRunRewards(rawCredits, rawXp)

	profile.Credits += creditsGained
	profile.Races += 1
	profile.Wins += if didWin == true then 1 else 0
	profile.Podiums += if placement >= 1 and placement <= 3 then 1 else 0
	profile.DNFs += if wasDnf == true then 1 else 0
	profile.BestDistance = math.max(profile.BestDistance, distance)
	profile.TotalDistance += distance
	profile.TotalKills += safeKills
	profile.Mastery[classId] += xpGained

	if runId then
		table.insert(profile.ProcessedRunIds, runId)
		while #profile.ProcessedRunIds > MAX_PROCESSED_RUN_IDS do
			table.remove(profile.ProcessedRunIds, 1)
		end
	end

	notify(player)
	task.spawn(saveProfile, player)
	AnalyticsService.LogEvent(player, "RunRewarded", {
		Distance = distance,
		Kills = safeKills,
		Pickups = safePickups,
		Placement = placement,
		ClassId = classId,
		Credits = creditsGained,
		MasteryXp = xpGained,
	})
	AnalyticsService.LogEconomyFlow(
		player,
		true,
		"Credits",
		creditsGained,
		profile.Credits,
		"RunReward",
		classId
	)
	return creditsGained, xpGained
end

function ProgressionService.PurchaseCosmetic(player: Player, cosmeticId: string): (boolean, string)
	local profile = ProgressionService.GetProfile(player)
	local cosmetic = ProgressionConfig.Cosmetics[cosmeticId]
	if not cosmetic then
		return false, "Cosmetic does not exist"
	end

	if profile.UnlockedCosmetics[cosmeticId] then
		profile.EquippedCosmetic = cosmeticId
		notify(player)
		task.spawn(saveProfile, player)
		AnalyticsService.LogEvent(player, "CosmeticEquipped", {
			CosmeticId = cosmeticId,
		})
		return true, "Equipped"
	end

	if profile.Credits < cosmetic.Cost then
		return false, "Insufficient Credits"
	end

	profile.Credits -= cosmetic.Cost
	profile.UnlockedCosmetics[cosmeticId] = true
	profile.EquippedCosmetic = cosmeticId
	notify(player)
	task.spawn(saveProfile, player)
	AnalyticsService.LogEconomyFlow(
		player,
		false,
		"Credits",
		cosmetic.Cost,
		profile.Credits,
		"CosmeticPurchase",
		cosmeticId
	)
	return true, "Purchased and Equipped"
end

function ProgressionService.CreateDefaultProfileForTest(): PlayerProfile
	return createDefaultProfile()
end

function ProgressionService.NormalizeProfileForTest(saved: unknown): PlayerProfile
	return normalizeProfile(saved)
end

function ProgressionService.NormalizeAccessibilityForTest(
	saved: unknown
): AccessibilityConfig.AccessibilitySettings
	return normalizeAccessibility(saved)
end

return ProgressionService
