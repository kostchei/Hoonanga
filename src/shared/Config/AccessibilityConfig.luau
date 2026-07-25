--!strict

export type AccessibilitySettings = {
	FieldOfView: number,
	ScreenShakeMultiplier: number,
	ColorblindMode: "None" | "Protanopia" | "Deuteranopia" | "Tritanopia",
	SubtitlesEnabled: boolean,
	ReducedFlashing: boolean,
}

local DEFAULT_SETTINGS: AccessibilitySettings = {
	FieldOfView = 80,
	ScreenShakeMultiplier = 1.0,
	ColorblindMode = "None",
	SubtitlesEnabled = true,
	ReducedFlashing = false,
}

return {
	MinFOV = 60,
	MaxFOV = 110,
	DefaultFOV = 80,
	DefaultSettings = DEFAULT_SETTINGS,
}
