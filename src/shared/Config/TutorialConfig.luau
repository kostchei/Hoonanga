--!strict

export type TutorialStep = {
	StepId: number,
	Title: string,
	Message: string,
	ActionKeyHint: string,
}

local STEPS: { TutorialStep } = {
	{
		StepId = 1,
		Title = "DRIVE ANGRY",
		Message = "Press W or Push Left Trigger to accelerate forward",
		ActionKeyHint = "W / RT",
	},
	{
		StepId = 2,
		Title = "STEER & DRIFT",
		Message = "Use A/D or Left Stick to steer, Space for handbrake",
		ActionKeyHint = "A/D / Space",
	},
	{
		StepId = 3,
		Title = "AIM & FIRE",
		Message = "Aim with Mouse or Right Stick, Left Click to fire mounted weapon",
		ActionKeyHint = "LMB / RB",
	},
	{
		StepId = 4,
		Title = "CONVOY FUEL",
		Message = "Keep moving and collect glowing yellow fuel canisters on the road",
		ActionKeyHint = "FUEL",
	},
	{
		StepId = 5,
		Title = "ROUTE FORKS",
		Message = "Forks offer choices: Fuel vs Short, High Road vs Canyon",
		ActionKeyHint = "FORK",
	},
}

return {
	Steps = STEPS,
	DistanceThresholds = {
		Steering = 300,
		Combat = 800,
		Fuel = 1500,
		Forks = 2500,
	},
}
