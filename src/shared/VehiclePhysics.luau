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
	BogLevel: number,
}

type PhysicsState = {
	BogLevel: number,
}

type CornerState = {
	Grounded: boolean,
	Position: Vector3,
}

-- Suspension and lateral grip are independent per-corner VectorForces, and
-- most of the cornering/self-righting comes from the *difference* in grip
-- direction between the (steerable) front corners and the (fixed) rear
-- corners - the same technique every raycast-suspension vehicle uses. A
-- yaw-only SteeringTorque tops that up for low-speed responsiveness, since
-- pure tire-slip grip is naturally weak when the vehicle is barely moving.
-- There is deliberately no AlignOrientation self-level constraint here: an
-- earlier version of this module had one running alongside the four
-- independent suspension corners AND a yaw torque, and the AlignOrientation
-- fought both of them for authority over roll/pitch every physics step,
-- which is what produced the reported cab jitter. SteeringTorque only
-- drives yaw, a rotational axis the suspension corners don't directly
-- control, so it doesn't have that problem.
local WHEEL_CORNERS = {
	{ Name = "FL", Offset = Vector3.new(-3.05, -1.05, -4.65), Front = true },
	{ Name = "FR", Offset = Vector3.new(3.05, -1.05, -4.65), Front = true },
	{ Name = "RL", Offset = Vector3.new(-3.05, -1.05, 4.65), Front = false },
	{ Name = "RR", Offset = Vector3.new(3.05, -1.05, 4.65), Front = false },
}

local DOWNFORCE_SCALE = 0.018
local AIR_DRAG = 0.045
local HANDBRAKE_REAR_GRIP = 0.28
local STEERING_TORQUE_PER_MASS = 150
local MAX_STEERING_TORQUE = 600_000

local states: { [Model]: PhysicsState } = setmetatable({}, { __mode = "k" }) :: any

local function getVehicleType(vehicle: Model): string
	return vehicle:GetAttribute("VehicleType") or "Ute"
end

local function getState(vehicle: Model): PhysicsState
	local state = states[vehicle]
	if state then
		return state
	end

	state = {
		BogLevel = 0,
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

local function flatDirection(direction: Vector3, fallback: Vector3): Vector3
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.001 then
		return fallback
	end
	return flat.Unit
end

local function zeroActuators(chassis: BasePart)
	local driveForce = chassis:FindFirstChild("DriveForce")
	if driveForce and driveForce:IsA("VectorForce") then
		driveForce.Force = Vector3.zero
	end

	local steeringTorque = chassis:FindFirstChild("SteeringTorque")
	if steeringTorque and steeringTorque:IsA("Torque") then
		steeringTorque.Torque = Vector3.zero
	end

	for _, corner in WHEEL_CORNERS do
		local suspension = chassis:FindFirstChild("Suspension" .. corner.Name)
		if suspension and suspension:IsA("VectorForce") then
			suspension.Force = Vector3.zero
		end

		local lateralGrip = chassis:FindFirstChild("LateralGrip" .. corner.Name)
		if lateralGrip and lateralGrip:IsA("VectorForce") then
			lateralGrip.Force = Vector3.zero
		end
	end
end

local VehiclePhysics = {}

function VehiclePhysics.Reset(vehicle: Model)
	local chassis = vehicle.PrimaryPart
	local state = getState(vehicle)
	state.BogLevel = 0
	vehicle:SetAttribute("ForwardSpeed", 0)
	vehicle:SetAttribute("BogLevel", 0)
	vehicle:SetAttribute("Bogged", false)
	if chassis then
		zeroActuators(chassis)
	end
end

function VehiclePhysics.Step(vehicle: Model, input: VehicleInput, deltaTime: number): Telemetry?
	local chassis = vehicle.PrimaryPart
	if not chassis or chassis.Anchored or deltaTime <= 0 then
		return nil
	end

	local config = VehicleConfig[getVehicleType(vehicle)]
	if not config then
		return nil
	end

	local driveForce = chassis:FindFirstChild("DriveForce")
	if not driveForce or not driveForce:IsA("VectorForce") then
		return nil
	end

	local state = getState(vehicle)
	local frame = chassis.CFrame
	local up = frame.UpVector
	local flatForward = flatDirection(frame.LookVector, Vector3.new(0, 0, -1))
	local flatRight = flatDirection(frame.RightVector, Vector3.new(1, 0, 0))
	local velocity = chassis.AssemblyLinearVelocity
	local forwardSpeed = velocity:Dot(flatForward)
	local speed = velocity.Magnitude
	local mass = chassis.AssemblyMass

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { vehicle }
	raycastParams.IgnoreWater = false

	local groundedWheels = 0
	local cornerStates: { [string]: CornerState } = {}
	local surfaceName = "Air"
	local grip = 1
	local fuelMultiplier = 1
	local bogRate = 0

	for _, corner in WHEEL_CORNERS do
		local attachment = chassis:FindFirstChild("SuspensionPoint" .. corner.Name)
		local suspension = chassis:FindFirstChild("Suspension" .. corner.Name)
		if
			attachment
			and attachment:IsA("Attachment")
			and suspension
			and suspension:IsA("VectorForce")
		then
			local desiredDistance = math.max(0.25, config.Suspension.RideHeight + corner.Offset.Y)
			local rayLength = desiredDistance + config.Suspension.RayLength
			local origin = attachment.WorldPosition
			local result = Workspace:Raycast(origin, -up * rayLength, raycastParams)
			if result then
				groundedWheels += 1
				local wheelSurfaceName, wheelProfile = resolveSurface(result.Instance)
				if wheelProfile.Grip < grip or groundedWheels == 1 then
					surfaceName = wheelSurfaceName
					grip = wheelProfile.Grip
				end
				fuelMultiplier = math.max(fuelMultiplier, wheelProfile.FuelUse)
				bogRate = math.max(bogRate, wheelProfile.BogRate)

				local compression = desiredDistance - result.Distance
				local pointVelocity = chassis:GetVelocityAtPosition(origin)
				local suspensionVelocity = pointVelocity:Dot(up)
				local springAcceleration = compression * config.Suspension.SpringStrength
					- suspensionVelocity * config.Suspension.SpringDamping
				suspension.Force = up * math.max(0, springAcceleration * mass)

				cornerStates[corner.Name] = { Grounded = true, Position = origin }
			else
				suspension.Force = Vector3.zero
				cornerStates[corner.Name] = { Grounded = false, Position = origin }
			end
		end
	end

	local grounded = groundedWheels > 0
	if not grounded then
		grip = 0
	end

	local throttle = if vehicle:GetAttribute("OutOfFuel") == true
		then 0
		else math.clamp(input.Throttle, -1, 1)
	local steer = math.clamp(input.Steer, -1, 1)

	if bogRate > 0 and grounded then
		local lowMovement = math.clamp(1 - math.abs(forwardSpeed) / 18, 0, 1)
		local effort = 0.2 + math.abs(throttle) * 1.8
		state.BogLevel += bogRate * effort * (0.35 + lowMovement) * deltaTime
	else
		local recovery = if grounded and grip >= 0.8 then 0.3 else 0.12
		state.BogLevel -= recovery * deltaTime
	end
	state.BogLevel = math.clamp(state.BogLevel, 0, 1)

	local bogDriveScale = 1 - state.BogLevel * 0.82
	local surfaceDriveScale = math.clamp(grip, 0.2, 1.05) / math.max(fuelMultiplier, 0.8)
	local maxForwardSpeed = config.MaxForwardSpeed
		* bogDriveScale
		/ math.max(1, (fuelMultiplier - 1) * 1.4 + 1)
	local maxReverseSpeed = config.MaxReverseSpeed * math.max(0.35, bogDriveScale)

	local longitudinalAcceleration = 0
	if grounded then
		if throttle > 0 then
			if forwardSpeed < maxForwardSpeed then
				longitudinalAcceleration = config.Acceleration
					* surfaceDriveScale
					* bogDriveScale
					* throttle
			end
		elseif throttle < 0 then
			if forwardSpeed > 1 then
				longitudinalAcceleration = -config.BrakeDeceleration * math.abs(throttle)
			elseif forwardSpeed > -maxReverseSpeed then
				longitudinalAcceleration = -config.ReverseAcceleration
					* surfaceDriveScale
					* bogDriveScale
					* math.abs(throttle)
			end
		elseif math.abs(forwardSpeed) > 0.05 then
			local coast = config.CoastDeceleration
				* fuelMultiplier
				* (if input.Handbrake then 3.5 else 1)
			longitudinalAcceleration = -math.sign(forwardSpeed)
				* math.min(coast, math.abs(forwardSpeed) / deltaTime)
		end

		if forwardSpeed > maxForwardSpeed then
			longitudinalAcceleration -= math.min(
				config.BrakeDeceleration,
				(forwardSpeed - maxForwardSpeed) * 5
			)
		elseif forwardSpeed < -maxReverseSpeed then
			longitudinalAcceleration += math.min(
				config.BrakeDeceleration,
				(-maxReverseSpeed - forwardSpeed) * 5
			)
		end
	end

	local downforceAcceleration = if grounded
		then math.min(55, config.Downforce * speed * speed * DOWNFORCE_SCALE)
		else 0
	local airDragAcceleration = if grounded
		then Vector3.zero
		else -velocity * math.min(1, AIR_DRAG * speed)
	driveForce.Force = (
		flatForward * longitudinalAcceleration
		- up * downforceAcceleration
		+ airDragAcceleration
	) * mass

	local speedRatio = math.clamp(math.abs(forwardSpeed) / config.MaxForwardSpeed, 0, 1)
	local steeringScale = 1 - speedRatio * (1 - config.HighSpeedSteeringFactor)
	local steerAngle = steer * config.MaxSteerAngle * steeringScale
	local cosAngle = math.cos(steerAngle)
	local sinAngle = math.sin(steerAngle)
	local gripCoefficient = config.LateralGrip * math.clamp(grip, 0.05, 1)

	local steeringTorque = chassis:FindFirstChild("SteeringTorque")
	if steeringTorque and steeringTorque:IsA("Torque") then
		local targetYawRate = 0
		if grounded and math.abs(forwardSpeed) > 1 then
			local movementScale = math.clamp(math.abs(forwardSpeed) / 8, 0, 1)
			local directionScale = if forwardSpeed < 0 then -1 else 1
			targetYawRate = -steer
				* config.SteeringRate
				* steeringScale
				* movementScale
				* math.clamp(grip, 0.12, 1)
				* (if input.Handbrake then 1.2 else 1)
				* directionScale
		end
		local currentYawRate = chassis.AssemblyAngularVelocity:Dot(up)
		local yawTorque = math.clamp(
			(targetYawRate - currentYawRate) * mass * STEERING_TORQUE_PER_MASS,
			-MAX_STEERING_TORQUE,
			MAX_STEERING_TORQUE
		)
		steeringTorque.Torque = up * yawTorque
	end

	for _, corner in WHEEL_CORNERS do
		local lateralGrip = chassis:FindFirstChild("LateralGrip" .. corner.Name)
		if lateralGrip and lateralGrip:IsA("VectorForce") then
			local cornerState = cornerStates[corner.Name]
			if cornerState and cornerState.Grounded then
				local wheelRight = if corner.Front
					then flatRight * cosAngle - flatForward * sinAngle
					else flatRight

				local contactVelocity = chassis:GetVelocityAtPosition(cornerState.Position)
				local lateralSlip = contactVelocity:Dot(wheelRight)
				local cornerGrip = if input.Handbrake and not corner.Front
					then gripCoefficient * HANDBRAKE_REAR_GRIP
					else gripCoefficient

				lateralGrip.Force = wheelRight * (-lateralSlip * cornerGrip * (mass / 4))
			else
				lateralGrip.Force = Vector3.zero
			end
		end
	end

	vehicle:SetAttribute("SurfaceProfile", surfaceName)
	vehicle:SetAttribute("SurfaceFuelMultiplier", fuelMultiplier)
	vehicle:SetAttribute("ForwardSpeed", forwardSpeed)
	vehicle:SetAttribute("GroundedWheels", groundedWheels)
	vehicle:SetAttribute("BogLevel", state.BogLevel)
	vehicle:SetAttribute("Bogged", state.BogLevel >= 0.85)

	return {
		ForwardSpeed = forwardSpeed,
		Speed = speed,
		GroundedWheels = groundedWheels,
		SurfaceProfile = surfaceName,
		FuelMultiplier = fuelMultiplier,
		Grip = grip,
		BogLevel = state.BogLevel,
	}
end

return VehiclePhysics
