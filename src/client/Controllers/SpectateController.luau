--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local remotesFolder = ReplicatedStorage:WaitForChild("HoonangaRemotes")
local requestSpectateRemote = remotesFolder:WaitForChild("RequestSpectateTarget") :: RemoteEvent

local spectateTargetPlayer: Player? = nil
local isSpectating = false

local SpectateController = {}

function SpectateController.Start()
	requestSpectateRemote.OnClientEvent:Connect(function(targetPlayer: Player)
		spectateTargetPlayer = targetPlayer
		isSpectating = targetPlayer ~= nil
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
end

function SpectateController.IsSpectating(): boolean
	return isSpectating
end

function SpectateController.GetTargetPlayer(): Player?
	return spectateTargetPlayer
end

return SpectateController
