--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)

local localPlayer = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("HoonangaRemotes")
local playAudioRemote = remotesFolder:WaitForChild("PlayAudioEffect") :: RemoteEvent

local engineSound: Sound? = nil
local activeVehicle: Model? = nil

local AudioController = {}

function AudioController.Start()
	playAudioRemote.OnClientEvent:Connect(function(effectId: string, position: Vector3?)
		local effect = AudioConfig.Effects[effectId]
		if not effect then
			return
		end

		local sound = Instance.new("Sound")
		sound.SoundId = effect.AssetId
		sound.Volume = effect.Volume
		sound.Pitch = effect.Pitch

		if position then
			local part = Instance.new("Part")
			part.Anchored = true
			part.CanCollide = false
			part.Transparency = 1
			part.Position = position
			part.Parent = Workspace
			sound.Parent = part
			sound.Ended:Connect(function()
				part:Destroy()
			end)
		else
			sound.Parent = Workspace
			sound.Ended:Connect(function()
				sound:Destroy()
			end)
		end
		sound:Play()
	end)

	RunService.RenderStepped:Connect(function()
		local character = localPlayer.Character
		local seat = if character
			then character:FindFirstChildOfClass("Humanoid") and (character:FindFirstChildOfClass(
				"Humanoid"
			) :: Humanoid).SeatPart
			else nil
		local vehicle = if seat then seat:FindFirstAncestorOfClass("Model") else nil

		if vehicle ~= activeVehicle then
			activeVehicle = vehicle
			if engineSound then
				engineSound:Destroy()
				engineSound = nil
			end

			if vehicle and vehicle.PrimaryPart then
				local sound = Instance.new("Sound")
				sound.Name = "EngineRPM"
				sound.Looped = true
				sound.Volume = 0.45
				sound.Pitch = AudioConfig.EngineMinPitch
				sound.SoundId = "rbxassetid://9114228000"
				sound.Parent = vehicle.PrimaryPart
				sound:Play()
				engineSound = sound
			end
		end

		if engineSound and activeVehicle and activeVehicle.PrimaryPart then
			local speed = activeVehicle.PrimaryPart.AssemblyLinearVelocity.Magnitude
			local speedRatio = math.clamp(speed / 120, 0, 1)
			engineSound.Pitch = AudioConfig.EngineMinPitch
				+ (AudioConfig.EngineMaxPitch - AudioConfig.EngineMinPitch) * speedRatio
		end
	end)
end

function AudioController.PlayLocalEffect(effectId: string)
	local effect = AudioConfig.Effects[effectId]
	if effect then
		local sound = Instance.new("Sound")
		sound.SoundId = effect.AssetId
		sound.Volume = effect.Volume
		sound.Pitch = effect.Pitch
		sound.Parent = Workspace
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end
end

return AudioController
