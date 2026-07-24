--!strict

local CollectionService = game:GetService("CollectionService")

local CHASSIS_SIZE = Vector3.new(6.4, 1.8, 10.4)
local WHEEL_OFFSETS = {
	FL = Vector3.new(-3.35, -1.05, -3.35),
	FR = Vector3.new(3.35, -1.05, -3.35),
	RL = Vector3.new(-3.35, -1.05, 3.35),
	RR = Vector3.new(3.35, -1.05, 3.35),
}

local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function weldToChassis(chassis: BasePart, part: BasePart, relativeCFrame: CFrame)
	part.CFrame = chassis.CFrame * relativeCFrame
	part.Massless = true

	local weld = Instance.new("WeldConstraint")
	weld.Name = "ChassisWeld"
	weld.Part0 = chassis
	weld.Part1 = part
	weld.Parent = part
end

local function addSuspension(chassis: Part, corner: string, offset: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.Name = "SuspensionPoint" .. corner
	attachment.Position = offset
	attachment.Parent = chassis

	local force = Instance.new("VectorForce")
	force.Name = "Suspension" .. corner
	force.Attachment0 = attachment
	force.ApplyAtCenterOfMass = false
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.Force = Vector3.zero
	force.Parent = chassis
end

local VehicleBuilder = {}

function VehicleBuilder.CreateUte(
	parent: Instance,
	name: string,
	spawnCFrame: CFrame,
	bodyColor: Color3
): Model
	local vehicle = Instance.new("Model")
	vehicle.Name = name
	vehicle:SetAttribute("VehicleType", "Ute")
	vehicle:SetAttribute("Hull", 100)
	vehicle:SetAttribute("MaxHull", 100)
	vehicle:SetAttribute("Fuel", 300)
	vehicle:SetAttribute("MaxFuel", 300)
	vehicle:SetAttribute("Destroyed", false)

	local chassis = makePart("Chassis", CHASSIS_SIZE, bodyColor, Enum.Material.Metal)
	chassis.CustomPhysicalProperties = PhysicalProperties.new(2.4, 0.5, 0.05, 1, 1)
	chassis.CFrame = CFrame.new()
	chassis.Parent = vehicle
	vehicle.PrimaryPart = chassis

	local body = makePart("Body", Vector3.new(6.2, 1.5, 7.2), bodyColor, Enum.Material.Metal)
	body.CanCollide = false
	weldToChassis(chassis, body, CFrame.new(0, 1.2, -0.6))
	body.Parent = vehicle

	local cabin = makePart(
		"Cabin",
		Vector3.new(5.4, 2.2, 3.5),
		bodyColor:Lerp(Color3.new(0, 0, 0), 0.15),
		Enum.Material.Metal
	)
	cabin.CanCollide = false
	weldToChassis(chassis, cabin, CFrame.new(0, 2.6, 1.7))
	cabin.Parent = vehicle

	local windshield = makePart(
		"Windshield",
		Vector3.new(4.8, 1.35, 0.18),
		Color3.fromRGB(70, 105, 115),
		Enum.Material.Glass
	)
	windshield.Transparency = 0.25
	windshield.CanCollide = false
	weldToChassis(
		chassis,
		windshield,
		CFrame.new(0, 2.85, -0.1) * CFrame.Angles(math.rad(-12), 0, 0)
	)
	windshield.Parent = vehicle

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2.4, 1, 2.4)
	seat.Color = Color3.fromRGB(40, 40, 40)
	seat.Material = Enum.Material.SmoothPlastic
	seat.CanCollide = false
	seat.MaxSpeed = 0
	seat.Torque = 0
	weldToChassis(chassis, seat, CFrame.new(0, 1.65, 1.7))
	seat.Parent = vehicle

	for corner, offset in WHEEL_OFFSETS do
		addSuspension(chassis, corner, offset)

		local wheel = makePart(
			"Wheel" .. corner,
			Vector3.new(1.25, 2.8, 2.8),
			Color3.fromRGB(24, 24, 24),
			Enum.Material.Rubber
		)
		wheel.Shape = Enum.PartType.Cylinder
		wheel.CanCollide = false
		weldToChassis(chassis, wheel, CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(90)))
		wheel.Parent = vehicle
	end

	local centerAttachment = Instance.new("Attachment")
	centerAttachment.Name = "CenterAttachment"
	centerAttachment.Parent = chassis

	local driveForce = Instance.new("VectorForce")
	driveForce.Name = "DriveForce"
	driveForce.Attachment0 = centerAttachment
	driveForce.ApplyAtCenterOfMass = true
	driveForce.RelativeTo = Enum.ActuatorRelativeTo.World
	driveForce.Force = Vector3.zero
	driveForce.Parent = chassis

	local steeringVelocity = Instance.new("AngularVelocity")
	steeringVelocity.Name = "SteeringVelocity"
	steeringVelocity.Attachment0 = centerAttachment
	steeringVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	steeringVelocity.MaxTorque = math.huge
	steeringVelocity.AngularVelocity = Vector3.zero
	steeringVelocity.Parent = chassis

	local cameraAttachment = Instance.new("Attachment")
	cameraAttachment.Name = "CameraAttachment"
	cameraAttachment.Position = Vector3.new(0, 2.8, 1.15)
	cameraAttachment.Parent = chassis

	local muzzleAttachment = Instance.new("Attachment")
	muzzleAttachment.Name = "MuzzleAttachment"
	muzzleAttachment.Position = Vector3.new(0, 2.45, -5.45)
	muzzleAttachment.Parent = chassis

	vehicle:PivotTo(spawnCFrame)
	vehicle.Parent = parent
	CollectionService:AddTag(vehicle, "HoonangaVehicle")

	return vehicle
end

return VehicleBuilder
