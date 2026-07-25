--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessibilityConfig = require(ReplicatedStorage.Shared.Config.AccessibilityConfig)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[GAMEPAD] " .. message, 2)
	end
end

expect(AccessibilityConfig.MinFOV >= 60, "MinFOV must be at least 60")
expect(AccessibilityConfig.MaxFOV <= 120, "MaxFOV must be at most 120")
expect(AccessibilityConfig.DefaultFOV == 80, "DefaultFOV must be 80")

print("[GAMEPAD] PASS: Controller and accessibility configuration validated cleanly")
