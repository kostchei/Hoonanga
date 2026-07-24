--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage.Shared.Config
local SurfaceProfiles = require(Config.SurfaceProfiles)
local VehicleConfig = require(Config.VehicleConfig)

export type VehicleInput = {
	Throttle: number,
	Steer: number,
	Handbrake: boolean,
}

export type Telemetry = {
	ForwardSpeed: number,
	Speed: number,
	GroundedWheels: number,
	SurfaceProfile: string,
	FuelMultiplier: number,
	Grip: number,
}

type PhysicsState = {
	Speed: number,
	VerticalSpeed: number,
}

local GROUND_CLEARANCE = 2.8
local GROUND_PROBE_HEIGHT = 8
local GROUND_PROBE_DEPTH = 20
local FALL_ACCELERATION = 70

local states: { [Model]: PhysicsState } = setmetatable({}, { __mode = "k" }) :: any

local function approach(current: number, target: number, amount: number): number
	if current < target then
		return math.min(current + amount, target)
	end
	return math.max(current - amount, target)
end

local function getVehicleType(vehicle: Model): string
	return vehicle:GetAttribute("VehicleType") or "Ute"
end

local function getState(vehicle: Model): PhysicsState
	local state = states[vehicle]
	if state then
		return state
	end

	state = {
		Speed = 0,
		VerticalSpeed = 0,
	}
	states[vehicle] = state
	return state
end

local function resolveSurface(part: Instance?): (string, any)
	local profileName = "WornDirt"
	if part then
		local attribute = part:GetAttribute("SurfaceProfile")
		if typeof(attribute) == "string" and SurfaceProfiles[attribute] then
			profileName = attribute
		end
	end
	return profileName, SurfaceProfiles[profileName]
end

local function probeGround(vehicle: Model, position: Vector3): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { vehicle }
	params.IgnoreWater = false

	local origin = position + Vector3.new(0, GROUND_PROBE_HEIGHT, 0)
	return Workspace:Raycast(
		origin,
		Vector3.new(0, -(GROUND_PROBE_HEIGHT + GROUND_PROBE_DEPTH), 0),
		params
	)
end

local VehiclePhysics = {}

function VehiclePhysics.Reset(vehicle: Model)
	local state = getState(vehicle)
	state.Speed = 0
	state.VerticalSpeed = 0
	vehicle:SetAttribute("ForwardSpeed", 0)
end

function VehiclePhysics.Step(vehicle: Model, input: VehicleInput, deltaTime: number): Telemetry?
	local chassis = vehicle.PrimaryPart
	if not chassis then
		return nil
	end

	local config = VehicleConfig[getVehicleType(vehicle)]
	if not config then
		return nil
	end

	local state = getState(vehicle)
	local frame = chassis.CFrame
	local groundResult = probeGround(vehicle, frame.Position)
	local surfaceName = "Air"
	local profile = SurfaceProfiles.WornDirt
	local grounded = groundResult ~= nil
	if groundResult then
		surfaceName, profile = resolveSurface(groundResult.Instance)
	end

	local grip = if grounded then profile.Grip else 0
	local fuelMultiplier = if grounded then profile.FuelUse else 1
	local throttle = if vehicle:GetAttribute("OutOfFuel") == true
		then 0
		else math.clamp(input.Throttle, -1, 1)
	local accelerationScale = math.clamp(grip, 0.28, 1.15) / math.max(fuelMultiplier, 0.8)

	if throttle > 0 then
		state.Speed += config.Acceleration * accelerationScale * throttle * deltaTime
	elseif throttle < 0 then
		if state.Speed > 1 then
			state.Speed =
				approach(state.Speed, 0, config.BrakeDeceleration * math.abs(throttle) * deltaTime)
		else
			state.Speed -= config.ReverseAcceleration * accelerationScale * math.abs(throttle) * deltaTime
		end
	else
		local coast = config.CoastDeceleration * (if input.Handbrake then 3.2 else 1)
		state.Speed = approach(state.Speed, 0, coast * fuelMultiplier * deltaTime)
	end

	local maxForwardSpeed = config.MaxForwardSpeed / math.max(1, (fuelMultiplier - 1) * 1.4 + 1)
	state.Speed = math.clamp(state.Speed, -config.MaxReverseSpeed, maxForwardSpeed)

	local yawDelta = 0
	if grounded and math.abs(state.Speed) > 0.5 then
		local speedRatio = math.clamp(math.abs(state.Speed) / config.MaxForwardSpeed, 0, 1)
		local steeringScale = 1 - speedRatio * (1 - config.HighSpeedSteeringFactor)
		local movementScale = math.clamp(math.abs(state.Speed) / 7, 0, 1)
		local reverseDirection = if state.Speed < 0 then -1 else 1
		local handbrakeScale = if input.Handbrake then 1.3 else 1
		yawDelta = -math.clamp(input.Steer, -1, 1)
			* config.SteeringRate
			* steeringScale
			* movementScale
			* math.clamp(grip, 0.22, 1)
			* handbrakeScale
			* reverseDirection
			* deltaTime
	end

	local yawedFrame = frame * CFrame.Angles(0, yawDelta, 0)
	local position = frame.Position + yawedFrame.LookVector * state.Speed * deltaTime
	if groundResult then
		state.VerticalSpeed = 0
		local targetY = groundResult.Position.Y + GROUND_CLEARANCE
		local heightAlpha = 1 - math.exp(-14 * deltaTime)
		position =
			Vector3.new(position.X, position.Y + (targetY - position.Y) * heightAlpha, position.Z)
	else
		state.VerticalSpeed -= FALL_ACCELERATION * deltaTime
		position += Vector3.new(0, state.VerticalSpeed * deltaTime, 0)
		state.Speed *= math.exp(-0.35 * deltaTime)
	end

	local flatForward = Vector3.new(yawedFrame.LookVector.X, 0, yawedFrame.LookVector.Z)
	if flatForward.Magnitude < 0.01 then
		flatForward = Vector3.new(0, 0, -1)
	end
	vehicle:PivotTo(CFrame.lookAt(position, position + flatForward.Unit, Vector3.yAxis))

	vehicle:SetAttribute("SurfaceProfile", surfaceName)
	vehicle:SetAttribute("SurfaceFuelMultiplier", fuelMultiplier)
	vehicle:SetAttribute("ForwardSpeed", state.Speed)

	return {
		ForwardSpeed = state.Speed,
		Speed = math.abs(state.Speed),
		GroundedWheels = if grounded then 4 else 0,
		SurfaceProfile = surfaceName,
		FuelMultiplier = fuelMultiplier,
		Grip = grip,
	}
end

return VehiclePhysics
