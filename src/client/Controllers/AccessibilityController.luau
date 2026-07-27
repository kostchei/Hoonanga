--!strict

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AccessibilityConfig = require(ReplicatedStorage.Shared.Config.AccessibilityConfig)
local InputModeController = require(script.Parent.InputModeController)

local localPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("HoonangaRemotes")
local progressionUpdatedRemote = remotes:WaitForChild("ProgressionUpdated") :: RemoteEvent
local updateSettingsRemote = remotes:WaitForChild("UpdateAccessibilitySettings") :: RemoteEvent
local getPlayerData = remotes:WaitForChild("GetPlayerData") :: RemoteFunction

local currentSettings: AccessibilityConfig.AccessibilitySettings = {
	FieldOfView = AccessibilityConfig.DefaultSettings.FieldOfView,
	ScreenShakeMultiplier = AccessibilityConfig.DefaultSettings.ScreenShakeMultiplier,
	ColorblindMode = AccessibilityConfig.DefaultSettings.ColorblindMode,
	SubtitlesEnabled = AccessibilityConfig.DefaultSettings.SubtitlesEnabled,
	ReducedFlashing = AccessibilityConfig.DefaultSettings.ReducedFlashing,
}

local panelVisible = false
local refreshUi: (() -> ())? = nil

local COLORBLIND_MODES: { AccessibilityConfig.ColorblindMode } = {
	"None",
	"Protanopia",
	"Deuteranopia",
	"Tritanopia",
}
local FOV_OPTIONS = { 60, 80, 90, 100, 110 }
local SHAKE_OPTIONS = { 0, 0.5, 1 }

local function applyVisualSettings()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView = currentSettings.FieldOfView
	end
	local correction = Lighting:FindFirstChild("HoonangaColorAccessibility")
	if not correction or not correction:IsA("ColorCorrectionEffect") then
		if correction then
			correction:Destroy()
		end
		correction = Instance.new("ColorCorrectionEffect")
		correction.Name = "HoonangaColorAccessibility"
		correction.Parent = Lighting
	end
	local effect = correction :: ColorCorrectionEffect
	if currentSettings.ColorblindMode == "Protanopia" then
		effect.TintColor = Color3.fromRGB(235, 245, 255)
		effect.Saturation = -0.12
	elseif currentSettings.ColorblindMode == "Deuteranopia" then
		effect.TintColor = Color3.fromRGB(245, 238, 255)
		effect.Saturation = -0.1
	elseif currentSettings.ColorblindMode == "Tritanopia" then
		effect.TintColor = Color3.fromRGB(255, 240, 225)
		effect.Saturation = -0.16
	else
		effect.TintColor = Color3.new(1, 1, 1)
		effect.Saturation = 0
	end
	localPlayer:SetAttribute("ScreenShakeMultiplier", currentSettings.ScreenShakeMultiplier)
	localPlayer:SetAttribute("SubtitlesEnabled", currentSettings.SubtitlesEnabled)
	localPlayer:SetAttribute("ReducedFlashing", currentSettings.ReducedFlashing)
	if refreshUi then
		refreshUi()
	end
end

local function submit()
	applyVisualSettings()
	updateSettingsRemote:FireServer(currentSettings)
end

local AccessibilityController = {}

function AccessibilityController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HoonangaAccessibility"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 30
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "AccessibilityPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(460, 390)
	panel.BackgroundColor3 = Color3.fromRGB(15, 18, 19)
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Text = "ACCESSIBILITY SETTINGS"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 19
	title.TextColor3 = Color3.fromRGB(255, 103, 65)
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 12)
	title.Size = UDim2.fromOffset(350, 30)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Text = "CLOSE"
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 12
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.BackgroundColor3 = Color3.fromRGB(184, 73, 42)
	closeButton.BorderSizePixel = 0
	closeButton.Position = UDim2.fromOffset(372, 14)
	closeButton.Size = UDim2.fromOffset(72, 28)
	closeButton.Parent = panel

	local buttons: { [string]: TextButton } = {}
	local function makeSettingButton(name: string, y: number): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.Font = Enum.Font.GothamMedium
		button.TextSize = 15
		button.TextColor3 = Color3.fromRGB(238, 220, 189)
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.BackgroundColor3 = Color3.fromRGB(48, 50, 49)
		button.BorderSizePixel = 0
		button.Position = UDim2.fromOffset(16, y)
		button.Size = UDim2.fromOffset(428, 52)
		button.Parent = panel
		buttons[name] = button
		return button
	end

	local fovButton = makeSettingButton("FieldOfView", 58)
	local shakeButton = makeSettingButton("ScreenShake", 116)
	local colorButton = makeSettingButton("ColorblindMode", 174)
	local subtitleButton = makeSettingButton("Subtitles", 232)
	local flashingButton = makeSettingButton("ReducedFlashing", 290)

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Text = "Press V or controller Start to open/close settings."
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 12
	hint.TextColor3 = Color3.fromRGB(180, 174, 164)
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(16, 350)
	hint.Size = UDim2.fromOffset(428, 24)
	hint.Parent = panel

	refreshUi = function()
		fovButton.Text =
			string.format("  FIELD OF VIEW                         %d", currentSettings.FieldOfView)
		shakeButton.Text = string.format(
			"  SCREEN SHAKE                         %d%%",
			math.floor(currentSettings.ScreenShakeMultiplier * 100)
		)
		colorButton.Text = "  COLOR VISION                          "
			.. string.upper(currentSettings.ColorblindMode)
		subtitleButton.Text = "  SUBTITLES                             "
			.. (if currentSettings.SubtitlesEnabled then "ON" else "OFF")
		flashingButton.Text = "  REDUCED FLASHING                      "
			.. (if currentSettings.ReducedFlashing then "ON" else "OFF")
	end

	local function toggle(open: boolean?)
		panelVisible = if open == nil then not panelVisible else open
		gui.Enabled = panelVisible
		InputModeController.SetModalOpen(panelVisible)
	end

	closeButton.MouseButton1Click:Connect(function()
		toggle(false)
	end)
	fovButton.MouseButton1Click:Connect(function()
		local index = table.find(FOV_OPTIONS, currentSettings.FieldOfView) or 2
		currentSettings.FieldOfView = FOV_OPTIONS[(index % #FOV_OPTIONS) + 1]
		submit()
	end)
	shakeButton.MouseButton1Click:Connect(function()
		local index = table.find(SHAKE_OPTIONS, currentSettings.ScreenShakeMultiplier) or 3
		currentSettings.ScreenShakeMultiplier = SHAKE_OPTIONS[(index % #SHAKE_OPTIONS) + 1]
		submit()
	end)
	colorButton.MouseButton1Click:Connect(function()
		local index = table.find(COLORBLIND_MODES, currentSettings.ColorblindMode) or 1
		currentSettings.ColorblindMode = COLORBLIND_MODES[(index % #COLORBLIND_MODES) + 1]
		submit()
	end)
	subtitleButton.MouseButton1Click:Connect(function()
		currentSettings.SubtitlesEnabled = not currentSettings.SubtitlesEnabled
		submit()
	end)
	flashingButton.MouseButton1Click:Connect(function()
		currentSettings.ReducedFlashing = not currentSettings.ReducedFlashing
		submit()
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.V then
			toggle()
		end
	end)

	local function acceptProfile(profile: any)
		if typeof(profile) ~= "table" or typeof(profile.Accessibility) ~= "table" then
			return
		end
		local settings = profile.Accessibility
		currentSettings.FieldOfView = settings.FieldOfView or currentSettings.FieldOfView
		currentSettings.ScreenShakeMultiplier = settings.ScreenShakeMultiplier
			or currentSettings.ScreenShakeMultiplier
		currentSettings.ColorblindMode = settings.ColorblindMode or currentSettings.ColorblindMode
		if typeof(settings.SubtitlesEnabled) == "boolean" then
			currentSettings.SubtitlesEnabled = settings.SubtitlesEnabled
		end
		if typeof(settings.ReducedFlashing) == "boolean" then
			currentSettings.ReducedFlashing = settings.ReducedFlashing
		end
		applyVisualSettings()
	end

	progressionUpdatedRemote.OnClientEvent:Connect(acceptProfile)
	task.spawn(function()
		local success, profile = pcall(function()
			return getPlayerData:InvokeServer()
		end)
		if success then
			acceptProfile(profile)
		end
	end)
	applyVisualSettings()
end

function AccessibilityController.Toggle()
	panelVisible = not panelVisible
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = if playerGui then playerGui:FindFirstChild("HoonangaAccessibility") else nil
	if gui and gui:IsA("ScreenGui") then
		gui.Enabled = panelVisible
	end
	InputModeController.SetModalOpen(panelVisible)
end

function AccessibilityController.GetSettings(): AccessibilityConfig.AccessibilitySettings
	return currentSettings
end

function AccessibilityController.SetFOV(fov: number)
	currentSettings.FieldOfView =
		math.clamp(fov, AccessibilityConfig.MinFOV, AccessibilityConfig.MaxFOV)
	submit()
end

return AccessibilityController
