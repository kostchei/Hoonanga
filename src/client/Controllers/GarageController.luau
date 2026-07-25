--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("HoonangaRemotes")
local setReadyRemote = remotesFolder:WaitForChild("SetPlayerReady") :: RemoteEvent
local progressionUpdatedRemote = remotesFolder:WaitForChild("ProgressionUpdated") :: RemoteEvent

local isReady = false

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
	title.Text = "GARAGE & PROGRESSION"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(255, 103, 65)
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 10)
	title.Size = UDim2.fromOffset(336, 24)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "Info"
	infoLabel.Text = "Scrap: 0 | Class: Ute"
	infoLabel.Font = Enum.Font.GothamMedium
	infoLabel.TextSize = 13
	infoLabel.TextColor3 = Color3.fromRGB(238, 220, 189)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Position = UDim2.fromOffset(12, 38)
	infoLabel.Size = UDim2.fromOffset(336, 40)
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
end

return GarageController
