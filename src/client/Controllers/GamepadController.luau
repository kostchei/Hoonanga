--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ControllerConfig = require(ReplicatedStorage.Shared.Config.ControllerConfig)
local ControllerInput = require(ReplicatedStorage.Shared.ControllerInput)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponState = require(ReplicatedStorage.Shared.WeaponState)
local AccessibilityController = require(script.Parent.AccessibilityController)
local CameraController = require(script.Parent.CameraController)
local InputModeController = require(script.Parent.InputModeController)
local VehicleLocator = require(script.Parent.VehicleLocator)

local localPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("HoonangaRemotes")
local vehicleInputRemote = remotes:WaitForChild("VehicleInput") :: RemoteEvent
local fireRemote = remotes:WaitForChild("FireWeapon") :: RemoteEvent
local reloadRemote = remotes:WaitForChild("ReloadWeapon") :: RemoteEvent
local selectRemote = remotes:WaitForChild("SelectWeapon") :: RemoteEvent

local isGamepadConnected = false
local leftStick = Vector2.zero
local rightStick = Vector2.zero
local triggerThrottle = 0
local triggerBrake = 0
local handbrakePressed = false
local firing = false
local lastDriveSend = 0
local lastFireSend = 0

local function currentVehicle(): Model?
	return VehicleLocator.ForPlayer(localPlayer)
end

local function updateGamepadState()
	isGamepadConnected = #UserInputService:GetConnectedGamepads() > 0
end

local function assistedAimDirection(direction: Vector3): Vector3
	if direction.Magnitude < 0.9 then
		return direction
	end
	local vehicle = currentVehicle()
	local ownConvoyId = if vehicle then vehicle:GetAttribute("ConvoyId") else nil
	local origin = Workspace.CurrentCamera.CFrame.Position
	local unit = direction.Unit
	local bestDirection: Vector3? = nil
	local bestDot = math.cos(math.rad(ControllerConfig.AimAssistConeDegrees))

	for _, candidate in CollectionService:GetTagged("HoonangaVehicle") do
		if
			candidate:IsA("Model")
			and candidate ~= vehicle
			and candidate.PrimaryPart
			and not candidate:GetAttribute("Destroyed")
			and candidate:GetAttribute("ConvoyId") ~= ownConvoyId
		then
			local offset = candidate.PrimaryPart.Position - origin
			local distance = offset.Magnitude
			if distance > 0 and distance <= ControllerConfig.AimAssistMaxDistance then
				local targetDirection = offset.Unit
				local alignment = unit:Dot(targetDirection)
				if alignment > bestDot then
					bestDot = alignment
					bestDirection = targetDirection
				end
			end
		end
	end

	return if bestDirection
		then unit:Lerp(bestDirection, ControllerConfig.AimAssistStrength).Unit
		else unit
end

local function fireOnce()
	if not InputModeController.IsGameplayEnabled() then
		return
	end
	local vehicle = currentVehicle()
	if not vehicle then
		return
	end
	local config = WeaponState.GetActiveWeapon(vehicle)
	local now = os.clock()
	if now - lastFireSend < config.FireInterval then
		return
	end
	lastFireSend = now
	local direction = assistedAimDirection(Workspace.CurrentCamera.CFrame.LookVector)
	fireRemote:FireServer(direction)
end

local function selectRelativeWeapon(direction: number)
	local vehicle = currentVehicle()
	if not vehicle then
		return
	end
	local activeId = vehicle:GetAttribute("ActiveWeapon")
	local currentSlot = if typeof(activeId) == "string"
		then table.find(WeaponConfig.Loadout, activeId) or 1
		else 1
	local slot = ControllerInput.WrapSlot(currentSlot, direction, #WeaponConfig.Loadout)
	local weaponId = WeaponConfig.Loadout[slot]
	if weaponId then
		selectRemote:FireServer(weaponId)
	end
end

local GamepadController = {}

function GamepadController.Start()
	UserInputService.GamepadConnected:Connect(updateGamepadState)
	UserInputService.GamepadDisconnected:Connect(updateGamepadState)
	updateGamepadState()

	UserInputService.InputChanged:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			leftStick = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			rightStick = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			triggerThrottle = input.Position.Z
		elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
			triggerBrake = input.Position.Z
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonX then
			handbrakePressed = true
		elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
			firing = true
			fireOnce()
		elseif input.KeyCode == Enum.KeyCode.ButtonY then
			if InputModeController.IsGameplayEnabled() then
				reloadRemote:FireServer()
			end
		elseif input.KeyCode == Enum.KeyCode.DPadLeft then
			selectRelativeWeapon(-1)
		elseif input.KeyCode == Enum.KeyCode.DPadRight then
			selectRelativeWeapon(1)
		elseif input.KeyCode == Enum.KeyCode.ButtonStart then
			AccessibilityController.Toggle()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonX then
			handbrakePressed = false
		elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
			firing = false
		end
	end)

	RunService.Heartbeat:Connect(function()
		if not isGamepadConnected or not InputModeController.IsGameplayEnabled() then
			return
		end
		local now = os.clock()
		if now - lastDriveSend < 1 / 30 then
			return
		end
		lastDriveSend = now
		local throttle, steer = ControllerInput.ComposeDriveInput(
			leftStick.X,
			triggerThrottle,
			triggerBrake,
			ControllerConfig.StickDeadzone,
			ControllerConfig.TriggerDeadzone
		)
		vehicleInputRemote:FireServer(throttle, steer, handbrakePressed)
	end)

	RunService.RenderStepped:Connect(function(deltaTime)
		if not isGamepadConnected or not InputModeController.IsGameplayEnabled() then
			return
		end
		local lookX = ControllerInput.ApplyDeadzone(rightStick.X, ControllerConfig.StickDeadzone)
		local lookY = ControllerInput.ApplyDeadzone(rightStick.Y, ControllerConfig.StickDeadzone)
		CameraController.AddGamepadLook(
			lookX * ControllerConfig.CameraYawRadiansPerSecond * deltaTime,
			lookY * ControllerConfig.CameraPitchRadiansPerSecond * deltaTime
		)

		if firing then
			local vehicle = currentVehicle()
			if vehicle and WeaponState.GetActiveWeapon(vehicle).Automatic then
				fireOnce()
			end
		end
	end)
end

function GamepadController.IsGamepadConnected(): boolean
	return isGamepadConnected
end

function GamepadController.CalculateAimAssistModifier(aimDirection: Vector3): Vector3
	return assistedAimDirection(aimDirection)
end

return GamepadController
