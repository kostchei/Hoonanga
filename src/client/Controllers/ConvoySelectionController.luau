--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local selectRemote = ReplicatedStorage:WaitForChild("HoonangaRemotes")
	:WaitForChild("SelectConvoyClass") :: RemoteEvent
local sessionStateRemote = ReplicatedStorage:WaitForChild("HoonangaRemotes")
	:WaitForChild("SessionStateChanged") :: RemoteEvent

local CHOICES = {
	HoonangaRoadtrain = { Key = Enum.KeyCode.F1, ClassId = "Roadtrain" },
	HoonangaUtes = { Key = Enum.KeyCode.F2, ClassId = "Ute" },
	HoonangaBikes = { Key = Enum.KeyCode.F3, ClassId = "Bike" },
}

local ConvoySelectionController = {}

function ConvoySelectionController.Start()
	local currentPhase = "Lobby"
	local gui = Instance.new("ScreenGui")
	gui.Name = "HoonangaConvoySelector"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Name = "Selector"
	label.Position = UDim2.fromOffset(22, 22)
	label.Size = UDim2.fromOffset(360, 30)
	label.BackgroundColor3 = Color3.fromRGB(15, 18, 19)
	label.BackgroundTransparency = 0.28
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(238, 220, 189)
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = " LOBBY: F1 ROADTRAIN   F2 TWO UTES   F3 THREE BIKES"
	label.Parent = gui

	sessionStateRemote.OnClientEvent:Connect(function(newPhase: string)
		currentPhase = newPhase
		gui.Enabled = newPhase == "Lobby"
	end)

	for actionName, choice in CHOICES do
		ContextActionService:BindActionAtPriority(actionName, function(_, state)
			if state == Enum.UserInputState.Begin and currentPhase == "Lobby" then
				selectRemote:FireServer(choice.ClassId)
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 90, choice.Key)
	end
end

return ConvoySelectionController
