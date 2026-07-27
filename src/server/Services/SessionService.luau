--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AIRosterPolicy = require(ReplicatedStorage.Shared.AIRosterPolicy)
local SessionConfig = require(ReplicatedStorage.Shared.Config.SessionConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local AIService = require(script.Parent.AIService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local ConvoyService = require(script.Parent.ConvoyService)
local GarageService = require(script.Parent.GarageService)
local ProgressionService = require(script.Parent.ProgressionService)
local RemoteService = require(script.Parent.RemoteService)
local RoadService = require(script.Parent.RoadService)
local UpgradeService = require(script.Parent.UpgradeService)
local VehicleService = require(script.Parent.VehicleService)

export type SessionState = "Lobby" | "Countdown" | "InRun" | "Results"

export type PlayerSessionStats = {
	Player: Player,
	ClassId: string,
	Distance: number,
	Kills: number,
	Pickups: number,
	Eliminated: boolean,
	EndReason: string?,
	Placement: number,
	CreditsEarned: number,
	XpEarned: number,
}

local state: SessionState = "Lobby"
local countdownTime = 0
local runSerial = 0
local currentRunId = ""
local sessionStats: { [Player]: PlayerSessionStats } = {}
local activeRoster: { Player } = {}
local pendingRoster: { Player } = {}
local activeAIConvoys: { ConvoyService.ConvoyRecord } = {}
local spectateTargets: { [Player]: Player } = {}
local started = false
-- How many convoys, human and AI, the run started with. The run turns into a
-- race the moment that number drops.
local startingCompetitors = 0
local finalStretchStarted = false
local finishDistance = 0

local SessionService = {}

local function isInRoster(player: Player, roster: { Player }): boolean
	return table.find(roster, player) ~= nil
end

local function rosterStillReady(roster: { Player }): boolean
	if #roster < SessionConfig.MinPlayers then
		return false
	end
	for _, player in roster do
		if player.Parent ~= Players or not GarageService.IsReady(player) then
			return false
		end
	end
	return true
end

local function buildReadyRoster(): { Player }
	local ready = GarageService.GetReadyPlayers()
	local roster: { Player } = {}
	for index = 1, math.min(#ready, SessionConfig.MaxPlayers) do
		table.insert(roster, ready[index])
	end
	return roster
end

local function lobbyStatus()
	local ready = GarageService.GetReadyPlayers()
	local players = {}
	for _, player in Players:GetPlayers() do
		table.insert(players, {
			UserId = player.UserId,
			Name = player.Name,
			Ready = GarageService.IsReady(player),
			ClassId = GarageService.GetSelectedClass(player),
		})
	end
	table.sort(players, function(a, b)
		return a.UserId < b.UserId
	end)
	return {
		State = state,
		ReadyCount = #ready,
		MinPlayers = SessionConfig.MinPlayers,
		MaxPlayers = SessionConfig.MaxPlayers,
		AIPlayers = SessionConfig.AIPlayers,
		TotalCompetitors = math.min(
			SessionConfig.MaxCompetitors,
			math.max(#ready, SessionConfig.MinPlayers) + SessionConfig.AIPlayers
		),
		Countdown = countdownTime,
		Players = players,
	}
end

local function broadcastLobbyStatus()
	RemoteService.Get("LobbyStatusUpdated"):FireAllClients(lobbyStatus())
end

local function setState(newState: SessionState, data: any?)
	state = newState
	RemoteService.Get("SessionStateChanged"):FireAllClients(newState, data)
	broadcastLobbyStatus()
end

local function clearMatchConvoys()
	AIService.ResetCompetitors()
	for _, record in ConvoyService.GetAll() do
		ConvoyService.Remove(record, true)
	end
	table.clear(activeAIConvoys)
	VehicleService.RemoveAllPlayerConvoys()
end

local function spawnAIRivals(
	humanClasses: { string },
	matchSeed: number,
	firstRosterSlot: number,
	totalCompetitors: number
): { ConvoyService.ConvoyRecord }
	local classes = AIRosterPolicy.AllocateClasses(humanClasses, SessionConfig.AIPlayers, matchSeed)
	local center = (totalCompetitors - 1) / 2
	local records = {}
	for aiSlot, classId in classes do
		local rosterSlot = firstRosterSlot + aiSlot - 1
		local offsetX = (rosterSlot - 1 - center) * SessionConfig.SpawnSpacing
		local spawnCFrame = WorldConfig.Spawn.Player * CFrame.new(offsetX, 0, 0)
		local record = ConvoyService.Create(0, "Enemy", classId, spawnCFrame)
		record.Model:SetAttribute("CompetitorType", "AI")
		record.Model:SetAttribute("CompetitorName", string.format("Rival %d", aiSlot))
		record.Model:SetAttribute("RosterSlot", rosterSlot)
		for memberIndex, vehicle in record.Members do
			vehicle.Name = string.format("Rival%d_%s_%02d", aiSlot, classId, memberIndex)
		end
		AIService.RegisterCompetitor(record, matchSeed, aiSlot)
		table.insert(records, record)
	end
	return records
end

local function spawnRoster(matchSeed: number)
	local humanClasses = {}
	for _, player in activeRoster do
		table.insert(humanClasses, GarageService.GetSelectedClass(player))
	end
	local totalCompetitors = #activeRoster + SessionConfig.AIPlayers
	local center = (totalCompetitors - 1) / 2
	for index, player in activeRoster do
		local classId = humanClasses[index]
		local offsetX = (index - 1 - center) * SessionConfig.SpawnSpacing
		local spawnCFrame = WorldConfig.Spawn.Player * CFrame.new(offsetX, 0, 0)
		VehicleService.SpawnMatchConvoy(player, classId, spawnCFrame)
	end
	activeAIConvoys = spawnAIRivals(humanClasses, matchSeed, #activeRoster + 1, totalCompetitors)
end

-- Everything still in the running: living humans plus AI rivals whose convoy
-- has not ended.
local function countLivingCompetitors(): number
	local alive = #SessionService.GetActiveLivingPlayers()
	for _, record in activeAIConvoys do
		if not record.Ended then
			alive += 1
		end
	end
	return alive
end

local function leadRunDistance(): number
	local best = 0
	for _, stats in sessionStats do
		best = math.max(best, stats.Distance)
	end
	for _, record in activeAIConvoys do
		if not record.Ended then
			best = math.max(best, record.RunDistance)
		end
	end
	return best
end

-- The field losing a competitor is what ends the open-ended part of the run:
-- a finish line goes down ahead of the leader and everyone still driving is
-- told to go for it.
local function beginFinalStretch()
	finalStretchStarted = true
	finishDistance = leadRunDistance() + SessionConfig.FinalStretchLeadDistance
	RoadService.SpawnFinishLine(finishDistance)
	RemoteService.Get("FinalStretchStarted"):FireAllClients({
		FinishDistance = finishDistance,
		BannerSeconds = SessionConfig.FinalStretchBannerSeconds,
	})
end

function SessionService.Start()
	if started then
		return
	end
	started = true

	GarageService.ReadyChangedSignal():Connect(function()
		broadcastLobbyStatus()
	end)
	GarageService.SelectionChangedSignal():Connect(function()
		broadcastLobbyStatus()
	end)

	ConvoyService.ConvoyEndedSignal():Connect(function(record, reason)
		if state ~= "InRun" then
			return
		end
		if record.OwnerUserId <= 0 then
			-- An AI rival dropping out thins the field just as a human does,
			-- so it can open the final stretch on its own.
			SessionService.CheckSessionEndConditions()
			return
		end
		local player = Players:GetPlayerByUserId(record.OwnerUserId)
		if player and sessionStats[player] then
			SessionService.OnPlayerEliminated(player, reason)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		if state == "InRun" then
			local target = SessionService.GetLeadActivePlayer()
			if target then
				spectateTargets[player] = target
				RemoteService.Get("RequestSpectateTarget"):FireClient(player, target)
			end
		end
		task.defer(broadcastLobbyStatus)
	end)

	Players.PlayerRemoving:Connect(function(player)
		spectateTargets[player] = nil
		if state == "Countdown" and isInRoster(player, pendingRoster) then
			SessionService.ReturnToLobby()
		elseif state == "InRun" then
			local stats = sessionStats[player]
			if stats and not stats.Eliminated then
				stats.Eliminated = true
				stats.EndReason = "Disconnected"
				VehicleService.RemovePlayerConvoy(player, true)
				SessionService.CheckSessionEndConditions()
			end
		end
		task.defer(broadcastLobbyStatus)
	end)

	RemoteService.Get("RequestSpectateTarget").OnServerEvent
		:Connect(function(player: Player, direction: unknown)
			if state ~= "InRun" then
				return
			end
			local stats = sessionStats[player]
			local isLateSpectator = not isInRoster(player, activeRoster)
			if not isLateSpectator and (not stats or not stats.Eliminated) then
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
			else
				return
			end
			spectateTargets[player] = activePlayers[idx]
			RemoteService.Get("RequestSpectateTarget"):FireClient(player, activePlayers[idx])
		end)

	GarageService.SetSelectionOpen(true)
	broadcastLobbyStatus()
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

function SessionService.GetRunId(): string
	return currentRunId
end

function SessionService.GetStats(player: Player): PlayerSessionStats?
	return sessionStats[player]
end

function SessionService.UpdateSessionLoop()
	if state == "Lobby" then
		local roster = buildReadyRoster()
		if #roster >= SessionConfig.MinPlayers then
			pendingRoster = roster
			countdownTime = SessionConfig.LobbyCountdownSeconds
			setState("Countdown", countdownTime)
		else
			broadcastLobbyStatus()
		end
	elseif state == "Countdown" then
		if not rosterStillReady(pendingRoster) then
			SessionService.ReturnToLobby()
			return
		end
		countdownTime -= 1
		RemoteService.Get("SessionStateChanged"):FireAllClients("Countdown", countdownTime)
		broadcastLobbyStatus()
		if countdownTime <= 0 then
			SessionService.StartMatchRun()
		end
	elseif state == "InRun" then
		SessionService.UpdateInRunDistances()
		SessionService.BroadcastLeaderboard()
		SessionService.CheckFinishLine()
		SessionService.CheckSessionEndConditions()
	end
end

function SessionService.StartMatchRun()
	if state ~= "Countdown" or not rosterStillReady(pendingRoster) then
		SessionService.ReturnToLobby()
		return
	end

	runSerial += 1
	currentRunId = string.format(
		"%s:%d:%d",
		if game.JobId ~= "" then game.JobId else "Studio",
		os.time(),
		runSerial
	)
	activeRoster = table.clone(pendingRoster)
	table.clear(pendingRoster)
	table.clear(sessionStats)
	table.clear(spectateTargets)
	GarageService.SetSelectionOpen(false)
	UpgradeService.ResetSessionUpgrades()
	finalStretchStarted = false
	finishDistance = 0

	clearMatchConvoys()
	RoadService.Reset()
	local seed = math.floor(os.clock() * 1000000) % (2 ^ 31 - 1)
	RoadService.Start(seed)

	for _, player in activeRoster do
		local classId = GarageService.GetSelectedClass(player)
		sessionStats[player] = {
			Player = player,
			ClassId = classId,
			Distance = 0,
			Kills = 0,
			Pickups = 0,
			Eliminated = false,
			EndReason = nil,
			Placement = 0,
			CreditsEarned = 0,
			XpEarned = 0,
		}
		player:SetAttribute("Kills", 0)
		player:SetAttribute("Pickups", 0)
		player:SetAttribute("RunEnded", false)
		player:SetAttribute("RunEndReason", nil)
		AnalyticsService.LogEvent(player, "MatchStarted", {
			RunId = currentRunId,
			ClassId = classId,
			HumanPlayers = #activeRoster,
			RoadSeed = seed,
		})
	end

	spawnRoster(seed)
	startingCompetitors = #activeRoster + #activeAIConvoys
	setState("InRun", {
		RunId = currentRunId,
		Seed = seed,
		AICompetitors = SessionConfig.AIPlayers,
		TotalCompetitors = #activeRoster + #activeAIConvoys,
	})
	for _, player in activeRoster do
		local playerSeed = math.abs(seed + player.UserId * 9973) % (2 ^ 31 - 1)
		UpgradeService.OfferRandomUpgrades(player, 3, playerSeed)
	end
end

function SessionService.UpdateInRunDistances()
	for player, stats in sessionStats do
		local convoy = ConvoyService.GetForPlayer(player)
		if convoy then
			stats.Distance = math.max(stats.Distance, convoy.RunDistance)
		end
		stats.Kills = player:GetAttribute("Kills") or stats.Kills
		stats.Pickups = player:GetAttribute("Pickups") or stats.Pickups
	end
end

function SessionService.OnPlayerEliminated(player: Player, reason: string?)
	local stats = sessionStats[player]
	if state ~= "InRun" or not stats or stats.Eliminated then
		return
	end
	stats.Eliminated = true
	stats.EndReason = reason or "Eliminated"
	local convoy = ConvoyService.GetForPlayer(player)
	if convoy then
		stats.Distance = math.max(stats.Distance, convoy.RunDistance)
	end
	AnalyticsService.LogEvent(player, "ConvoyEliminated", {
		RunId = currentRunId,
		Reason = stats.EndReason or "Eliminated",
		Distance = stats.Distance,
		ClassId = stats.ClassId,
	})

	local active = SessionService.GetActiveLivingPlayers()
	if #active > 0 then
		spectateTargets[player] = active[1]
		RemoteService.Get("RequestSpectateTarget"):FireClient(player, active[1])
	end
	SessionService.CheckSessionEndConditions()
end

function SessionService.GetActiveLivingPlayers(): { Player }
	local living: { Player } = {}
	for player, stats in sessionStats do
		if not stats.Eliminated and player.Parent == Players then
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

-- Crossing the gate ends the run for everyone: whoever got there is furthest
-- down the road, so the existing distance ranking already places them first.
function SessionService.CheckFinishLine()
	if state ~= "InRun" or not finalStretchStarted then
		return
	end
	for _, stats in sessionStats do
		if not stats.Eliminated and stats.Distance >= finishDistance then
			stats.EndReason = "Finished"
			SessionService.EndMatchRun()
			return
		end
	end
end

function SessionService.CheckSessionEndConditions()
	if state ~= "InRun" then
		return
	end
	if #SessionService.GetActiveLivingPlayers() == 0 then
		SessionService.EndMatchRun()
		return
	end
	if not finalStretchStarted and countLivingCompetitors() < startingCompetitors then
		beginFinalStretch()
	end
end

function SessionService.EndMatchRun()
	if state ~= "InRun" then
		return
	end
	SessionService.UpdateInRunDistances()
	VehicleService.SetMatchInputEnabled(false)

	local ranked: { PlayerSessionStats } = {}
	for _, stats in sessionStats do
		table.insert(ranked, stats)
	end
	table.sort(ranked, function(a, b)
		if a.Distance == b.Distance then
			return a.Player.UserId < b.Player.UserId
		end
		return a.Distance > b.Distance
	end)

	local publicResults = {}
	for place, stats in ranked do
		stats.Placement = place
		if stats.Player.Parent == Players then
			local credits, xp = ProgressionService.AwardRunRewards(
				stats.Player,
				stats.Distance,
				stats.Kills,
				stats.Pickups,
				place,
				stats.ClassId,
				currentRunId,
				place == 1,
				place ~= 1 and stats.Eliminated
			)
			stats.CreditsEarned = credits
			stats.XpEarned = xp
		end
		table.insert(publicResults, {
			UserId = stats.Player.UserId,
			Name = stats.Player.Name,
			ClassId = stats.ClassId,
			Distance = stats.Distance,
			Kills = stats.Kills,
			Pickups = stats.Pickups,
			Eliminated = stats.Eliminated,
			EndReason = stats.EndReason,
			Placement = place,
			CreditsEarned = stats.CreditsEarned,
			XpEarned = stats.XpEarned,
		})
		if stats.Player.Parent == Players then
			AnalyticsService.LogEvent(stats.Player, "MatchCompleted", {
				RunId = currentRunId,
				Placement = place,
				Distance = stats.Distance,
				Kills = stats.Kills,
				Pickups = stats.Pickups,
				ClassId = stats.ClassId,
			})
		end
	end

	setState("Results", publicResults)
	task.delay(SessionConfig.PostMatchSummarySeconds, function()
		if state ~= "Results" then
			return
		end
		clearMatchConvoys()
		table.clear(activeRoster)
		table.clear(sessionStats)
		table.clear(spectateTargets)
		currentRunId = ""
		GarageService.ResetReadyState()
		GarageService.SetSelectionOpen(true)
		setState("Lobby", lobbyStatus())
	end)
end

function SessionService.ReturnToLobby()
	table.clear(pendingRoster)
	countdownTime = 0
	GarageService.SetSelectionOpen(true)
	setState("Lobby", lobbyStatus())
end

function SessionService.BroadcastLeaderboard()
	local summary = {}
	for player, stats in sessionStats do
		table.insert(summary, {
			UserId = player.UserId,
			Name = player.Name,
			ClassId = stats.ClassId,
			Distance = stats.Distance,
			Kills = stats.Kills,
			Eliminated = stats.Eliminated,
		})
	end
	table.sort(summary, function(a, b)
		return a.Distance > b.Distance
	end)
	for rank, entry in summary do
		local player = Players:GetPlayerByUserId(entry.UserId)
		if player then
			player:SetAttribute("DistanceRank", rank)
		end
	end
	RemoteService.Get("LeaderboardUpdated"):FireAllClients(summary)
end

function SessionService.BuildRosterForTest(players: { Player }): { Player }
	local result = table.clone(players)
	table.sort(result, function(a, b)
		return a.UserId < b.UserId
	end)
	while #result > SessionConfig.MaxPlayers do
		table.remove(result)
	end
	return result
end

function SessionService.BuildAIClassesForTest(
	humanClasses: { string },
	matchSeed: number
): { string }
	return AIRosterPolicy.AllocateClasses(humanClasses, SessionConfig.AIPlayers, matchSeed)
end

function SessionService.SpawnAIRivalsForTest(
	humanClasses: { string },
	matchSeed: number
): { ConvoyService.ConvoyRecord }
	activeAIConvoys = spawnAIRivals(
		humanClasses,
		matchSeed,
		#humanClasses + 1,
		#humanClasses + SessionConfig.AIPlayers
	)
	return table.clone(activeAIConvoys)
end

return SessionService
