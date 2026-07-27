--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local ProgressionService = require(script.Parent.ProgressionService)
local RemoteService = require(script.Parent.RemoteService)

local VALID_CLASSES = {
	Ute = true,
	Roadtrain = true,
	Bike = true,
}
local VALID_PRIMARY_WEAPONS = {
	MachineGun = true,
	RocketLauncher = true,
	Flamethrower = true,
}
local VALID_SECONDARY_WEAPONS = {
	Pistol = true,
	Molotov = true,
}
local REQUEST_INTERVAL = 0.15

local readyPlayers: { [Player]: boolean } = {}
local lastRequestAt: { [Player]: number } = {}
local selectionOpen = true
local readyChanged = Instance.new("BindableEvent")
local selectionChanged = Instance.new("BindableEvent")
local started = false

local function requestAllowed(player: Player): boolean
	local now = Workspace:GetServerTimeNow()
	local last = lastRequestAt[player] or 0
	if now - last < REQUEST_INTERVAL then
		return false
	end
	lastRequestAt[player] = now
	return true
end

local function validWeapon(weaponId: unknown, allowed: { [string]: boolean }): boolean
	return typeof(weaponId) == "string"
		and allowed[weaponId] == true
		and WeaponConfig.Weapons[weaponId] ~= nil
end

local function setSelectedClass(player: Player, classId: unknown): boolean
	if
		not selectionOpen
		or readyPlayers[player] == true
		or typeof(classId) ~= "string"
		or VALID_CLASSES[classId] ~= true
	then
		return false
	end
	local profile = ProgressionService.GetProfile(player)
	if profile.OwnedVehicles[classId] ~= true then
		return false
	end
	profile.EquippedClass = classId
	ProgressionService.Notify(player)
	selectionChanged:Fire(player, classId)
	return true
end

local GarageService = {}

function GarageService.Start()
	if started then
		return
	end
	started = true

	RemoteService.Get("SetPlayerReady").OnServerEvent
		:Connect(function(player: Player, isReady: unknown)
			if not requestAllowed(player) or not selectionOpen or typeof(isReady) ~= "boolean" then
				return
			end
			local profile = ProgressionService.GetProfile(player)
			if VALID_CLASSES[profile.EquippedClass] ~= true then
				return
			end
			readyPlayers[player] = isReady
			player:SetAttribute("LobbyReady", isReady)
			readyChanged:Fire(player, isReady)
		end)

	RemoteService.Get("SelectConvoyClass").OnServerEvent
		:Connect(function(player: Player, classId: unknown)
			if requestAllowed(player) then
				setSelectedClass(player, classId)
			end
		end)

	RemoteService.Get("SelectGarageLoadout").OnServerEvent
		:Connect(function(player: Player, payload: unknown)
			if
				not requestAllowed(player)
				or not selectionOpen
				or readyPlayers[player] == true
				or typeof(payload) ~= "table"
			then
				return
			end
			local data = payload :: { [string]: any }
			local profile = ProgressionService.GetProfile(player)

			if data.Class ~= nil then
				setSelectedClass(player, data.Class)
			end
			if validWeapon(data.PrimaryWeapon, VALID_PRIMARY_WEAPONS) then
				profile.EquippedWeapon = data.PrimaryWeapon
			end
			if validWeapon(data.SecondaryWeapon, VALID_SECONDARY_WEAPONS) then
				profile.EquippedSecondary = data.SecondaryWeapon
			end
			if
				typeof(data.CosmeticId) == "string"
				and ProgressionConfig.Cosmetics[data.CosmeticId] ~= nil
				and profile.UnlockedCosmetics[data.CosmeticId]
			then
				profile.EquippedCosmetic = data.CosmeticId
			end

			ProgressionService.Notify(player)
			selectionChanged:Fire(player, profile.EquippedClass)
		end)

	for _, player in Players:GetPlayers() do
		player:SetAttribute("LobbyReady", false)
	end
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("LobbyReady", false)
	end)
	Players.PlayerRemoving:Connect(function(player)
		readyPlayers[player] = nil
		lastRequestAt[player] = nil
	end)
end

function GarageService.IsReady(player: Player): boolean
	return readyPlayers[player] == true
end

function GarageService.GetReadyPlayers(): { Player }
	local result: { Player } = {}
	for player, isReady in readyPlayers do
		if isReady and player.Parent == Players then
			table.insert(result, player)
		end
	end
	table.sort(result, function(a, b)
		return a.UserId < b.UserId
	end)
	return result
end

function GarageService.GetSelectedClass(player: Player): string
	return ProgressionService.GetProfile(player).EquippedClass
end

function GarageService.SetSelectionOpen(open: boolean)
	selectionOpen = open
	if not open then
		for player in readyPlayers do
			player:SetAttribute("LobbyReady", true)
		end
	end
end

function GarageService.IsSelectionOpen(): boolean
	return selectionOpen
end

function GarageService.ResetReadyState()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("LobbyReady", false)
	end
	table.clear(readyPlayers)
	readyChanged:Fire(nil, false)
end

function GarageService.ReadyChangedSignal(): RBXScriptSignal
	return readyChanged.Event
end

function GarageService.SelectionChangedSignal(): RBXScriptSignal
	return selectionChanged.Event
end

function GarageService.SetSelectedClassForTest(player: Player, classId: string): boolean
	return setSelectedClass(player, classId)
end

return GarageService
