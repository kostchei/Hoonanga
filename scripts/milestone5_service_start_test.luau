--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local services = ServerScriptService.Server.Services
local GarageService = require(services.GarageService)
local ProgressionService = require(services.ProgressionService)
local RemoteService = require(services.RemoteService)
local SessionService = require(services.SessionService)
local UpgradeService = require(services.UpgradeService)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[M5_START] " .. message, 2)
	end
end

RemoteService.Start()
ProgressionService.Start()
GarageService.Start()
UpgradeService.Start()
SessionService.Start()

local remotes = ReplicatedStorage:FindFirstChild("HoonangaRemotes")
expect(remotes ~= nil, "remote folder was not created")
expect(remotes:FindFirstChild("LobbyStatusUpdated") ~= nil, "lobby status remote missing")
expect(remotes:FindFirstChild("UpgradeOffered") ~= nil, "upgrade offer remote missing")
expect(SessionService.GetState() == "Lobby", "session did not start in Lobby")
expect(GarageService.IsSelectionOpen(), "garage selection did not start open")

print("[M5_START] PASS: Milestone 5 services start in a valid lobby state")
