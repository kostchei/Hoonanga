--!strict

local Players = game:GetService("Players")

local RemoteService = require(script.Parent.RemoteService)

local AudioService = {}

function AudioService.Start()
	-- AudioService ready
end

function AudioService.PlayEffectAt(effectId: string, position: Vector3, ignorePlayer: Player?)
	for _, player in Players:GetPlayers() do
		if player ~= ignorePlayer then
			RemoteService.Get("PlayAudioEffect"):FireClient(player, effectId, position)
		end
	end
end

function AudioService.PlayGlobalEffect(effectId: string, player: Player?)
	if player then
		RemoteService.Get("PlayAudioEffect"):FireClient(player, effectId, nil)
	else
		RemoteService.Get("PlayAudioEffect"):FireAllClients(effectId, nil)
	end
end

return AudioService
