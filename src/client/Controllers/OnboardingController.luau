--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)

local localPlayer = Players.LocalPlayer
local activeStepIndex = 1
local currentStep: TutorialConfig.TutorialStep? = TutorialConfig.Steps[1]

local OnboardingController = {}

function OnboardingController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HoonangaOnboarding"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = true
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "TutorialBanner"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 80)
	panel.Size = UDim2.fromOffset(480, 60)
	panel.BackgroundColor3 = Color3.fromRGB(15, 18, 19)
	panel.BackgroundTransparency = 0.2
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextColor3 = Color3.fromRGB(255, 103, 65)
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.fromOffset(456, 20)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local msg = Instance.new("TextLabel")
	msg.Name = "Message"
	msg.Font = Enum.Font.GothamMedium
	msg.TextSize = 13
	msg.TextColor3 = Color3.fromRGB(238, 220, 189)
	msg.BackgroundTransparency = 1
	msg.Position = UDim2.fromOffset(12, 28)
	msg.Size = UDim2.fromOffset(456, 26)
	msg.TextXAlignment = Enum.TextXAlignment.Left
	msg.Parent = panel

	local function updateStepUI()
		if currentStep then
			title.Text =
				string.format("TUTORIAL: %s [%s]", currentStep.Title, currentStep.ActionKeyHint)
			msg.Text = currentStep.Message
			gui.Enabled = true
		else
			gui.Enabled = false
		end
	end

	updateStepUI()

	RunService.RenderStepped:Connect(function()
		local character = localPlayer.Character
		local seat = if character
			then character:FindFirstChildOfClass("Humanoid") and (character:FindFirstChildOfClass(
				"Humanoid"
			) :: Humanoid).SeatPart
			else nil
		local vehicle = if seat then seat:FindFirstAncestorOfClass("Model") else nil

		if vehicle and vehicle.PrimaryPart then
			local speed = vehicle.PrimaryPart.AssemblyLinearVelocity.Magnitude
			local dist = math.max(0, -vehicle.PrimaryPart.Position.Z)

			if activeStepIndex == 1 and speed > 10 then
				activeStepIndex = 2
				currentStep = TutorialConfig.Steps[2]
				updateStepUI()
			elseif activeStepIndex == 2 and dist > 300 then
				activeStepIndex = 3
				currentStep = TutorialConfig.Steps[3]
				updateStepUI()
			elseif activeStepIndex == 3 and dist > 800 then
				activeStepIndex = 4
				currentStep = TutorialConfig.Steps[4]
				updateStepUI()
			elseif activeStepIndex == 4 and dist > 1500 then
				activeStepIndex = 5
				currentStep = TutorialConfig.Steps[5]
				updateStepUI()
			elseif activeStepIndex == 5 and dist > 2500 then
				currentStep = nil
				updateStepUI()
			end
		end
	end)
end

return OnboardingController
