--!strict

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")

local CHASSIS_SIZE = Vector3.new(6.4, 1.8, 10.4)
local TURRET_ASSET_ID = 2046384884
local TURRET_SOURCE_URL = "https://create.roblox.com/store/asset/2046384884/Machine-Gun-Turret"
local WHEEL_OFFSETS = {
	FL = Vector3.new(-3.35, -1.05, -3.35),
	FR = Vector3.new(3.35, -1.05, -3.35),
	RL = Vector3.new(-3.35, -1.05, 3.35),
	RR = Vector3.new(3.35, -1.05, 3.35),
}

local turretAssetAttempted = false
local turretAssetTemplate: Model? = nil

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

local function getTurretAssetTemplate(): Model?
	if turretAssetAttempted then
		return turretAssetTemplate
	end
	turretAssetAttempted = true

	local success, result = pcall(function()
		return AssetService:LoadAssetAsync(TURRET_ASSET_ID)
	end)
	if not success or not result or not result:IsA("Model") then
		warn(
			string.format(
				"[Hoonanga] Creator Store turret %d unavailable; using safe fallback",
				TURRET_ASSET_ID
			)
		)
		return nil
	end

	for _, descendant in result:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	result.Parent = nil
	turretAssetTemplate = result
	print(string.format("[Hoonanga] Loaded no-script Creator Store turret %d", TURRET_ASSET_ID))
	return turretAssetTemplate
end

local function mountFallbackTurret(vehicle: Model, chassis: Part)
	local pedestal = makePart(
		"TurretPedestal",
		Vector3.new(2.2, 0.55, 2.2),
		Color3.fromRGB(52, 50, 46),
		Enum.Material.Metal
	)
	pedestal.Shape = Enum.PartType.Cylinder
	pedestal.CanCollide = false
	weldToChassis(chassis, pedestal, CFrame.new(0, 3.25, 1.55) * CFrame.Angles(0, 0, math.rad(90)))
	pedestal.Parent = vehicle

	local receiver = makePart(
		"TurretReceiver",
		Vector3.new(1.2, 0.9, 1.8),
		Color3.fromRGB(39, 40, 38),
		Enum.Material.Metal
	)
	receiver.CanCollide = false
	weldToChassis(chassis, receiver, CFrame.new(0, 3.75, 1.2))
	receiver.Parent = vehicle

	local barrel = makePart(
		"TurretBarrel",
		Vector3.new(0.32, 0.32, 4.4),
		Color3.fromRGB(30, 31, 30),
		Enum.Material.Metal
	)
	barrel.CanCollide = false
	weldToChassis(chassis, barrel, CFrame.new(0, 3.82, -1.8))
	barrel.Parent = vehicle
end

local function mountStoreTurret(vehicle: Model, chassis: Part): boolean
	local template = getTurretAssetTemplate()
	if not template then
		return false
	end

	local turret = template:Clone()
	turret.Name = "CreatorStoreTurret"
	turret:SetAttribute("SourceAssetId", TURRET_ASSET_ID)
	turret:SetAttribute("SourceUrl", TURRET_SOURCE_URL)
	turret.Parent = vehicle

	local _, size = turret:GetBoundingBox()
	local longestSide = math.max(size.X, size.Y, size.Z)
	if longestSide > 0.01 then
		turret:ScaleTo(4.5 / longestSide)
	end
	turret:PivotTo(chassis.CFrame * CFrame.new(0, 3.65, 1.4))

	local partCount = 0
	for _, descendant in turret:GetDescendants() do
		if descendant:IsA("BasePart") then
			partCount += 1
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true

			local weld = Instance.new("WeldConstraint")
			weld.Name = "TurretChassisWeld"
			weld.Part0 = chassis
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end

	if partCount == 0 then
		turret:Destroy()
		return false
	end
	return true
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
	vehicle:SetAttribute("OutOfFuel", false)
	vehicle:SetAttribute("Ammo", 80)
	vehicle:SetAttribute("ReserveAmmo", 240)
	vehicle:SetAttribute("Reloading", false)
	vehicle:SetAttribute("ServerThrottle", 0)
	vehicle:SetAttribute("ServerSteer", 0)
	vehicle:SetAttribute("ServerHandbrake", false)
	vehicle:SetAttribute("Destroyed", false)

	local chassis = makePart("Chassis", CHASSIS_SIZE, bodyColor, Enum.Material.Metal)
	chassis.Anchored = true
	chassis.CustomPhysicalProperties = PhysicalProperties.new(2.4, 0.5, 0.05, 1, 1)
	chassis.CFrame = CFrame.new()
	chassis.RootPriority = 127
	chassis.Parent = vehicle
	vehicle.PrimaryPart = chassis

	local ballast = makePart(
		"Ballast",
		Vector3.new(5.6, 0.8, 8),
		Color3.fromRGB(30, 30, 30),
		Enum.Material.Metal
	)
	ballast.CanCollide = false
	ballast.Transparency = 1
	ballast.CustomPhysicalProperties = PhysicalProperties.new(6, 0, 0, 100, 100)
	weldToChassis(chassis, ballast, CFrame.new(0, -1.25, 0))
	ballast.Massless = false
	ballast.Parent = vehicle

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
	seat.Disabled = false
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

	local uprightOrientation = Instance.new("AlignOrientation")
	uprightOrientation.Name = "UprightOrientation"
	uprightOrientation.Attachment0 = centerAttachment
	uprightOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	uprightOrientation.MaxAngularVelocity = math.rad(180)
	uprightOrientation.MaxTorque = 2_000_000
	uprightOrientation.Responsiveness = 18
	uprightOrientation.RigidityEnabled = false
	uprightOrientation.CFrame = spawnCFrame.Rotation
	uprightOrientation.Parent = chassis

	local cameraAttachment = Instance.new("Attachment")
	cameraAttachment.Name = "CameraAttachment"
	cameraAttachment.Position = Vector3.new(0, 4.8, 0.4)
	cameraAttachment.Parent = chassis

	local turretMuzzle = Instance.new("Attachment")
	turretMuzzle.Name = "TurretMuzzleAttachment"
	turretMuzzle.Position = Vector3.new(0, 3.82, -4.05)
	turretMuzzle.Parent = chassis

	local forwardMuzzle = Instance.new("Attachment")
	forwardMuzzle.Name = "ForwardMuzzleAttachment"
	forwardMuzzle.Position = Vector3.new(0, 2.1, -5.45)
	forwardMuzzle.Parent = chassis

	if not mountStoreTurret(vehicle, chassis) then
		mountFallbackTurret(vehicle, chassis)
	end

	vehicle:PivotTo(spawnCFrame)
	vehicle.Parent = parent
	CollectionService:AddTag(vehicle, "HoonangaVehicle")

	return vehicle
end

return VehicleBuilder
