--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)

local localPlayer = Players.LocalPlayer
local activeStepIndex = 1
local currentStep: TutorialConfig.TutorialStep? = TutorialConfig.Steps[1]
local isDismissed = false

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
	panel.Size = UDim2.fromOffset(500, 64)
	panel.BackgroundColor3 = Color3.fromRGB(15, 18, 19)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextColor3 = Color3.fromRGB(255, 103, 65)
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.fromOffset(400, 20)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local msg = Instance.new("TextLabel")
	msg.Name = "Message"
	msg.Font = Enum.Font.GothamMedium
	msg.TextSize = 13
	msg.TextColor3 = Color3.fromRGB(238, 220, 189)
	msg.BackgroundTransparency = 1
	msg.Position = UDim2.fromOffset(12, 28)
	msg.Size = UDim2.fromOffset(400, 28)
	msg.TextXAlignment = Enum.TextXAlignment.Left
	msg.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Text = "X CLOSE [N]"
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 11
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.BackgroundColor3 = Color3.fromRGB(184, 73, 42)
	closeButton.BorderSizePixel = 0
	closeButton.Position = UDim2.fromOffset(418, 12)
	closeButton.Size = UDim2.fromOffset(70, 40)
	closeButton.Parent = panel

	local function dismissTutorial()
		isDismissed = true
		currentStep = nil
		gui.Enabled = false
	end

	closeButton.MouseButton1Click:Connect(dismissTutorial)

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe or isDismissed then
			return
		end
		if input.KeyCode == Enum.KeyCode.N then
			dismissTutorial()
		end
	end)

	local function updateStepUI()
		if isDismissed then
			gui.Enabled = false
			return
		end
		if currentStep then
			title.Text = string.format(
				"TUTORIAL (%d/5): %s [%s]",
				activeStepIndex,
				currentStep.Title,
				currentStep.ActionKeyHint
			)
			msg.Text = currentStep.Message
			gui.Enabled = true
		else
			gui.Enabled = false
		end
	end

	updateStepUI()

	RunService.RenderStepped:Connect(function()
		if isDismissed then
			return
		end

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
				dismissTutorial()
			end
		end
	end)
end

return OnboardingController
