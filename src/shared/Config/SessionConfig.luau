--!strict

return {
	-- Human slots. Exactly two AI competitors are added by SessionService, so
	-- one ready human produces the minimum three-convoy match.
	MinPlayers = 1,
	MaxPlayers = 4,
	AIPlayers = 2,
	MinCompetitors = 3,
	MaxCompetitors = 6,
	LobbyCountdownSeconds = 15,
	PostMatchSummarySeconds = 12,
	SpawnSpacing = 24,
	SpawnZ = 120,
	-- The final stretch. The run is open-ended until the field loses a
	-- competitor; at that point a finish line is placed this far along the
	-- road ahead of whoever is leading, and the run stops being a survival
	-- drive and becomes a race to it.
	FinalStretchLeadDistance = 3500,
	-- How long the green flag and its call-out stay on screen.
	FinalStretchBannerSeconds = 10,
}
