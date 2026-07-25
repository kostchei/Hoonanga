--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraController = require(script.Parent.CameraController)
local VehicleLocator = require(script.Parent.VehicleLocator)

local localPlayer = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("HoonangaRemotes")
local setReadyRemote = remotesFolder:WaitForChild("SetPlayerReady") :: RemoteEvent
local progressionUpdatedRemote = remotesFolder:WaitForChild("ProgressionUpdated") :: RemoteEvent

local isReady = false
local isManuallyHidden = false
local isManuallyOpened = false

local GarageController = {}

function GarageController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HoonangaGarage"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = true
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "GaragePanel"
	panel.Position = UDim2.fromOffset(22, 60)
	panel.Size = UDim2.fromOffset(360, 240)
	panel.BackgroundColor3 = Color3.fromRGB(15, 18, 19)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Text = "GARAGE & PROGRESSION [G]"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextColor3 = Color3.fromRGB(255, 103, 65)
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 10)
	title.Size = UDim2.fromOffset(260, 24)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Text = "X HIDE [G]"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 11
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.BackgroundColor3 = Color3.fromRGB(184, 73, 42)
	closeBtn.BorderSizePixel = 0
	closeBtn.Position = UDim2.fromOffset(276, 10)
	closeBtn.Size = UDim2.fromOffset(72, 24)
	closeBtn.Parent = panel

	local function hideGarage()
		isManuallyHidden = true
		isManuallyOpened = false
		gui.Enabled = false
		CameraController.SetMouseUnlocked(false)
	end

	local function toggleGarage()
		if gui.Enabled then
			hideGarage()
		else
			isManuallyHidden = false
			isManuallyOpened = true
			gui.Enabled = true
			CameraController.SetMouseUnlocked(true)
		end
	end

	closeBtn.MouseButton1Click:Connect(hideGarage)

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then
			return
		end
		if input.KeyCode == Enum.KeyCode.G then
			toggleGarage()
		end
	end)

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "Info"
	infoLabel.Text = "Scrap: 0 | Class: Ute"
	infoLabel.Font = Enum.Font.GothamMedium
	infoLabel.TextSize = 13
	infoLabel.TextColor3 = Color3.fromRGB(238, 220, 189)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Position = UDim2.fromOffset(12, 38)
	infoLabel.Size = UDim2.fromOffset(336, 130)
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.TextYAlignment = Enum.TextYAlignment.Top
	infoLabel.Parent = panel

	local readyButton = Instance.new("TextButton")
	readyButton.Name = "ReadyButton"
	readyButton.Text = "READY FOR RUN"
	readyButton.Font = Enum.Font.GothamBold
	readyButton.TextSize = 14
	readyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	readyButton.BackgroundColor3 = Color3.fromRGB(184, 73, 42)
	readyButton.BorderSizePixel = 0
	readyButton.Position = UDim2.fromOffset(12, 180)
	readyButton.Size = UDim2.fromOffset(336, 40)
	readyButton.Parent = panel

	readyButton.MouseButton1Click:Connect(function()
		isReady = not isReady
		readyButton.Text = if isReady then "READY! (CLICK TO UNREADY)" else "READY FOR RUN"
		readyButton.BackgroundColor3 = if isReady
			then Color3.fromRGB(42, 184, 73)
			else Color3.fromRGB(184, 73, 42)
		setReadyRemote:FireServer(isReady)
	end)

	progressionUpdatedRemote.OnClientEvent:Connect(function(profile: any)
		if profile then
			infoLabel.Text = string.format(
				"Scrap: %d\nClass: %s | Cosmetic: %s",
				profile.Scrap or 0,
				profile.EquippedClass or "Ute",
				profile.EquippedCosmetic or "Default"
			)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local activeVehicle = VehicleLocator.ForPlayer(localPlayer)
		if activeVehicle then
			if not isManuallyOpened then
				gui.Enabled = false
			end
		else
			if not isManuallyHidden then
				gui.Enabled = true
			end
		end
	end)
end

return GarageController
