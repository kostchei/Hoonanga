--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VehiclePhysics = require(ReplicatedStorage.Shared.VehiclePhysics)

local localPlayer = Players.LocalPlayer
local handbrake = false
local activeVehicle: Model? = nil
local activeSeat: VehicleSeat? = nil

local function findVehicleFromSeat(seat: BasePart?): Model?
	if not seat or not seat:IsA("VehicleSeat") then
		return nil
	end
	local model = seat:FindFirstAncestorOfClass("Model")
	if model and model:GetAttribute("VehicleType") then
		return model
	end
	return nil
end

local function refreshVehicle()
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	activeVehicle = findVehicleFromSeat(seat)
	activeSeat = if seat and seat:IsA("VehicleSeat") then seat else nil
end

local VehicleController = {}

function VehicleController.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space then
			handbrake = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space then
			handbrake = false
		end
	end)

	localPlayer.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid:GetPropertyChangedSignal("SeatPart"):Connect(refreshVehicle)
		refreshVehicle()
	end)

	if localPlayer.Character then
		local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:GetPropertyChangedSignal("SeatPart"):Connect(refreshVehicle)
		end
	end
	refreshVehicle()

	RunService.Heartbeat:Connect(function(deltaTime)
		local vehicle = activeVehicle
		local seat = activeSeat
		if not vehicle or not vehicle.Parent or not seat then
			return
		end

		VehiclePhysics.Step(vehicle, {
			Throttle = seat.ThrottleFloat,
			Steer = seat.SteerFloat,
			Handbrake = handbrake,
		}, deltaTime)
	end)
end

return VehicleController
