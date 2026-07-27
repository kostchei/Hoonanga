--!strict

local InputModePolicy = {}

function InputModePolicy.ShouldUnlockPointer(
	phase: string,
	modalOpen: boolean,
	spectating: boolean
): boolean
	return phase == "Lobby" or phase == "Countdown" or phase == "Results" or modalOpen or spectating
end

function InputModePolicy.IsGameplayEnabled(
	phase: string,
	modalOpen: boolean,
	spectating: boolean
): boolean
	return phase == "InRun" and not modalOpen and not spectating
end

return InputModePolicy
