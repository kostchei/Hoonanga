--!strict

local Players = game:GetService("Players")

local TutorialService = {}

local completedTutorial: { [Player]: boolean } = {}

function TutorialService.Start()
	Players.PlayerAdded:Connect(function(player)
		completedTutorial[player] = false
	end)

	Players.PlayerRemoving:Connect(function(player)
		completedTutorial[player] = nil
	end)
end

function TutorialService.HasCompleted(player: Player): boolean
	return completedTutorial[player] == true
end

function TutorialService.MarkCompleted(player: Player)
	completedTutorial[player] = true
end

return TutorialService
