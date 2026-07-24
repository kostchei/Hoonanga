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
	RaycastParams: RaycastParams,
	SuspensionForces: { VectorForce },
	DriveForce: VectorForce,
	SteeringVelocity: AngularVelocity,
}

local states: { [Model]: PhysicsState } = setmetatable({}, { __mode = "k" }) :: any

local function getVehicleType(vehicle: Model): string
	return vehicle:GetAttribute("VehicleType") or "Ute"
end

local function getState(vehicle: Model): PhysicsState?
	local cached = states[vehicle]
	if cached then
		return cached
	end

	local chassis = vehicle.PrimaryPart
	if not chassis then
		return nil
	end

	local suspensionForces = {}
	for _, corner in { "FL", "FR", "RL", "RR" } do
		local force = chassis:FindFirstChild("Suspension" .. corner)
		if not force or not force:IsA("VectorForce") then
			return nil
		end
		table.insert(suspensionForces, force)
	end

	local driveForce = chassis:FindFirstChild("DriveForce")
	local steeringVelocity = chassis:FindFirstChild("SteeringVelocity")
	if not driveForce or not driveForce:IsA("VectorForce") then
		return nil
	end
	if not steeringVelocity or not steeringVelocity:IsA("AngularVelocity") then
		return nil
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { vehicle }
	raycastParams.IgnoreWater = false

	local state: PhysicsState = {
		RaycastParams = raycastParams,
		SuspensionForces = suspensionForces,
		DriveForce = driveForce,
		SteeringVelocity = steeringVelocity,
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

local VehiclePhysics = {}

function VehiclePhysics.Reset(vehicle: Model)
	local state = getState(vehicle)
	if not state then
		return
	end

	for _, force in state.SuspensionForces do
		force.Force = Vector3.zero
	end
	state.DriveForce.Force = Vector3.zero
	state.SteeringVelocity.AngularVelocity = Vector3.zero
end

function VehiclePhysics.Step(vehicle: Model, input: VehicleInput, _deltaTime: number): Telemetry?
	local chassis = vehicle.PrimaryPart
	local state = getState(vehicle)
	if not chassis or not state then
		return nil
	end

	local config = VehicleConfig[getVehicleType(vehicle)]
	if not config then
		return nil
	end

	local up = chassis.CFrame.UpVector
	local forward = chassis.CFrame.LookVector
	local right = chassis.CFrame.RightVector
	local velocity = chassis.AssemblyLinearVelocity
	local mass = chassis.AssemblyMass
	local groundedWheels = 0
	local totalGrip = 0
	local totalFuelMultiplier = 0
	local surfaceVotes: { [string]: number } = {}

	for _, force in state.SuspensionForces do
		local attachment = force.Attachment0
		if not attachment then
			continue
		end

		local origin = attachment.WorldPosition
		local result =
			Workspace:Raycast(origin, -up * config.Suspension.RayLength, state.RaycastParams)
		if not result then
			force.Force = Vector3.zero
			continue
		end

		groundedWheels += 1
		local distance = (result.Position - origin).Magnitude
		local compression = config.Suspension.RideHeight - distance
		local pointVelocity = chassis:GetVelocityAtPosition(origin)
		local verticalSpeed = pointVelocity:Dot(up)
		local baseSupport = mass * Workspace.Gravity / #state.SuspensionForces
		local spring = compression * mass * config.Suspension.SpringStrength
		local damping = verticalSpeed
			* mass
			* config.Suspension.SpringDamping
			/ #state.SuspensionForces
		local forceMagnitude = math.max(0, baseSupport + spring - damping)
		force.Force = up * forceMagnitude

		local profileName, profile = resolveSurface(result.Instance)
		totalGrip += profile.Grip
		totalFuelMultiplier += profile.FuelUse
		surfaceVotes[profileName] = (surfaceVotes[profileName] or 0) + 1
	end

	local grip = if groundedWheels > 0 then totalGrip / groundedWheels else 0
	local fuelMultiplier = if groundedWheels > 0 then totalFuelMultiplier / groundedWheels else 1
	local dominantSurface = "Air"
	local dominantVotes = 0
	for profileName, votes in surfaceVotes do
		if votes > dominantVotes then
			dominantSurface = profileName
			dominantVotes = votes
		end
	end

	local forwardSpeed = velocity:Dot(forward)
	local sideSpeed = velocity:Dot(right)
	local horizontalVelocity = velocity - up * velocity:Dot(up)
	local speed = horizontalVelocity.Magnitude
	local drive = Vector3.zero

	if groundedWheels > 0 then
		local throttle = math.clamp(input.Throttle, -1, 1)
		local effectiveMaxSpeed = config.MaxForwardSpeed
			/ math.max(1, (fuelMultiplier - 1) * 1.4 + 1)

		if throttle > 0 and forwardSpeed < effectiveMaxSpeed then
			drive += forward * throttle * config.Acceleration * mass
		elseif throttle < 0 then
			if forwardSpeed > 3 then
				drive -= forward * math.abs(throttle) * config.BrakeDeceleration * mass
			elseif forwardSpeed > -config.MaxReverseSpeed then
				drive += forward * throttle * config.ReverseAcceleration * mass
			end
		elseif math.abs(forwardSpeed) > 0.5 then
			drive -= forward * math.sign(forwardSpeed) * config.CoastDeceleration * mass * fuelMultiplier
		end

		local handbrakeGrip = if input.Handbrake then 0.22 else 1
		drive -= right * sideSpeed * mass * config.LateralGrip * grip * handbrakeGrip
		drive -= up * math.min(speed * mass * config.Downforce, mass * Workspace.Gravity)

		local speedRatio = math.clamp(math.abs(forwardSpeed) / config.MaxForwardSpeed, 0, 1)
		local steeringScale = 1 - speedRatio * (1 - config.HighSpeedSteeringFactor)
		local movementScale = math.clamp(math.abs(forwardSpeed) / 7, 0, 1)
		local reverseDirection = if forwardSpeed < -1 then -1 else 1
		local yawRate = -math.clamp(input.Steer, -1, 1)
			* config.SteeringRate
			* steeringScale
			* movementScale
			* reverseDirection
		state.SteeringVelocity.AngularVelocity = Vector3.new(0, yawRate, 0)
	else
		state.SteeringVelocity.AngularVelocity = Vector3.zero
	end

	state.DriveForce.Force = drive
	vehicle:SetAttribute("SurfaceProfile", dominantSurface)
	vehicle:SetAttribute("SurfaceFuelMultiplier", fuelMultiplier)
	vehicle:SetAttribute("ForwardSpeed", forwardSpeed)

	return {
		ForwardSpeed = forwardSpeed,
		Speed = speed,
		GroundedWheels = groundedWheels,
		SurfaceProfile = dominantSurface,
		FuelMultiplier = fuelMultiplier,
		Grip = grip,
	}
end

return VehiclePhysics
