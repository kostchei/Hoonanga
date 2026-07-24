--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VehicleLocator = require(script.Parent.VehicleLocator)

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
local actionsBound = false
local forwardPressed = false
local reversePressed = false
local leftPressed = false
local rightPressed = false
local handbrakePressed = false
local lastInputSentAt = 0

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
	local previousVehicle = activeVehicle
	activeVehicle = VehicleLocator.ForPlayer(localPlayer)
	if activeVehicle ~= previousVehicle then
		if activeVehicle then
			print(string.format("[Hoonanga] Client acquired %s", activeVehicle.Name))
		elseif previousVehicle then
			warn(string.format("[Hoonanga] Client lost %s", previousVehicle.Name))
		end
	end
	if activeVehicle then
		bindVehicleActions()
	else
		unbindVehicleActions()
	end
end

local VehicleController = {}

function VehicleController.Start()
	refreshVehicle()

	RunService.Heartbeat:Connect(function()
		local resolvedVehicle = VehicleLocator.ForPlayer(localPlayer)
		if resolvedVehicle ~= activeVehicle then
			refreshVehicle()
		end

		local vehicle = activeVehicle
		if not vehicle or not vehicle.Parent then
			return
		end

		local throttle, steer, handbrake = currentInput()
		local now = os.clock()
		if now - lastInputSentAt >= INPUT_SEND_INTERVAL then
			lastInputSentAt = now
			vehicleInputRemote:FireServer(throttle, steer, handbrake)
		end
	end)
end

return VehicleController
