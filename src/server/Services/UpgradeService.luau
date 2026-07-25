--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local RemoteService = require(script.Parent.RemoteService)

export type ActiveUpgrade = UpgradeConfig.UpgradeDef

local activePlayerUpgrades: { [Player]: { [string]: ActiveUpgrade } } = {}

local UpgradeService = {}

function UpgradeService.Start()
	Players.PlayerAdded:Connect(function(player)
		activePlayerUpgrades[player] = {}
	end)

	Players.PlayerRemoving:Connect(function(player)
		activePlayerUpgrades[player] = nil
	end)

	RemoteService.Get("ClaimUpgrade").OnServerEvent
		:Connect(function(player: Player, upgradeId: unknown)
			if typeof(upgradeId) ~= "string" then
				return
			end

			local upgradeDef = UpgradeConfig.Upgrades[upgradeId]
			if not upgradeDef then
				return
			end

			UpgradeService.ApplyUpgrade(player, upgradeId)
		end)
end

function UpgradeService.ResetSessionUpgrades()
	for player, _ in activePlayerUpgrades do
		activePlayerUpgrades[player] = {}
		RemoteService.Get("ActiveUpgradesUpdated"):FireClient(player, {})
	end
end

function UpgradeService.ApplyUpgrade(player: Player, upgradeId: string)
	local playerUpgrades = activePlayerUpgrades[player]
	if not playerUpgrades then
		playerUpgrades = {}
		activePlayerUpgrades[player] = playerUpgrades
	end

	local upgradeDef = UpgradeConfig.Upgrades[upgradeId]
	if upgradeDef then
		playerUpgrades[upgradeId] = upgradeDef
		RemoteService.Get("ActiveUpgradesUpdated"):FireClient(player, playerUpgrades)
	end
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

return UpgradeService
