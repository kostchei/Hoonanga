--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local RemoteService = require(script.Parent.RemoteService)

local AudioService = {}

function AudioService.Start()
	-- AudioService ready
end

function AudioService.PlayEffectAt(effectId: string, position: Vector3, ignorePlayer: Player?)
	if AudioConfig.Effects[effectId] == nil then
		return
	end
	for _, player in Players:GetPlayers() do
		if player ~= ignorePlayer then
			RemoteService.Get("PlayAudioEffect"):FireClient(player, effectId, position)
		end
	end
end

function AudioService.PlayGlobalEffect(effectId: string, player: Player?)
	if AudioConfig.Effects[effectId] == nil then
		return
	end
	if player then
		RemoteService.Get("PlayAudioEffect"):FireClient(player, effectId, nil)
	else
		RemoteService.Get("PlayAudioEffect"):FireAllClients(effectId, nil)
	end
end

return AudioService
