--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local remotesFolder = ReplicatedStorage:WaitForChild("HoonangaRemotes")
local vehicleInputRemote = remotesFolder:WaitForChild("VehicleInput") :: RemoteEvent

local AIM_ASSIST_RADIUS_STUDS = 18
local AIM_ASSIST_FRICTION_FACTOR = 0.45

local isGamepadConnected = false
local leftStick = Vector2.zero
local _rightStick = Vector2.zero
local triggerThrottle = 0
local triggerBrake = 0
local isHandbrakePressed = false

local GamepadController = {}

function GamepadController.Start()
	local function updateGamepadState()
		local connected = UserInputService:GetNavigationGamepads()
		isGamepadConnected = #connected > 0
	end

	UserInputService.GamepadConnected:Connect(updateGamepadState)
	UserInputService.GamepadDisconnected:Connect(updateGamepadState)
	updateGamepadState()

	UserInputService.InputChanged:Connect(function(input, gpe)
		if gpe then
			return
		end

		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			leftStick = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			_rightStick = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			triggerThrottle = input.Position.Z
		elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
			triggerBrake = input.Position.Z
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonX then
			isHandbrakePressed = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gpe)
		if input.KeyCode == Enum.KeyCode.ButtonX then
			isHandbrakePressed = false
		end
	end)

	RunService.Heartbeat:Connect(function()
		if not isGamepadConnected then
			return
		end

		local steer = leftStick.X
		local throttle = triggerThrottle - triggerBrake
		vehicleInputRemote:FireServer(throttle, steer, isHandbrakePressed)
	end)
end

function GamepadController.IsGamepadConnected(): boolean
	return isGamepadConnected
end

function GamepadController.CalculateAimAssistModifier(aimDirection: Vector3): Vector3
	if not isGamepadConnected or aimDirection.Magnitude == 0 then
		return aimDirection
	end

	local origin = camera.CFrame.Position

	for _, vehicle in CollectionService:GetTagged("HoonangaVehicle") do
		if vehicle:IsA("Model") and vehicle.PrimaryPart then
			local ownerId = vehicle:GetAttribute("OwnerUserId")
			if
				ownerId
				and ownerId ~= localPlayer.UserId
				and not vehicle:GetAttribute("Destroyed")
			then
				local dist = (vehicle.PrimaryPart.Position - (origin + aimDirection * 100)).Magnitude
				if dist < AIM_ASSIST_RADIUS_STUDS then
					return aimDirection * (1 - AIM_ASSIST_FRICTION_FACTOR)
				end
			end
		end
	end

	return aimDirection
end

return GamepadController
