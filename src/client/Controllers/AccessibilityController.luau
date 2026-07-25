--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AccessibilityConfig = require(ReplicatedStorage.Shared.Config.AccessibilityConfig)

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local currentSettings: AccessibilityConfig.AccessibilitySettings =
	AccessibilityConfig.DefaultSettings

local AccessibilityController = {}

function AccessibilityController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HoonangaAccessibility"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = true
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "AccessibilityPanel"
	panel.Position = UDim2.fromOffset(22, 310)
	panel.Size = UDim2.fromOffset(360, 110)
	panel.BackgroundColor3 = Color3.fromRGB(15, 18, 19)
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Text = "ACCESSIBILITY & CAMERA FOV"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextColor3 = Color3.fromRGB(255, 103, 65)
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.fromOffset(336, 20)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local fovLabel = Instance.new("TextLabel")
	fovLabel.Name = "FOVLabel"
	fovLabel.Text = string.format("FOV: %d° | Screen Shake: 100%%", currentSettings.FieldOfView)
	fovLabel.Font = Enum.Font.GothamMedium
	fovLabel.TextSize = 12
	fovLabel.TextColor3 = Color3.fromRGB(238, 220, 189)
	fovLabel.BackgroundTransparency = 1
	fovLabel.Position = UDim2.fromOffset(12, 32)
	fovLabel.Size = UDim2.fromOffset(336, 20)
	fovLabel.TextXAlignment = Enum.TextXAlignment.Left
	fovLabel.Parent = panel

	local fovButton = Instance.new("TextButton")
	fovButton.Name = "FOVButton"
	fovButton.Text = "CYCLE FOV (60° / 80° / 90° / 100°)"
	fovButton.Font = Enum.Font.GothamMedium
	fovButton.TextSize = 12
	fovButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	fovButton.BackgroundColor3 = Color3.fromRGB(64, 56, 52)
	fovButton.BorderSizePixel = 0
	fovButton.Position = UDim2.fromOffset(12, 60)
	fovButton.Size = UDim2.fromOffset(336, 36)
	fovButton.Parent = panel

	local fovOptions = { 60, 80, 90, 100, 110 }
	local fovIdx = 2

	fovButton.MouseButton1Click:Connect(function()
		fovIdx = (fovIdx % #fovOptions) + 1
		currentSettings.FieldOfView = fovOptions[fovIdx]
		fovLabel.Text =
			string.format("FOV: %d° | Screen Shake: 100%%", currentSettings.FieldOfView)
	end)

	RunService.RenderStepped:Connect(function()
		if camera and camera.FieldOfView ~= currentSettings.FieldOfView then
			camera.FieldOfView = currentSettings.FieldOfView
		end
	end)
end

function AccessibilityController.GetSettings(): AccessibilityConfig.AccessibilitySettings
	return currentSettings
end

function AccessibilityController.SetFOV(fov: number)
	currentSettings.FieldOfView =
		math.clamp(fov, AccessibilityConfig.MinFOV, AccessibilityConfig.MaxFOV)
	if camera then
		camera.FieldOfView = currentSettings.FieldOfView
	end
end

return AccessibilityController
