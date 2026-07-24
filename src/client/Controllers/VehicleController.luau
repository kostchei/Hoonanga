--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VehiclePhysics = require(ReplicatedStorage.Shared.VehiclePhysics)

local localPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("HoonangaRemotes")
local vehicleInputRemote = remotes:WaitForChild("VehicleInput") :: RemoteEvent

local ACTION_FORWARD = "HoonangaDriveForward"
local ACTION_REVERSE = "HoonangaDriveReverse"
local ACTION_LEFT = "HoonangaSteerLeft"
local ACTION_RIGHT = "HoonangaSteerRight"
local ACTION_HANDBRAKE = "HoonangaHandbrake"
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 100
local INPUT_SEND_INTERVAL = 0.1

local activeVehicle: Model? = nil
local activeSeat: VehicleSeat? = nil
local actionsBound = false
local forwardPressed = false
local reversePressed = false
local leftPressed = false
local rightPressed = false
local handbrakePressed = false
local lastInputSentAt = 0

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

local function inputValue(pressed: boolean): number
	return if pressed then 1 else 0
end

local function currentInput(): (number, number, boolean)
	local throttle = inputValue(forwardPressed) - inputValue(reversePressed)
	local steer = inputValue(rightPressed) - inputValue(leftPressed)
	return throttle, steer, handbrakePressed
end

local function resetInput()
	forwardPressed = false
	reversePressed = false
	leftPressed = false
	rightPressed = false
	handbrakePressed = false
end

local function handleDigitalAction(
	actionName: string,
	inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult
	if not activeVehicle then
		return Enum.ContextActionResult.Pass
	end

	local pressed = inputState == Enum.UserInputState.Begin
		or inputState == Enum.UserInputState.Change
	if actionName == ACTION_FORWARD then
		forwardPressed = pressed
	elseif actionName == ACTION_REVERSE then
		reversePressed = pressed
	elseif actionName == ACTION_LEFT then
		leftPressed = pressed
	elseif actionName == ACTION_RIGHT then
		rightPressed = pressed
	elseif actionName == ACTION_HANDBRAKE then
		handbrakePressed = pressed
	end

	return Enum.ContextActionResult.Sink
end

local function bindVehicleActions()
	if actionsBound then
		return
	end
	actionsBound = true

	ContextActionService:BindActionAtPriority(
		ACTION_FORWARD,
		handleDigitalAction,
		false,
		ACTION_PRIORITY,
		Enum.KeyCode.W,
		Enum.KeyCode.Up
	)
	ContextActionService:BindActionAtPriority(
		ACTION_REVERSE,
		handleDigitalAction,
		false,
		ACTION_PRIORITY,
		Enum.KeyCode.S,
		Enum.KeyCode.Down
	)
	ContextActionService:BindActionAtPriority(
		ACTION_LEFT,
		handleDigitalAction,
		false,
		ACTION_PRIORITY,
		Enum.KeyCode.A,
		Enum.KeyCode.Left
	)
	ContextActionService:BindActionAtPriority(
		ACTION_RIGHT,
		handleDigitalAction,
		false,
		ACTION_PRIORITY,
		Enum.KeyCode.D,
		Enum.KeyCode.Right
	)
	ContextActionService:BindActionAtPriority(
		ACTION_HANDBRAKE,
		handleDigitalAction,
		false,
		ACTION_PRIORITY,
		Enum.KeyCode.Space
	)
end

local function unbindVehicleActions()
	if not actionsBound then
		return
	end
	actionsBound = false

	ContextActionService:UnbindAction(ACTION_FORWARD)
	ContextActionService:UnbindAction(ACTION_REVERSE)
	ContextActionService:UnbindAction(ACTION_LEFT)
	ContextActionService:UnbindAction(ACTION_RIGHT)
	ContextActionService:UnbindAction(ACTION_HANDBRAKE)
	resetInput()
	vehicleInputRemote:FireServer(0, 0, false)
end

local function refreshVehicle()
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	activeVehicle = findVehicleFromSeat(seat)
	activeSeat = if seat and seat:IsA("VehicleSeat") then seat else nil

	if activeVehicle then
		if humanoid then
			humanoid.AutoRotate = false
		end
		bindVehicleActions()
	else
		if humanoid then
			humanoid.AutoRotate = true
		end
		unbindVehicleActions()
	end
end

local VehicleController = {}

function VehicleController.Start()
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

		local throttle, steer, handbrake = currentInput()
		VehiclePhysics.Step(vehicle, {
			Throttle = throttle,
			Steer = steer,
			Handbrake = handbrake,
		}, deltaTime)

		local now = os.clock()
		if now - lastInputSentAt >= INPUT_SEND_INTERVAL then
			lastInputSentAt = now
			vehicleInputRemote:FireServer(throttle, steer, handbrake)
		end
	end)
end

return VehicleController
