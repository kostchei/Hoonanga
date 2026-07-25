--!strict

local Players = game:GetService("Players")

local ProgressionService = require(script.Parent.ProgressionService)
local RemoteService = require(script.Parent.RemoteService)

local readyPlayers: { [Player]: boolean } = {}

local GarageService = {}

function GarageService.Start()
	RemoteService.Get("SetPlayerReady").OnServerEvent
		:Connect(function(player: Player, isReady: unknown)
			if typeof(isReady) ~= "boolean" then
				return
			end
			readyPlayers[player] = isReady
			GarageService.OnReadyChanged(player, isReady)
		end)

	RemoteService.Get("SelectGarageLoadout").OnServerEvent
		:Connect(function(player: Player, payload: unknown)
			if typeof(payload) ~= "table" then
				return
			end
			local data = payload :: { [string]: any }
			local profile = ProgressionService.GetProfile(player)

			if
				typeof(data.Class) == "string"
				and (data.Class == "Ute" or data.Class == "Roadtrain" or data.Class == "Biker")
			then
				profile.EquippedClass = data.Class
			end
			if typeof(data.PrimaryWeapon) == "string" then
				profile.EquippedWeapon = data.PrimaryWeapon
			end
			if typeof(data.SecondaryWeapon) == "string" then
				profile.EquippedSecondary = data.SecondaryWeapon
			end
			if
				typeof(data.CosmeticId) == "string" and profile.UnlockedCosmetics[data.CosmeticId]
			then
				profile.EquippedCosmetic = data.CosmeticId
			end

			RemoteService.Get("ProgressionUpdated"):FireClient(player, profile)
		end)

	Players.PlayerRemoving:Connect(function(player)
		readyPlayers[player] = nil
	end)
end

function GarageService.IsReady(player: Player): boolean
	return readyPlayers[player] == true
end

function GarageService.ResetReadyState()
	table.clear(readyPlayers)
end

function GarageService.OnReadyChanged(_player: Player, _isReady: boolean)
	-- Hook for SessionService / UI notifications
end

return GarageService
