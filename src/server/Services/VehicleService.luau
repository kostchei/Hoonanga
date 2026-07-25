--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ConvoyConfig = require(ReplicatedStorage.Shared.Config.ConvoyConfig)
local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
local VehiclePhysics = require(ReplicatedStorage.Shared.VehiclePhysics)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local ConvoyService = require(script.Parent.ConvoyService)
local RemoteService = require(script.Parent.RemoteService)

type ValidationState = {
	Position: Vector3,
	CheckedAt: number,
}

local VALIDATION_INTERVAL = 0.25
local VALIDATION_SPEED_MULTIPLIER = 1.5
local VALIDATION_DISTANCE_TOLERANCE = 10
local VALIDATION_VERTICAL_TOLERANCE = 45
local IMPACT_GRACE_WINDOW = 0.5

local validationStates: { [Player]: ValidationState } = {}
local boundSeats: { [VehicleSeat]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function setNetworkOwner(vehicle: Model, player: Player?)
	local chassis = vehicle.PrimaryPart
	if not chassis or not chassis:CanSetNetworkOwnership() then
		return
	end
	chassis:SetNetworkOwner(player)
	vehicle:SetAttribute("NetworkOwnerUserId", if player then player.UserId else nil)
end

local function isClientOwned(chassis: BasePart, player: Player): boolean
	if chassis.Anchored then
		return false
	end
	local ok, owner = pcall(function()
		return chassis:GetNetworkOwner()
	end)
	return ok and owner == player
end

local function bindSeat(vehicle: Model)
	local seat = vehicle:FindFirstChild("DriverSeat")
	if not seat or not seat:IsA("VehicleSeat") or boundSeats[seat] then
		return
	end
	boundSeats[seat] = true
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		if not occupant then
			vehicle:SetAttribute("ServerThrottle", 0)
			vehicle:SetAttribute("ServerSteer", 0)
			vehicle:SetAttribute("ServerHandbrake", false)
			if vehicle:GetAttribute("ControlledByUserId") == nil then
				setNetworkOwner(vehicle, nil)
			end
			return
		end
		local character = occupant.Parent
		local player = if character then Players:GetPlayerFromCharacter(character) else nil
		if
			player
			and vehicle:GetAttribute("ControlledByUserId") == player.UserId
			and ConvoyService.GetControlledVehicle(player) == vehicle
		then
			setNetworkOwner(vehicle, player)
		end
	end)
end

local function prepareCharacter(character: Model)
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
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = false
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	end
end

local function bindPlayerToControlledVehicle(player: Player, character: Model)
	local vehicle = ConvoyService.GetControlledVehicle(player)
	if not vehicle or not vehicle.Parent or not ConvoyService.IsOperational(vehicle) then
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

	prepareCharacter(character)
	local existingWeld = root:FindFirstChild("VehicleCharacterWeld")
	if existingWeld then
		existingWeld:Destroy()
	end
	humanoid.Sit = false
	character:PivotTo(seat.CFrame * CFrame.new(0, 2, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Name = "VehicleCharacterWeld"
	weld.Part0 = seat
	weld.Part1 = root
	weld.Parent = root
	seat:Sit(humanoid)
	humanoid.Sit = true
	setNetworkOwner(vehicle, player)
	print(string.format("[Hoonanga] %s controls %s", player.Name, vehicle.Name))
end

local function resetValidation(player: Player, vehicle: Model?)
	if vehicle and vehicle.PrimaryPart then
		validationStates[player] = {
			Position = vehicle.PrimaryPart.Position,
			CheckedAt = Workspace:GetServerTimeNow(),
		}
	else
		validationStates[player] = nil
	end
end

local function createPlayerConvoy(
	player: Player,
	requestedClass: string?
): ConvoyService.ConvoyRecord
	player:SetAttribute("Kills", 0)
	player:SetAttribute("RunEnded", false)
	player:SetAttribute("RunEndReason", nil)
	player:SetAttribute("RunDistance", 0)
	player:SetAttribute("ControlTransfers", 0)
	local classId = if requestedClass and ConvoyConfig[requestedClass]
		then requestedClass
		else "Ute"
	player:SetAttribute("SelectedConvoyClass", classId)
	local spawnOffset = (#Players:GetPlayers() - 1) * 18
	local spawn = WorldConfig.Spawn.Player * CFrame.new(spawnOffset, 0, 0)
	local convoy = ConvoyService.Create(player.UserId, "Player", classId, spawn)
	player:SetAttribute("ConvoyId", convoy.Id)
	for _, vehicle in convoy.Members do
		bindSeat(vehicle)
	end
	resetValidation(player, convoy.ControlledVehicle)
	return convoy
end

local function validatePlayerVehicle(player: Player, vehicle: Model, now: number)
	local chassis = vehicle.PrimaryPart
	if not chassis or not ConvoyService.IsOperational(vehicle) then
		return
	end
	local state = validationStates[player]
	if not state then
		resetValidation(player, vehicle)
		return
	end
	local deltaTime = now - state.CheckedAt
	if deltaTime < VALIDATION_INTERVAL then
		return
	end
	local delta = chassis.Position - state.Position
	local horizontalDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local vehicleType = vehicle:GetAttribute("VehicleType") or "Ute"
	local config = VehicleConfig[vehicleType]
	local maxSpeed = if config then config.MaxForwardSpeed else 112
	local maximumDistance = maxSpeed * VALIDATION_SPEED_MULTIPLIER * deltaTime
		+ VALIDATION_DISTANCE_TOLERANCE
	local invalid = horizontalDistance > maximumDistance
		or math.abs(delta.Y) > VALIDATION_VERTICAL_TOLERANCE
	local lastImpactAt = vehicle:GetAttribute("LastImpactAt")
	local withinImpactGrace = typeof(lastImpactAt) == "number"
		and now - lastImpactAt < IMPACT_GRACE_WINDOW
	if invalid and not withinImpactGrace then
		warn(
			string.format(
				"[Hoonanga] Corrected impossible movement from %s (%.1f studs in %.2fs)",
				player.Name,
				delta.Magnitude,
				deltaTime
			)
		)
		vehicle:PivotTo(CFrame.new(state.Position) * chassis.CFrame.Rotation)
		chassis.AssemblyLinearVelocity = Vector3.zero
		chassis.AssemblyAngularVelocity = Vector3.zero
	else
		state.Position = chassis.Position
	end
	state.CheckedAt = now
end

local function addPlayer(player: Player)
	createPlayerConvoy(player, player:GetAttribute("SelectedConvoyClass") :: string?)
	player.CharacterAdded:Connect(function(character)
		local convoy = ConvoyService.GetForPlayer(player)
		if not convoy or convoy.Ended then
			if convoy then
				ConvoyService.Remove(convoy, true)
			end
			createPlayerConvoy(player, player:GetAttribute("SelectedConvoyClass") :: string?)
		end
		task.defer(bindPlayerToControlledVehicle, player, character)
	end)
	if player.Character then
		task.defer(bindPlayerToControlledVehicle, player, player.Character)
	end
end

local VehicleService = {}

function VehicleService.Start()
	ConvoyService.ControlChangedSignal():Connect(function(record, previous, replacement)
		if previous then
			VehiclePhysics.Reset(previous)
			setNetworkOwner(previous, nil)
		end
		if record.OwnerUserId <= 0 then
			return
		end
		local player = Players:GetPlayerByUserId(record.OwnerUserId)
		if not player then
			return
		end
		if replacement then
			local transferCount = player:GetAttribute("ControlTransfers")
			player:SetAttribute(
				"ControlTransfers",
				(if typeof(transferCount) == "number" then transferCount else 0)
					+ (if previous then 1 else 0)
			)
			local serial = player:GetAttribute("ControlTransferSerial")
			player:SetAttribute(
				"ControlTransferSerial",
				(if typeof(serial) == "number" then serial else 0) + 1
			)
			player:SetAttribute("ControlledVehicleName", replacement.Name)
			resetValidation(player, replacement)
			if player.Character then
				task.defer(bindPlayerToControlledVehicle, player, player.Character)
			end
		else
			player:SetAttribute("ControlledVehicleName", "")
			resetValidation(player, nil)
		end
	end)

	ConvoyService.ConvoyEndedSignal():Connect(function(record, reason)
		if record.OwnerUserId <= 0 then
			return
		end
		local player = Players:GetPlayerByUserId(record.OwnerUserId)
		if not player then
			return
		end
		player:SetAttribute("RunEnded", true)
		player:SetAttribute("RunEndReason", reason)
		player:SetAttribute("RunDistance", record.RunDistance)
		task.delay(2, function()
			local humanoid = if player.Character
				then player.Character:FindFirstChildOfClass("Humanoid")
				else nil
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = 0
			end
		end)
	end)

	RemoteService.Get("VehicleInput").OnServerEvent
		:Connect(function(player, throttle, steer, handbrake)
			if
				typeof(throttle) ~= "number"
				or typeof(steer) ~= "number"
				or typeof(handbrake) ~= "boolean"
			then
				return
			end
			local vehicle = ConvoyService.GetControlledVehicle(player)
			if
				not vehicle
				or not ConvoyService.IsOperational(vehicle)
				or vehicle:GetAttribute("ControlledByUserId") ~= player.UserId
			then
				return
			end
			vehicle:SetAttribute("ServerThrottle", math.clamp(throttle, -1, 1))
			vehicle:SetAttribute("ServerSteer", math.clamp(steer, -1, 1))
			vehicle:SetAttribute("ServerHandbrake", handbrake)
		end)

	RemoteService.Get("SelectConvoyClass").OnServerEvent:Connect(function(player, classId)
		if typeof(classId) ~= "string" or not ConvoyConfig[classId] then
			return
		end
		local old = ConvoyService.GetForPlayer(player)
		if old then
			ConvoyService.Remove(old, true)
		end
		local convoy = createPlayerConvoy(player, classId)
		if player.Character then
			task.defer(bindPlayerToControlledVehicle, player, player.Character)
		end
		print(string.format("[Hoonanga] %s selected %s convoy", player.Name, convoy.ClassId))
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(addPlayer, player)
	end
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local convoy = ConvoyService.GetForPlayer(player)
		validationStates[player] = nil
		if convoy then
			ConvoyService.Remove(convoy, true)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		for _, player in Players:GetPlayers() do
			local vehicle = ConvoyService.GetControlledVehicle(player)
			if vehicle and vehicle.Parent then
				validatePlayerVehicle(player, vehicle, now)
			end
		end
	end)

	RunService.PreSimulation:Connect(function(deltaTime)
		for _, player in Players:GetPlayers() do
			local vehicle = ConvoyService.GetControlledVehicle(player)
			if not vehicle or not vehicle.Parent or not ConvoyService.IsOperational(vehicle) then
				continue
			end
			local chassis = vehicle.PrimaryPart
			if not chassis or isClientOwned(chassis, player) then
				continue
			end
			local throttle = vehicle:GetAttribute("ServerThrottle")
			local steer = vehicle:GetAttribute("ServerSteer")
			local handbrake = vehicle:GetAttribute("ServerHandbrake")
			VehiclePhysics.Step(vehicle, {
				Throttle = if typeof(throttle) == "number" then throttle else 0,
				Steer = if typeof(steer) == "number" then steer else 0,
				Handbrake = handbrake == true,
			}, deltaTime)
		end
	end)
end

function VehicleService.GetPlayerVehicle(player: Player): Model?
	return ConvoyService.GetControlledVehicle(player)
end

function VehicleService.IsPlayerDriving(player: Player, vehicle: Model): boolean
	return ConvoyService.GetControlledVehicle(player) == vehicle
		and vehicle:GetAttribute("ControlledByUserId") == player.UserId
		and ConvoyService.IsOperational(vehicle)
end

return VehicleService
