--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputModePolicy = require(ReplicatedStorage.Shared.InputModePolicy)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[M5_INPUT] " .. message, 2)
	end
end

expect(InputModePolicy.ShouldUnlockPointer("Lobby", false, false), "lobby must release the mouse")
expect(
	InputModePolicy.ShouldUnlockPointer("Countdown", false, false),
	"countdown must release the mouse"
)
expect(
	InputModePolicy.ShouldUnlockPointer("Results", false, false),
	"results must release the mouse"
)
expect(
	not InputModePolicy.ShouldUnlockPointer("InRun", false, false),
	"active driving must lock the mouse"
)
expect(
	InputModePolicy.ShouldUnlockPointer("InRun", true, false),
	"an in-run modal must release the mouse"
)
expect(
	InputModePolicy.ShouldUnlockPointer("InRun", false, true),
	"spectating must release the mouse"
)
expect(
	InputModePolicy.IsGameplayEnabled("InRun", false, false),
	"active driving input should be enabled"
)
expect(
	not InputModePolicy.IsGameplayEnabled("InRun", true, false),
	"modal-open driving input should be disabled"
)
expect(
	not InputModePolicy.IsGameplayEnabled("InRun", false, true),
	"spectator driving input should be disabled"
)

print("[M5_INPUT] PASS: phase-owned mouse and gameplay input policy is valid")
