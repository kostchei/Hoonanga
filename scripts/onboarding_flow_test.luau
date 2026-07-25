--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[TUTORIAL] " .. message, 2)
	end
end

expect(#TutorialConfig.Steps >= 5, "Must have at least 5 onboarding tutorial steps")
expect(TutorialConfig.Steps[1].StepId == 1, "First tutorial step must have StepId 1")

print("[TUTORIAL] PASS: Interactive onboarding tutorial steps validated cleanly")
