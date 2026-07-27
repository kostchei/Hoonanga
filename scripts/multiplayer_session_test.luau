--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SessionConfig = require(ReplicatedStorage.Shared.Config.SessionConfig)
local SessionService = require(ServerScriptService.Server.Services.SessionService)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[SESSION] " .. message, 2)
	end
end

expect(SessionConfig.MinPlayers == 1, "one human must be enough with two AI rivals")
expect(SessionConfig.MaxPlayers <= 4, "MaxPlayers must be at most 4")
expect(SessionConfig.AIPlayers == 2, "every match must add exactly two AI rivals")
expect(
	SessionConfig.MinPlayers + SessionConfig.AIPlayers == SessionConfig.MinCompetitors,
	"minimum human and AI slots do not produce three competitors"
)
expect(
	SessionConfig.MaxPlayers + SessionConfig.AIPlayers == SessionConfig.MaxCompetitors,
	"maximum human and AI slots do not produce six competitors"
)
expect(SessionConfig.SpawnSpacing > 0, "SpawnSpacing must be positive")

local fakePlayers = {
	{ UserId = 40 },
	{ UserId = 10 },
	{ UserId = 30 },
	{ UserId = 20 },
	{ UserId = 60 },
	{ UserId = 50 },
} :: any
local roster = SessionService.BuildRosterForTest(fakePlayers)
expect(#roster == SessionConfig.MaxPlayers, "roster was not capped at MaxPlayers")
for index = 2, #roster do
	expect(roster[index - 1].UserId < roster[index].UserId, "roster ordering is not deterministic")
end
expect(roster[1].UserId == 10, "lowest UserId was not admitted first")
expect(roster[#roster].UserId == 40, "unexpected player admitted beyond the cap")

local soloAIClasses = SessionService.BuildAIClassesForTest({ "Ute" }, 7501)
expect(#soloAIClasses == 2, "solo roster did not allocate two AI rivals")
expect(table.find(soloAIClasses, "Roadtrain") ~= nil, "solo Ute did not add a Roadtrain")
expect(table.find(soloAIClasses, "Bike") ~= nil, "solo Ute did not add a Bike")

print("[SESSION] PASS: one-to-four humans produce three-to-six competitors with two AI")
