--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local VehicleLocator = require(script.Parent.VehicleLocator)

local remotesFolder = ReplicatedStorage:WaitForChild("HoonangaRemotes")
local requestSpectateRemote = remotesFolder:WaitForChild("RequestSpectateTarget") :: RemoteEvent
local sessionStateRemote = remotesFolder:WaitForChild("SessionStateChanged") :: RemoteEvent

local spectateTargetPlayer: Player? = nil
local isSpectating = false

local SpectateController = {}

function SpectateController.Start()
	requestSpectateRemote.OnClientEvent:Connect(function(targetPlayer: Player?)
		spectateTargetPlayer = targetPlayer
		isSpectating = targetPlayer ~= nil
	end)

	sessionStateRemote.OnClientEvent:Connect(function(state: string)
		if state == "Lobby" or state == "Results" then
			spectateTargetPlayer = nil
			isSpectating = false
			Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe or not isSpectating then
			return
		end
		if input.KeyCode == Enum.KeyCode.E then
			requestSpectateRemote:FireServer("Next")
		elseif input.KeyCode == Enum.KeyCode.Q then
			requestSpectateRemote:FireServer("Prev")
		end
	end)

	RunService.RenderStepped:Connect(function()
		local targetPlayer = spectateTargetPlayer
		if not isSpectating or not targetPlayer then
			return
		end
		local camera = Workspace.CurrentCamera
		local vehicle = VehicleLocator.ForPlayer(targetPlayer)
		if vehicle and vehicle.PrimaryPart then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = vehicle.PrimaryPart
			return
		end
		local humanoid = if targetPlayer.Character
			then targetPlayer.Character:FindFirstChildOfClass("Humanoid")
			else nil
		if humanoid then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end
	end)
end

function SpectateController.IsSpectating(): boolean
	return isSpectating
end

function SpectateController.GetTargetPlayer(): Player?
	return spectateTargetPlayer
end

return SpectateController
