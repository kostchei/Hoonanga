--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
		if player then
			setNetworkOwner(vehicle, nil)
		end
	end)
end

local function createPlayerVehicle(player: Player): Model
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
	return vehicle
end

local function bindPlayerToVehicle(player: Player, character: Model)
	local vehicle = playerVehicles[player]
	if not vehicle or not vehicle.Parent then
		return
	end

	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local seat = vehicle:FindFirstChild("DriverSeat")
	if
		not humanoid
		or not humanoid:IsA("Humanoid")
		or not root
		or not root:IsA("BasePart")
		or not seat
		or not seat:IsA("VehicleSeat")
	then
		return
	end

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			descendant.Transparency = 1
		elseif descendant:IsA("Decal") then
			descendant.Transparency = 1
		end
	end

	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)

	character:PivotTo(seat.CFrame * CFrame.new(0, 2, 0))
	local existingWeld = root:FindFirstChild("VehicleCharacterWeld")
	if existingWeld then
		existingWeld:Destroy()
	end

	local weld = Instance.new("WeldConstraint")
	weld.Name = "VehicleCharacterWeld"
	weld.Part0 = seat
	weld.Part1 = root
	weld.Parent = root
	seat:Sit(humanoid)
	humanoid.Sit = true
	print(string.format("[Hoonanga] %s bound to %s", player.Name, vehicle.Name))

	task.delay(5, function()
		if not vehicle.Parent or not vehicle.PrimaryPart then
			warn(string.format("[Hoonanga] %s ute missing after bind", player.Name))
			return
		end
		print(
			string.format(
				"[Hoonanga] %s ute state: pos=(%.1f, %.1f, %.1f), hull=%s, destroyed=%s, weld=%s",
				player.Name,
				vehicle.PrimaryPart.Position.X,
				vehicle.PrimaryPart.Position.Y,
				vehicle.PrimaryPart.Position.Z,
				tostring(vehicle:GetAttribute("Hull")),
				tostring(vehicle:GetAttribute("Destroyed")),
				tostring(root:FindFirstChild("VehicleCharacterWeld") ~= nil)
			)
		)
	end)
end

local function addPlayer(player: Player)
	player:SetAttribute("Kills", 0)
	createPlayerVehicle(player)

	player.CharacterAdded:Connect(function(character)
		local vehicle = playerVehicles[player]
		if not vehicle or not vehicle.Parent or vehicle:GetAttribute("Destroyed") then
			if vehicle and vehicle.Parent then
				vehicle:Destroy()
			end
			createPlayerVehicle(player)
		end
		task.defer(bindPlayerToVehicle, player, character)
	end)

	if player.Character then
		task.defer(bindPlayerToVehicle, player, player.Character)
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

			if vehicle:GetAttribute("OwnerUserId") ~= player.UserId then
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

	RunService.Heartbeat:Connect(function(deltaTime)
		for _, vehicle in playerVehicles do
			if vehicle.Parent and not vehicle:GetAttribute("Destroyed") then
				local throttle = vehicle:GetAttribute("ServerThrottle")
				local steer = vehicle:GetAttribute("ServerSteer")
				local handbrake = vehicle:GetAttribute("ServerHandbrake")
				VehiclePhysics.Step(vehicle, {
					Throttle = if typeof(throttle) == "number" then throttle else 0,
					Steer = if typeof(steer) == "number" then steer else 0,
					Handbrake = handbrake == true,
				}, deltaTime)
			end
		end
	end)
end

function VehicleService.GetPlayerVehicle(player: Player): Model?
	return playerVehicles[player]
end

return VehicleService
