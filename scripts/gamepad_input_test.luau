--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessibilityConfig = require(ReplicatedStorage.Shared.Config.AccessibilityConfig)
local ControllerConfig = require(ReplicatedStorage.Shared.Config.ControllerConfig)
local ControllerInput = require(ReplicatedStorage.Shared.ControllerInput)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[GAMEPAD] " .. message, 2)
	end
end

expect(AccessibilityConfig.MinFOV >= 60, "MinFOV must be at least 60")
expect(AccessibilityConfig.MaxFOV <= 120, "MaxFOV must be at most 120")
expect(AccessibilityConfig.DefaultFOV == 80, "DefaultFOV must be 80")
expect(ControllerConfig.Bindings.Fire == "R1", "controller fire binding missing")
expect(ControllerConfig.Bindings.LookAim == "RightStick", "controller aim binding missing")
expect(ControllerConfig.Bindings.Settings == "Start", "controller settings binding missing")
expect(Enum.KeyCode.ButtonStart ~= nil, "controller Start key is unavailable")
expect(ControllerInput.ApplyDeadzone(0.1, 0.16) == 0, "stick deadzone was not applied")
local throttle, steer = ControllerInput.ComposeDriveInput(0.8, 1, 0.25, 0.16, 0.08)
expect(throttle > 0.7 and throttle <= 1, "trigger drive input was not composed")
expect(steer > 0.7 and steer <= 1, "steering input was not composed")
expect(ControllerInput.WrapSlot(1, -1, 5) == 5, "weapon selection did not wrap backward")
expect(AccessibilityConfig.DefaultSettings.SubtitlesEnabled, "subtitles must default to enabled")

print("[GAMEPAD] PASS: Complete controller and accessibility policy validated cleanly")
