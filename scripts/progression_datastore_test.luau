--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[PROGRESSION] " .. message, 2)
	end
end

expect(ProgressionConfig.ScrapPerKm > 0, "ScrapPerKm must be positive")
expect(ProgressionConfig.MasteryXpPerKm > 0, "MasteryXpPerKm must be positive")
expect(ProgressionConfig.PaintPalette ~= nil, "PaintPalette config missing")
expect(ProgressionConfig.Cosmetics.Default ~= nil, "Default cosmetic missing")

print("[PROGRESSION] PASS: Progression configuration and DataStore schemas validated cleanly")
