--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local ProgressionService = require(ServerScriptService.Server.Services.ProgressionService)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[PROGRESSION] " .. message, 2)
	end
end

expect(ProgressionConfig.ScrapPerKm > 0, "ScrapPerKm must be positive")
expect(ProgressionConfig.MasteryXpPerKm > 0, "MasteryXpPerKm must be positive")
expect(ProgressionConfig.PaintPalette ~= nil, "PaintPalette config missing")
expect(ProgressionConfig.Cosmetics.Default ~= nil, "Default cosmetic missing")

local migrated = ProgressionService.NormalizeProfileForTest({
	Scrap = 425,
	Wins = 4,
	Mastery = {
		Ute = 100,
		Biker = 275,
	},
	EquippedClass = "Biker",
	EquippedWeapon = "ForwardGun",
	EquippedSecondary = "NotAWeapon",
	UnlockedCosmetics = {
		Scavenger = true,
		ExploitPaint = true,
	},
	ProcessedRunIds = { "run-a", "run-b" },
})
expect(migrated.Version == 3, "profile did not migrate to schema v3")
expect(migrated.Credits == 425, "legacy Scrap did not migrate to Credits")
expect(migrated.EquippedClass == "Bike", "legacy Biker class did not migrate")
expect(migrated.Mastery.Bike == 275, "legacy Biker mastery did not migrate")
expect(migrated.OwnedVehicles.Ute, "baseline Ute ownership missing")
expect(migrated.OwnedVehicles.Roadtrain, "baseline Roadtrain ownership missing")
expect(migrated.OwnedVehicles.Bike, "baseline Bike ownership missing")
expect(migrated.UnlockedCosmetics.Scavenger, "valid cosmetic was not preserved")
expect(not migrated.UnlockedCosmetics.ExploitPaint, "unknown cosmetic was trusted")
expect(migrated.EquippedWeapon == "MachineGun", "invalid primary weapon was trusted")
expect(migrated.EquippedSecondary == "Pistol", "invalid secondary weapon was trusted")
expect(#migrated.ProcessedRunIds == 2, "processed run IDs were not preserved")
expect(not migrated.TutorialCompleted, "legacy profile unexpectedly completed onboarding")
expect(migrated.Accessibility.SubtitlesEnabled, "accessibility defaults were not migrated")

local settings = ProgressionService.NormalizeAccessibilityForTest({
	FieldOfView = 999,
	ScreenShakeMultiplier = -5,
	ColorblindMode = "ExploitMode",
	SubtitlesEnabled = false,
	ReducedFlashing = true,
})
expect(settings.FieldOfView == 110, "FOV was not clamped")
expect(settings.ScreenShakeMultiplier == 0, "screen shake was not clamped")
expect(settings.ColorblindMode == "None", "unknown color mode was trusted")
expect(not settings.SubtitlesEnabled, "subtitle preference was not retained")
expect(settings.ReducedFlashing, "reduced flashing preference was not retained")

print("[PROGRESSION] PASS: Progression configuration and DataStore schemas validated cleanly")
