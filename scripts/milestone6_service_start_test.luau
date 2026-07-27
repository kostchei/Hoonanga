--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BuildConfig = require(ReplicatedStorage.Shared.Config.BuildConfig)
local services = ServerScriptService.Server.Services
local AnalyticsService = require(services.AnalyticsService)
local AudioService = require(services.AudioService)
local EconomyService = require(services.EconomyService)
local ProgressionService = require(services.ProgressionService)
local RemoteService = require(services.RemoteService)
local TutorialService = require(services.TutorialService)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[M6_START] " .. message, 2)
	end
end

RemoteService.Start()
AnalyticsService.Start()
EconomyService.Start()
AudioService.Start()
TutorialService.Start()
ProgressionService.Start()

local remotes = ReplicatedStorage.HoonangaRemotes
expect(remotes:FindFirstChild("UpdateAccessibilitySettings") ~= nil, "settings remote missing")
expect(remotes:FindFirstChild("CompleteTutorial") ~= nil, "tutorial remote missing")
expect(BuildConfig.Milestone == 6, "build milestone is not 6")
expect(BuildConfig.ProfileSchemaVersion == 3, "build profile schema is not 3")

print("[M6_START] PASS: Milestone 6 launch services start with the expected schema")
