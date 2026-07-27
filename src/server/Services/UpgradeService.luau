--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local ConvoyService = require(script.Parent.ConvoyService)
local RemoteService = require(script.Parent.RemoteService)

export type ActiveUpgrade = UpgradeConfig.UpgradeDef

local activePlayerUpgrades: { [Player]: { [string]: ActiveUpgrade } } = {}
local pendingOffers: { [Player]: { [string]: boolean } } = {}
local lastClaimAt: { [Player]: number } = {}
local started = false

local function initializePlayer(player: Player)
	activePlayerUpgrades[player] = {}
	pendingOffers[player] = {}
end

local function buildRandomOffer(count: number, seed: number): { string }
	local candidates: { string } = {}
	for upgradeId in UpgradeConfig.Upgrades do
		table.insert(candidates, upgradeId)
	end
	table.sort(candidates)

	local random = Random.new(seed)
	for index = #candidates, 2, -1 do
		local swapIndex = random:NextInteger(1, index)
		candidates[index], candidates[swapIndex] = candidates[swapIndex], candidates[index]
	end

	local selected: { string } = {}
	for index = 1, math.min(math.max(0, count), #candidates) do
		table.insert(selected, candidates[index])
	end
	return selected
end

local UpgradeService = {}

function UpgradeService.Start()
	if started then
		return
	end
	started = true

	for _, player in Players:GetPlayers() do
		initializePlayer(player)
	end
	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(function(player)
		activePlayerUpgrades[player] = nil
		pendingOffers[player] = nil
		lastClaimAt[player] = nil
	end)

	RemoteService.Get("ClaimUpgrade").OnServerEvent
		:Connect(function(player: Player, upgradeId: unknown)
			local now = Workspace:GetServerTimeNow()
			if typeof(upgradeId) ~= "string" or now - (lastClaimAt[player] or 0) < 0.2 then
				return
			end
			lastClaimAt[player] = now

			local offers = pendingOffers[player]
			if not offers or offers[upgradeId] ~= true then
				return
			end
			offers[upgradeId] = nil
			table.clear(offers)
			UpgradeService.ApplyUpgrade(player, upgradeId)
			RemoteService.Get("UpgradeOffered"):FireClient(player, {})
		end)
end

function UpgradeService.ResetSessionUpgrades()
	for player in activePlayerUpgrades do
		activePlayerUpgrades[player] = {}
		pendingOffers[player] = {}
		RemoteService.Get("ActiveUpgradesUpdated"):FireClient(player, {})
		RemoteService.Get("UpgradeOffered"):FireClient(player, {})
	end
end

function UpgradeService.OfferUpgrades(player: Player, upgradeIds: { string }): { string }
	local offers: { [string]: boolean } = {}
	local public: { string } = {}
	for _, upgradeId in upgradeIds do
		if UpgradeConfig.Upgrades[upgradeId] and not offers[upgradeId] then
			offers[upgradeId] = true
			table.insert(public, upgradeId)
		end
	end
	pendingOffers[player] = offers
	RemoteService.Get("UpgradeOffered"):FireClient(player, public)
	return public
end

function UpgradeService.OfferRandomUpgrades(player: Player, count: number, seed: number): { string }
	return UpgradeService.OfferUpgrades(player, buildRandomOffer(count, seed))
end

function UpgradeService.ApplyUpgrade(player: Player, upgradeId: string): boolean
	local upgradeDef = UpgradeConfig.Upgrades[upgradeId]
	if not upgradeDef then
		return false
	end
	local playerUpgrades = activePlayerUpgrades[player]
	if not playerUpgrades then
		playerUpgrades = {}
		activePlayerUpgrades[player] = playerUpgrades
	end
	playerUpgrades[upgradeId] = upgradeDef
	UpgradeService.ApplyToConvoy(player, ConvoyService.GetForPlayer(player))
	RemoteService.Get("ActiveUpgradesUpdated"):FireClient(player, playerUpgrades)
	return true
end

function UpgradeService.GetActiveUpgrades(player: Player): { [string]: ActiveUpgrade }
	return activePlayerUpgrades[player] or {}
end

function UpgradeService.GetModifier(player: Player, stat: string): number
	local upgrades = UpgradeService.GetActiveUpgrades(player)
	local mult = 1.0

	for _, upgrade in upgrades do
		if stat == "HullMult" and upgrade.HullMult then
			mult *= upgrade.HullMult
		elseif stat == "SpeedMult" and upgrade.SpeedMult then
			mult *= upgrade.SpeedMult
		elseif stat == "FuelCapMult" and upgrade.FuelCapMult then
			mult *= upgrade.FuelCapMult
		elseif stat == "GripMult" and upgrade.GripMult then
			mult *= upgrade.GripMult
		elseif stat == "HeatCoolMult" and upgrade.HeatCoolMult then
			mult *= upgrade.HeatCoolMult
		end
	end

	return mult
end

function UpgradeService.ApplyToConvoy(player: Player, record: ConvoyService.ConvoyRecord?)
	if not record or record.Ended then
		return
	end

	local hullMult = UpgradeService.GetModifier(player, "HullMult")
	local speedMult = UpgradeService.GetModifier(player, "SpeedMult")
	local fuelMult = UpgradeService.GetModifier(player, "FuelCapMult")
	local gripMult = UpgradeService.GetModifier(player, "GripMult")
	local heatCoolMult = UpgradeService.GetModifier(player, "HeatCoolMult")

	local baseFuel = record.Model:GetAttribute("UpgradeBaseMaxFuel")
	if typeof(baseFuel) ~= "number" then
		baseFuel = record.MaxFuel
		record.Model:SetAttribute("UpgradeBaseMaxFuel", baseFuel)
	end
	local previousMaxFuel = record.MaxFuel
	local fuelRatio = if previousMaxFuel > 0 then record.Fuel / previousMaxFuel else 1
	record.MaxFuel = baseFuel * fuelMult
	record.Fuel = math.clamp(record.MaxFuel * fuelRatio, 0, record.MaxFuel)
	record.Model:SetAttribute("MaxFuel", record.MaxFuel)
	record.Model:SetAttribute("Fuel", record.Fuel)

	for _, vehicle in record.Members do
		local currentMax = vehicle:GetAttribute("MaxHull")
		if typeof(currentMax) ~= "number" then
			continue
		end
		local baseHull = vehicle:GetAttribute("UpgradeBaseMaxHull")
		if typeof(baseHull) ~= "number" then
			baseHull = currentMax
			vehicle:SetAttribute("UpgradeBaseMaxHull", baseHull)
		end
		local currentHull = vehicle:GetAttribute("Hull")
		local hullRatio = if currentMax > 0 and typeof(currentHull) == "number"
			then currentHull / currentMax
			else 1
		local newMaxHull = baseHull * hullMult
		vehicle:SetAttribute("MaxHull", newMaxHull)
		vehicle:SetAttribute("Hull", math.clamp(newMaxHull * hullRatio, 0, newMaxHull))
		vehicle:SetAttribute("MaxFuel", record.MaxFuel)
		vehicle:SetAttribute("Fuel", record.Fuel)
		vehicle:SetAttribute("UpgradeSpeedMultiplier", speedMult)
		vehicle:SetAttribute("UpgradeGripMultiplier", gripMult)
		vehicle:SetAttribute("UpgradeHeatCoolMultiplier", heatCoolMult)
	end
end

function UpgradeService.HasPendingOfferForTest(player: Player, upgradeId: string): boolean
	local offers = pendingOffers[player]
	return offers ~= nil and offers[upgradeId] == true
end

function UpgradeService.BuildRandomOfferForTest(count: number, seed: number): { string }
	return buildRandomOffer(count, seed)
end

return UpgradeService
