--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local InputModePolicy = require(ReplicatedStorage.Shared.InputModePolicy)

local localPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("HoonangaRemotes")
local sessionStateRemote = remotes:WaitForChild("SessionStateChanged") :: RemoteEvent
local spectateRemote = remotes:WaitForChild("RequestSpectateTarget") :: RemoteEvent

local phase = "Lobby"
local modalOpen = false
local spectating = false

local function pointerShouldBeUnlocked(): boolean
	return InputModePolicy.ShouldUnlockPointer(phase, modalOpen, spectating)
end

local function apply()
	local unlocked = pointerShouldBeUnlocked()
	UserInputService.MouseBehavior = if unlocked
		then Enum.MouseBehavior.Default
		else Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = unlocked
end

local InputModeController = {}

function InputModeController.Start()
	sessionStateRemote.OnClientEvent:Connect(function(newPhase: string)
		phase = newPhase
		if phase ~= "InRun" then
			modalOpen = false
		end
		if phase == "Lobby" or phase == "Countdown" or phase == "Results" then
			spectating = false
		end
		apply()
	end)

	spectateRemote.OnClientEvent:Connect(function(target: Player?)
		spectating = target ~= nil
		apply()
	end)

	localPlayer.CharacterAdded:Connect(function()
		task.defer(apply)
	end)
	UserInputService.WindowFocused:Connect(apply)
	RunService:BindToRenderStep("HoonangaInputMode", Enum.RenderPriority.Camera.Value + 10, apply)
	apply()
end

function InputModeController.SetModalOpen(open: boolean)
	modalOpen = open
	apply()
end

function InputModeController.IsPointerUnlocked(): boolean
	return pointerShouldBeUnlocked()
end

function InputModeController.IsGameplayEnabled(): boolean
	return InputModePolicy.IsGameplayEnabled(phase, modalOpen, spectating)
end

function InputModeController.GetPhase(): string
	return phase
end

function InputModeController.ApplyForTest(
	testPhase: string,
	isModal: boolean,
	isSpectating: boolean
)
	phase = testPhase
	modalOpen = isModal
	spectating = isSpectating
	apply()
end

return InputModeController
