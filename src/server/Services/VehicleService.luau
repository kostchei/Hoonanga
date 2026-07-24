--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VehiclePhysics = require(ReplicatedStorage.Shared.VehiclePhysics)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local RemoteService = require(script.Parent.RemoteService)
local VehicleBuilder = require(script.Parent.VehicleBuilder)

local playerVehicles: { [Player]: Model } = {}

local function setNetworkOwner(vehicle: Model, player: Player?)
	local chassis = vehicle.PrimaryPart
	if not chassis then
		return
	end

	local canSet = chassis:CanSetNetworkOwnership()
	if not canSet then
		return
	end

	if player then
		chassis:SetNetworkOwner(player)
	else
		chassis:SetNetworkOwner(nil)
	end
end

local function bindSeat(vehicle: Model)
	local seat = vehicle:FindFirstChild("DriverSeat")
	if not seat or not seat:IsA("VehicleSeat") then
		return
	end

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		if not occupant then
			vehicle:SetAttribute("ServerThrottle", 0)
			vehicle:SetAttribute("ServerSteer", 0)
			vehicle:SetAttribute("ServerHandbrake", false)
			setNetworkOwner(vehicle, nil)
			VehiclePhysics.Reset(vehicle)
			return
		end

		local character = occupant.Parent
		local player = if character then Players:GetPlayerFromCharacter(character) else nil
		setNetworkOwner(vehicle, player)
	end)
end

local function seatPlayer(player: Player, character: Model)
	local vehicle = playerVehicles[player]
	if not vehicle or not vehicle.Parent then
		return
	end

	local humanoid = character:WaitForChild("Humanoid", 10)
	local seat = vehicle:FindFirstChild("DriverSeat")
	if humanoid and humanoid:IsA("Humanoid") and seat and seat:IsA("VehicleSeat") then
		character:PivotTo(vehicle:GetPivot() * CFrame.new(0, 5, 0))
		task.wait(0.2)
		seat:Sit(humanoid)
	end
end

local function addPlayer(player: Player)
	local vehiclesFolder = Workspace:WaitForChild("HoonangaWorld"):WaitForChild("Vehicles")
	local spawnOffset = (#Players:GetPlayers() - 1) * 12
	local spawn = WorldConfig.Spawn.Player * CFrame.new(spawnOffset, 0, 0)
	local vehicle = VehicleBuilder.CreateUte(
		vehiclesFolder,
		"PlayerUte_" .. player.UserId,
		spawn,
		Color3.fromRGB(184, 73, 42)
	)
	vehicle:SetAttribute("OwnerUserId", player.UserId)
	vehicle:SetAttribute("Team", "Player")
	playerVehicles[player] = vehicle
	bindSeat(vehicle)

	player.CharacterAdded:Connect(function(character)
		task.defer(seatPlayer, player, character)
	end)

	if player.Character then
		task.defer(seatPlayer, player, player.Character)
	end
end

local VehicleService = {}

function VehicleService.Start()
	RemoteService.Get("VehicleInput").OnServerEvent
		:Connect(function(player, throttle, steer, handbrake)
			if
				typeof(throttle) ~= "number"
				or typeof(steer) ~= "number"
				or typeof(handbrake) ~= "boolean"
			then
				return
			end

			local vehicle = playerVehicles[player]
			if not vehicle or not vehicle.Parent then
				return
			end

			local seat = vehicle:FindFirstChild("DriverSeat")
			if not seat or not seat:IsA("VehicleSeat") or not seat.Occupant then
				return
			end
			if Players:GetPlayerFromCharacter(seat.Occupant.Parent) ~= player then
				return
			end

			vehicle:SetAttribute("ServerThrottle", math.clamp(throttle, -1, 1))
			vehicle:SetAttribute("ServerSteer", math.clamp(steer, -1, 1))
			vehicle:SetAttribute("ServerHandbrake", handbrake)
		end)

	for _, player in Players:GetPlayers() do
		task.spawn(addPlayer, player)
	end
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local vehicle = playerVehicles[player]
		playerVehicles[player] = nil
		if vehicle then
			vehicle:Destroy()
		end
	end)
end

function VehicleService.GetPlayerVehicle(player: Player): Model?
	return playerVehicles[player]
end

return VehicleService
