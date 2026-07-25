--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SessionConfig = require(ReplicatedStorage.Shared.Config.SessionConfig)
local ProgressionService = require(script.Parent.ProgressionService)
local RemoteService = require(script.Parent.RemoteService)
local UpgradeService = require(script.Parent.UpgradeService)
local VehicleService = require(script.Parent.VehicleService)

export type SessionState = "Lobby" | "Countdown" | "InRun" | "Ended"

export type PlayerSessionStats = {
	Player: Player,
	Distance: number,
	Kills: number,
	Pickups: number,
	Eliminated: boolean,
	Placement: number,
	ScrapEarned: number,
	XpEarned: number,
}

local state: SessionState = "Lobby"
local countdownTime = 0
local sessionStats: { [Player]: PlayerSessionStats } = {}
local spectateTargets: { [Player]: Player } = {}

local SessionService = {}

function SessionService.Start()
	Players.PlayerAdded:Connect(function(player)
		if state == "InRun" then
			spectateTargets[player] = SessionService.GetLeadActivePlayer()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		sessionStats[player] = nil
		spectateTargets[player] = nil
		SessionService.CheckSessionEndConditions()
	end)

	RemoteService.Get("RequestSpectateTarget").OnServerEvent
		:Connect(function(player: Player, direction: unknown)
			if state ~= "InRun" then
				return
			end
			local stats = sessionStats[player]
			if not stats or not stats.Eliminated then
				return
			end

			local activePlayers = SessionService.GetActiveLivingPlayers()
			if #activePlayers == 0 then
				return
			end

			local current = spectateTargets[player]
			local idx = table.find(activePlayers, current) or 1
			if direction == "Next" then
				idx = (idx % #activePlayers) + 1
			elseif direction == "Prev" then
				idx = ((idx - 2 + #activePlayers) % #activePlayers) + 1
			end
			spectateTargets[player] = activePlayers[idx]
			RemoteService.Get("RequestSpectateTarget"):FireClient(player, activePlayers[idx])
		end)

	task.spawn(function()
		while true do
			task.wait(1)
			SessionService.UpdateSessionLoop()
		end
	end)
end

function SessionService.GetState(): SessionState
	return state
end

function SessionService.GetStats(player: Player): PlayerSessionStats?
	return sessionStats[player]
end

function SessionService.UpdateSessionLoop()
	local allPlayers = Players:GetPlayers()
	if state == "Lobby" then
		if #allPlayers >= SessionConfig.MinPlayers then
			state = "Countdown"
			countdownTime = SessionConfig.LobbyCountdownSeconds
			RemoteService.Get("SessionStateChanged"):FireAllClients("Countdown", countdownTime)
		end
	elseif state == "Countdown" then
		if #allPlayers < SessionConfig.MinPlayers then
			state = "Lobby"
			RemoteService.Get("SessionStateChanged"):FireAllClients("Lobby", 0)
			return
		end

		countdownTime -= 1
		RemoteService.Get("SessionStateChanged"):FireAllClients("Countdown", countdownTime)

		if countdownTime <= 0 then
			SessionService.StartMatchRun()
		end
	elseif state == "InRun" then
		SessionService.UpdateInRunDistances()
		SessionService.BroadcastLeaderboard()
		SessionService.CheckSessionEndConditions()
	end
end

function SessionService.StartMatchRun()
	state = "InRun"
	UpgradeService.ResetSessionUpgrades()
	table.clear(sessionStats)
	table.clear(spectateTargets)

	local players = Players:GetPlayers()
	for _, player in players do
		sessionStats[player] = {
			Player = player,
			Distance = 0,
			Kills = 0,
			Pickups = 0,
			Eliminated = false,
			Placement = 0,
			ScrapEarned = 0,
			XpEarned = 0,
		}
		player:SetAttribute("Kills", 0)
	end

	RemoteService.Get("SessionStateChanged"):FireAllClients("InRun", 0)
end

function SessionService.UpdateInRunDistances()
	for player, stats in sessionStats do
		if not stats.Eliminated then
			local vehicle = VehicleService.GetPlayerVehicle(player)
			if vehicle and vehicle.PrimaryPart then
				local dist = math.max(0, -vehicle.PrimaryPart.Position.Z)
				stats.Distance = dist
				stats.Kills = player:GetAttribute("Kills") or 0
			end
		end
	end
end

function SessionService.OnPlayerEliminated(player: Player)
	local stats = sessionStats[player]
	if stats and not stats.Eliminated then
		stats.Eliminated = true

		local active = SessionService.GetActiveLivingPlayers()
		if #active > 0 then
			spectateTargets[player] = active[1]
			RemoteService.Get("RequestSpectateTarget"):FireClient(player, active[1])
		end

		SessionService.CheckSessionEndConditions()
	end
end

function SessionService.GetActiveLivingPlayers(): { Player }
	local living: { Player } = {}
	for player, stats in sessionStats do
		if not stats.Eliminated then
			table.insert(living, player)
		end
	end
	return living
end

function SessionService.GetLeadActivePlayer(): Player?
	local living = SessionService.GetActiveLivingPlayers()
	table.sort(living, function(a, b)
		local distA = sessionStats[a] and sessionStats[a].Distance or 0
		local distB = sessionStats[b] and sessionStats[b].Distance or 0
		return distA > distB
	end)
	return living[1]
end

function SessionService.CheckSessionEndConditions()
	if state ~= "InRun" then
		return
	end

	local living = SessionService.GetActiveLivingPlayers()
	if #living == 0 and #Players:GetPlayers() > 0 then
		SessionService.EndMatchRun()
	end
end

function SessionService.EndMatchRun()
	state = "Ended"

	local ranked: { PlayerSessionStats } = {}
	for _, stats in sessionStats do
		table.insert(ranked, stats)
	end

	table.sort(ranked, function(a, b)
		return a.Distance > b.Distance
	end)

	for place, stats in ranked do
		stats.Placement = place
		local profile = ProgressionService.GetProfile(stats.Player)
		local scrap, xp = ProgressionService.AwardRunRewards(
			stats.Player,
			stats.Distance,
			stats.Kills,
			stats.Pickups,
			place,
			profile.EquippedClass
		)
		stats.ScrapEarned = scrap
		stats.XpEarned = xp
	end

	RemoteService.Get("SessionStateChanged"):FireAllClients("Ended", ranked)

	task.delay(SessionConfig.PostMatchSummarySeconds, function()
		state = "Lobby"
		RemoteService.Get("SessionStateChanged"):FireAllClients("Lobby", 0)
	end)
end

function SessionService.BroadcastLeaderboard()
	local summary = {}
	for player, stats in sessionStats do
		table.insert(summary, {
			UserId = player.UserId,
			Name = player.Name,
			Distance = stats.Distance,
			Kills = stats.Kills,
			Eliminated = stats.Eliminated,
		})
	end
	table.sort(summary, function(a, b)
		return a.Distance > b.Distance
	end)
	RemoteService.Get("LeaderboardUpdated"):FireAllClients(summary)
end

return SessionService
