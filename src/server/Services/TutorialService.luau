--!strict

local ProgressionService = require(script.Parent.ProgressionService)
local RemoteService = require(script.Parent.RemoteService)

local TutorialService = {}

function TutorialService.Start()
	RemoteService.Get("CompleteTutorial").OnServerEvent:Connect(function(player: Player)
		ProgressionService.MarkTutorialCompleted(player)
	end)
end

function TutorialService.HasCompleted(player: Player): boolean
	return ProgressionService.GetProfile(player).TutorialCompleted
end

function TutorialService.MarkCompleted(player: Player)
	ProgressionService.MarkTutorialCompleted(player)
end

return TutorialService
