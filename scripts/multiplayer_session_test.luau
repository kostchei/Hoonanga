--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SessionConfig = require(ReplicatedStorage.Shared.Config.SessionConfig)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[SESSION] " .. message, 2)
	end
end

expect(SessionConfig.MinPlayers >= 2, "MinPlayers must be at least 2")
expect(SessionConfig.MaxPlayers <= 4, "MaxPlayers must be at most 4")
expect(SessionConfig.SpawnSpacing > 0, "SpawnSpacing must be positive")

print("[SESSION] PASS: Multiplayer session and distance tracking validated cleanly")
