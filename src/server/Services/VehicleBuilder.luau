--!strict

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
local WeaponState = require(ReplicatedStorage.Shared.WeaponState)
local RoadtrainArtBuilder = require(script.Parent.RoadtrainArtBuilder)

local CHASSIS_SIZE = Vector3.new(6.4, 1.8, 15.4)
local PICKUP_ASSET_ID = 6418225759
local PICKUP_SOURCE_URL = "https://create.roblox.com/store/asset/6418225759/Pickup-Truck"
local PICKUP_VISUAL_SCALE = 0.576
local PICKUP_GROUND_OFFSET = -2.8
local PICKUP_VARIANTS = {
	Player = "Pickup Truck (bronze)",
	Enemy = "Pickup Truck (blue)",
}
local PICKUP_SEAT_OFFSET = Vector3.new(-0.98, 0.08, -1.25)
local PICKUP_CAMERA_OFFSET = Vector3.new(-0.98, 1.9, -1.25)
local PICKUP_TURRET_POSITION = Vector3.new(0, 2.75, 3.6)
local PICKUP_TURRET_MUZZLE = Vector3.new(0, 2.92, -1.85)
local PICKUP_FORWARD_MUZZLE = Vector3.new(0, 0.35, -7.8)
local TURRET_ASSET_ID = 2046384884
local TURRET_SOURCE_URL = "https://create.roblox.com/store/asset/2046384884/Machine-Gun-Turret"
local WHEEL_OFFSETS = {
	FL = Vector3.new(-3.05, -1.05, -4.65),
	FR = Vector3.new(3.05, -1.05, -4.65),
	RL = Vector3.new(-3.05, -1.05, 4.65),
	RR = Vector3.new(3.05, -1.05, 4.65),
}

-- These are "loaded" (the fetch has finished, successfully or not) rather
-- than "attempted" (the fetch has started). LoadAssetAsync yields on the
-- network, so a caller arriving during another caller's in-flight fetch has
-- to wait for it instead of sailing past an already-started flag and
-- finding an empty cache - see loadPickupBodyTemplates.
local pickupAssetLoaded = false
local pickupAssetLoading = false
local pickupBodyTemplates: { [string]: Model } = {}
local turretAssetLoaded = false
local turretAssetLoading = false
local turretAssetTemplate: Model? = nil
local assetLoadingEnabled = true

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

	local springForce = Instance.new("VectorForce")
	springForce.Name = "Suspension" .. corner
	springForce.Attachment0 = attachment
	springForce.ApplyAtCenterOfMass = false
	springForce.RelativeTo = Enum.ActuatorRelativeTo.World
	springForce.Force = Vector3.zero
	springForce.Parent = chassis

	-- Per-wheel lateral grip. Front and rear corners get different amounts
	-- of steer angle applied in VehiclePhysics, so the differential grip
	-- between them is what turns the vehicle and keeps it upright - no
	-- separate yaw-torque or self-level constraint is needed, and none is
	-- present here on purpose (see VehiclePhysics.luau for why one used to
	-- be here and caused the vehicle to jitter).
	local lateralForce = Instance.new("VectorForce")
	lateralForce.Name = "LateralGrip" .. corner
	lateralForce.Attachment0 = attachment
	lateralForce.ApplyAtCenterOfMass = false
	lateralForce.RelativeTo = Enum.ActuatorRelativeTo.World
	lateralForce.Force = Vector3.zero
	lateralForce.Parent = chassis
end

local function sanitizePickupBody(body: Model)
	for _, descendant in body:GetDescendants() do
		if
			descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Constraint")
			or descendant:IsA("Attachment")
			or descendant:IsA("ProximityPrompt")
			or descendant:IsA("Sound")
			or descendant:IsA("RemoteEvent")
			or descendant:IsA("BindableEvent")
			or descendant:IsA("ValueBase")
			or descendant:IsA("GuiObject")
		then
			descendant:Destroy()
		end
	end
end

local function loadPickupBodyTemplates()
	if pickupAssetLoaded then
		return
	end
	if pickupAssetLoading then
		repeat
			task.wait()
		until pickupAssetLoaded
		return
	end
	pickupAssetLoading = true

	local success, result = pcall(function()
		return AssetService:LoadAssetAsync(PICKUP_ASSET_ID)
	end)

	-- Release the gate before any early return, so a failed fetch can never
	-- leave a concurrent caller waiting forever.
	pickupAssetLoaded = true
	pickupAssetLoading = false

	if not success or not result or not result:IsA("Model") then
		warn(
			string.format(
				"[Hoonanga] Creator Store pickup %d unavailable; using safe fallback body",
				PICKUP_ASSET_ID
			)
		)
		return
	end

	for _, variantName in PICKUP_VARIANTS do
		local variant = result:FindFirstChild(variantName)
		local body = if variant then variant:FindFirstChild("Body") else nil
		if body and body:IsA("Model") then
			local template = body:Clone()
			template.Name = "CreatorStoreBody"
			template:SetAttribute("SourceAssetId", PICKUP_ASSET_ID)
			template:SetAttribute("SourceUrl", PICKUP_SOURCE_URL)
			template:SetAttribute("SourceVariant", variantName)
			sanitizePickupBody(template)
			template.Parent = nil
			pickupBodyTemplates[variantName] = template
		else
			warn(string.format("[Hoonanga] Pickup asset is missing visual variant %s", variantName))
		end
	end

	result:Destroy()
	print(
		string.format(
			"[Hoonanga] Audited pickup %d; retained script-free body/interior only",
			PICKUP_ASSET_ID
		)
	)
end

local function mountPickupBody(vehicle: Model, chassis: Part, bodyColor: Color3): boolean
	if not assetLoadingEnabled then
		return false
	end
	loadPickupBodyTemplates()

	local variantName = if bodyColor.B > bodyColor.R
		then PICKUP_VARIANTS.Enemy
		else PICKUP_VARIANTS.Player
	local template = pickupBodyTemplates[variantName]
	if not template then
		return false
	end

	local visual = template:Clone()
	visual:ScaleTo(PICKUP_VISUAL_SCALE)
	visual.Parent = vehicle

	local bodyFrame, bodySize = visual:GetBoundingBox()
	local pivotToBody = visual:GetPivot():ToObjectSpace(bodyFrame)
	local targetBodyFrame = chassis.CFrame * CFrame.new(0, PICKUP_GROUND_OFFSET + bodySize.Y / 2, 0)
	visual:PivotTo(targetBodyFrame * pivotToBody:Inverse())

	local partCount = 0
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			partCount += 1
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			weldToChassis(chassis, descendant, chassis.CFrame:ToObjectSpace(descendant.CFrame))
		end
	end

	if partCount == 0 then
		visual:Destroy()
		return false
	end

	vehicle:SetAttribute("VisualAssetId", PICKUP_ASSET_ID)
	vehicle:SetAttribute("VisualVariant", variantName)
	return true
end

local function getTurretAssetTemplate(): Model?
	if not assetLoadingEnabled then
		return nil
	end
	if turretAssetLoaded then
		return turretAssetTemplate
	end
	if turretAssetLoading then
		repeat
			task.wait()
		until turretAssetLoaded
		return turretAssetTemplate
	end
	turretAssetLoading = true

	local success, result = pcall(function()
		return AssetService:LoadAssetAsync(TURRET_ASSET_ID)
	end)

	turretAssetLoaded = true
	turretAssetLoading = false

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

local function mountFallbackTurret(vehicle: Model, chassis: Part, mountPosition: Vector3)
	local pedestal = makePart(
		"TurretPedestal",
		Vector3.new(2.2, 0.55, 2.2),
		Color3.fromRGB(52, 50, 46),
		Enum.Material.Metal
	)
	pedestal.Shape = Enum.PartType.Cylinder
	pedestal.CanCollide = false
	weldToChassis(
		chassis,
		pedestal,
		CFrame.new(mountPosition + Vector3.new(0, -0.4, 0.15)) * CFrame.Angles(0, 0, math.rad(90))
	)
	pedestal.Parent = vehicle

	local receiver = makePart(
		"TurretReceiver",
		Vector3.new(1.2, 0.9, 1.8),
		Color3.fromRGB(39, 40, 38),
		Enum.Material.Metal
	)
	receiver.CanCollide = false
	weldToChassis(chassis, receiver, CFrame.new(mountPosition + Vector3.new(0, 0.1, -0.2)))
	receiver.Parent = vehicle

	local barrel = makePart(
		"TurretBarrel",
		Vector3.new(0.32, 0.32, 4.4),
		Color3.fromRGB(30, 31, 30),
		Enum.Material.Metal
	)
	barrel.CanCollide = false
	weldToChassis(chassis, barrel, CFrame.new(mountPosition + Vector3.new(0, 0.17, -3.2)))
	barrel.Parent = vehicle
end

local function mountStoreTurret(vehicle: Model, chassis: Part, mountPosition: Vector3): boolean
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
	turret:PivotTo(chassis.CFrame * CFrame.new(mountPosition))

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

function VehicleBuilder.SetAssetLoadingEnabledForTests(enabled: boolean)
	assetLoadingEnabled = enabled
end

function VehicleBuilder.CreateUte(
	parent: Instance,
	name: string,
	spawnCFrame: CFrame,
	bodyColor: Color3
): Model
	local config = VehicleConfig.Ute
	local vehicle = Instance.new("Model")
	vehicle.Name = name
	vehicle:SetAttribute("VehicleType", "Ute")
	vehicle:SetAttribute("Hull", config.MaxHull)
	vehicle:SetAttribute("MaxHull", config.MaxHull)
	vehicle:SetAttribute("OperatorHealth", config.MaxOperatorHealth)
	vehicle:SetAttribute("MaxOperatorHealth", config.MaxOperatorHealth)
	vehicle:SetAttribute("OperatorAlive", true)
	vehicle:SetAttribute("PersonnelProtected", config.PersonnelProtected)
	vehicle:SetAttribute("Fuel", config.FuelCapacity)
	vehicle:SetAttribute("MaxFuel", config.FuelCapacity)
	vehicle:SetAttribute("FuelConsumptionMultiplier", config.FuelConsumptionMultiplier)
	vehicle:SetAttribute("OutOfFuel", false)
	-- GDD 11.5 fire state. Heat is the accumulator FireService drives; every
	-- vehicle carries it from birth so nothing has to test for its absence.
	vehicle:SetAttribute("Heat", 0)
	vehicle:SetAttribute("FireState", "None")
	-- VehiclePhysics republishes this every step, but a vehicle can be set
	-- alight (or shot, or rammed) before it has ever been stepped - on the
	-- spawn frame, or while parked with no driver - and FireService reads it
	-- to decide how much airflow is stripping the flames.
	vehicle:SetAttribute("ForwardSpeed", 0)
	vehicle:SetAttribute("DamageMultiplier", 1)
	-- GDD 11.4 ram: equipment modifies impact damage dealt and received. The
	-- base ute has no ram equipment, so both are neutral until a garage
	-- fitting changes them.
	vehicle:SetAttribute("RamDealtMultiplier", config.RamDealtMultiplier)
	vehicle:SetAttribute("RamReceivedMultiplier", config.RamReceivedMultiplier)
	vehicle:SetAttribute("MuzzleBlocked", false)
	vehicle:SetAttribute("AimOutOfTraverse", false)
	WeaponState.Initialise(vehicle)
	vehicle:SetAttribute("ServerThrottle", 0)
	vehicle:SetAttribute("ServerSteer", 0)
	vehicle:SetAttribute("ServerHandbrake", false)
	vehicle:SetAttribute("Destroyed", false)
	vehicle:SetAttribute("Operational", true)

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

	local mountedCreatorStoreBody = mountPickupBody(vehicle, chassis, bodyColor)
	if not mountedCreatorStoreBody then
		local body = makePart("Body", Vector3.new(6.2, 1.5, 11.8), bodyColor, Enum.Material.Metal)
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
		weldToChassis(chassis, cabin, CFrame.new(0, 2.6, -1.2))
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
			CFrame.new(0, 2.85, -3) * CFrame.Angles(math.rad(-12), 0, 0)
		)
		windshield.Parent = vehicle
	end

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2.4, 1, 2.4)
	seat.Color = Color3.fromRGB(40, 40, 40)
	seat.Material = Enum.Material.SmoothPlastic
	seat.CanCollide = false
	seat.Disabled = false
	seat.MaxSpeed = 0
	seat.Torque = 0
	local seatOffset = if mountedCreatorStoreBody
		then PICKUP_SEAT_OFFSET
		else Vector3.new(0, 1.65, -1.2)
	weldToChassis(chassis, seat, CFrame.new(seatOffset))
	seat.Parent = vehicle

	-- The personnel damage channel (GDD 11.1/11.2): an invisible, non-physical
	-- hitbox standing in for the operator's torso, positioned above the seat.
	-- CanQuery stays true (it's the only thing about this part that matters)
	-- so weapon raycasts can single it out from the surrounding hull.
	local personnelHitbox = makePart(
		"PersonnelHitbox",
		Vector3.new(1.6, 2.1, 1.6),
		bodyColor,
		Enum.Material.SmoothPlastic
	)
	personnelHitbox.Transparency = 1
	personnelHitbox.CanCollide = false
	personnelHitbox.CanTouch = false
	personnelHitbox.CanQuery = true
	weldToChassis(chassis, personnelHitbox, CFrame.new(seatOffset + Vector3.new(0, 1.1, 0)))
	personnelHitbox.Parent = vehicle

	for corner, offset in WHEEL_OFFSETS do
		addSuspension(chassis, corner, offset)

		if not mountedCreatorStoreBody then
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

	-- Yaw-only torque assist for low-speed responsiveness (real tire slip is
	-- too weak to turn the car when it's barely moving, which is why an
	-- arcade driving feel needs a direct nudge here). This does not touch
	-- roll or pitch, so it does not compete with the per-corner suspension
	-- the way the old AlignOrientation self-level constraint did.
	local steeringTorque = Instance.new("Torque")
	steeringTorque.Name = "SteeringTorque"
	steeringTorque.Attachment0 = centerAttachment
	steeringTorque.RelativeTo = Enum.ActuatorRelativeTo.World
	steeringTorque.Torque = Vector3.zero
	steeringTorque.Parent = chassis

	local cameraAttachment = Instance.new("Attachment")
	cameraAttachment.Name = "CameraAttachment"
	cameraAttachment.Position = if mountedCreatorStoreBody
		then PICKUP_CAMERA_OFFSET
		else Vector3.new(0, 4.8, -1.2)
	cameraAttachment.Parent = chassis

	local turretMuzzle = Instance.new("Attachment")
	turretMuzzle.Name = "TurretMuzzleAttachment"
	turretMuzzle.Position = if mountedCreatorStoreBody
		then PICKUP_TURRET_MUZZLE
		else Vector3.new(0, 3.82, -1.85)
	turretMuzzle.Parent = chassis

	local forwardMuzzle = Instance.new("Attachment")
	forwardMuzzle.Name = "ForwardMuzzleAttachment"
	forwardMuzzle.Position = if mountedCreatorStoreBody
		then PICKUP_FORWARD_MUZZLE
		else Vector3.new(0, 2.1, -7.8)
	forwardMuzzle.Parent = chassis

	local turretPosition = if mountedCreatorStoreBody
		then PICKUP_TURRET_POSITION
		else Vector3.new(0, 3.65, 3.6)
	if not mountStoreTurret(vehicle, chassis, turretPosition) then
		mountFallbackTurret(vehicle, chassis, turretPosition)
	end

	-- GDD 11.2 hit regions. Weapons resolve a hit by reading this attribute
	-- rather than by matching part names, so every queryable part on the
	-- vehicle has to declare one. Everything defaults to hull and the
	-- operator box overrides itself, which is the correct default: an
	-- unlabelled new part is structure, not crew.
	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant:SetAttribute("HitRegion", "Hull")
		end
	end
	personnelHitbox:SetAttribute("HitRegion", "Personnel")

	vehicle:PivotTo(spawnCFrame)
	vehicle.Parent = parent
	CollectionService:AddTag(vehicle, "HoonangaVehicle")
	chassis.Anchored = false

	return vehicle
end

local function createGrayboxVehicle(
	vehicleType: string,
	parent: Instance,
	name: string,
	spawnCFrame: CFrame,
	bodyColor: Color3
): Model
	local config = VehicleConfig[vehicleType]
	assert(config, string.format("Unknown vehicle type %q", vehicleType))

	local vehicle = Instance.new("Model")
	vehicle.Name = name
	vehicle:SetAttribute("VehicleType", vehicleType)
	vehicle:SetAttribute("Hull", config.MaxHull)
	vehicle:SetAttribute("MaxHull", config.MaxHull)
	vehicle:SetAttribute("OperatorHealth", config.MaxOperatorHealth)
	vehicle:SetAttribute("MaxOperatorHealth", config.MaxOperatorHealth)
	vehicle:SetAttribute("OperatorAlive", true)
	vehicle:SetAttribute("PersonnelProtected", config.PersonnelProtected)
	vehicle:SetAttribute("Fuel", config.FuelCapacity)
	vehicle:SetAttribute("MaxFuel", config.FuelCapacity)
	vehicle:SetAttribute("FuelConsumptionMultiplier", config.FuelConsumptionMultiplier)
	vehicle:SetAttribute("OutOfFuel", false)
	vehicle:SetAttribute("Heat", 0)
	vehicle:SetAttribute("FireState", "None")
	vehicle:SetAttribute("ForwardSpeed", 0)
	vehicle:SetAttribute("DamageMultiplier", 1)
	vehicle:SetAttribute("RamDealtMultiplier", config.RamDealtMultiplier)
	vehicle:SetAttribute("RamReceivedMultiplier", config.RamReceivedMultiplier)
	vehicle:SetAttribute("MuzzleBlocked", false)
	vehicle:SetAttribute("AimOutOfTraverse", false)
	vehicle:SetAttribute("ServerThrottle", 0)
	vehicle:SetAttribute("ServerSteer", 0)
	vehicle:SetAttribute("ServerHandbrake", false)
	vehicle:SetAttribute("Destroyed", false)
	vehicle:SetAttribute("Operational", true)
	WeaponState.Initialise(vehicle)

	local chassis = makePart("Chassis", config.ChassisSize, bodyColor, Enum.Material.Metal)
	chassis.Anchored = true
	chassis.RootPriority = 127
	chassis.CustomPhysicalProperties = PhysicalProperties.new(
		if vehicleType == "Roadtrain" then 4.2 elseif vehicleType == "Bike" then 1.45 else 2.4,
		0.5,
		0.05,
		1,
		1
	)
	chassis.Parent = vehicle
	vehicle.PrimaryPart = chassis

	local ballast =
		makePart("Ballast", config.BallastSize, Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
	ballast.Transparency = 1
	ballast.CanCollide = false
	ballast.Massless = false
	ballast.CustomPhysicalProperties = PhysicalProperties.new(6, 0, 0, 100, 100)
	weldToChassis(chassis, ballast, CFrame.new(config.BallastOffset))
	ballast.Parent = vehicle

	local body = makePart("Body", config.BodySize, bodyColor, Enum.Material.Metal)
	body.CanCollide = false
	weldToChassis(chassis, body, CFrame.new(config.BodyOffset))
	body.Parent = vehicle

	if vehicleType == "Roadtrain" then
		body.Transparency = 1
		RoadtrainArtBuilder.Build(vehicle, chassis, bodyColor)
	else
		local tank = makePart(
			"FuelTankVisual",
			Vector3.new(2.1, 1.5, 2.8),
			bodyColor:Lerp(Color3.new(1, 1, 1), 0.08),
			Enum.Material.Metal
		)
		tank.CanCollide = false
		weldToChassis(chassis, tank, CFrame.new(0, 1.75, -0.6))
		tank.Parent = vehicle
	end

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = if vehicleType == "Bike"
		then Vector3.new(1.4, 0.7, 1.8)
		else Vector3.new(2.4, 1, 2.4)
	seat.Color = Color3.fromRGB(40, 40, 40)
	seat.Material = Enum.Material.SmoothPlastic
	seat.CanCollide = false
	seat.Disabled = false
	seat.MaxSpeed = 0
	seat.Torque = 0
	weldToChassis(chassis, seat, CFrame.new(config.SeatOffset))
	seat.Parent = vehicle

	local personnelHitbox = makePart(
		"PersonnelHitbox",
		config.PersonnelHitboxSize,
		bodyColor,
		Enum.Material.SmoothPlastic
	)
	personnelHitbox.Transparency = 1
	personnelHitbox.CanCollide = false
	personnelHitbox.CanTouch = false
	personnelHitbox.CanQuery = not config.PersonnelProtected
	weldToChassis(chassis, personnelHitbox, CFrame.new(config.SeatOffset + Vector3.new(0, 1.1, 0)))
	personnelHitbox.Parent = vehicle

	for _, contact in config.WheelContacts do
		addSuspension(chassis, contact.Name, contact.Offset)
	end

	if vehicleType == "Bike" then
		for _, wheelOffset in
			{
				Vector3.new(0, -0.7, -2.65),
				Vector3.new(0, -0.7, 2.6),
			}
		do
			local wheel = makePart(
				"BikeWheel",
				Vector3.new(0.65, 2.7, 2.7),
				Color3.fromRGB(24, 24, 24),
				Enum.Material.Rubber
			)
			wheel.Shape = Enum.PartType.Cylinder
			wheel.CanCollide = false
			weldToChassis(
				chassis,
				wheel,
				CFrame.new(wheelOffset) * CFrame.Angles(0, 0, math.rad(90))
			)
			wheel.Parent = vehicle
		end
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

	local steeringTorque = Instance.new("Torque")
	steeringTorque.Name = "SteeringTorque"
	steeringTorque.Attachment0 = centerAttachment
	steeringTorque.RelativeTo = Enum.ActuatorRelativeTo.World
	steeringTorque.Torque = Vector3.zero
	steeringTorque.Parent = chassis

	local cameraAttachment = Instance.new("Attachment")
	cameraAttachment.Name = "CameraAttachment"
	cameraAttachment.Position = config.CameraOffset
	cameraAttachment.Parent = chassis

	local turretMuzzle = Instance.new("Attachment")
	turretMuzzle.Name = "TurretMuzzleAttachment"
	turretMuzzle.Position = config.TurretMuzzle
	turretMuzzle.Parent = chassis

	local forwardMuzzle = Instance.new("Attachment")
	forwardMuzzle.Name = "ForwardMuzzleAttachment"
	forwardMuzzle.Position = config.ForwardMuzzle
	forwardMuzzle.Parent = chassis

	if not mountStoreTurret(vehicle, chassis, config.TurretPosition) then
		mountFallbackTurret(vehicle, chassis, config.TurretPosition)
	end

	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant:SetAttribute("HitRegion", "Hull")
		end
	end
	personnelHitbox:SetAttribute("HitRegion", "Personnel")

	vehicle:PivotTo(spawnCFrame)
	vehicle.Parent = parent
	CollectionService:AddTag(vehicle, "HoonangaVehicle")
	chassis.Anchored = false
	return vehicle
end

function VehicleBuilder.CreateRoadtrain(
	parent: Instance,
	name: string,
	spawnCFrame: CFrame,
	bodyColor: Color3
): Model
	return createGrayboxVehicle("Roadtrain", parent, name, spawnCFrame, bodyColor)
end

function VehicleBuilder.CreateBike(
	parent: Instance,
	name: string,
	spawnCFrame: CFrame,
	bodyColor: Color3
): Model
	return createGrayboxVehicle("Bike", parent, name, spawnCFrame, bodyColor)
end

function VehicleBuilder.Create(
	vehicleType: string,
	parent: Instance,
	name: string,
	spawnCFrame: CFrame,
	bodyColor: Color3
): Model
	if vehicleType == "Ute" then
		return VehicleBuilder.CreateUte(parent, name, spawnCFrame, bodyColor)
	elseif vehicleType == "Roadtrain" then
		return VehicleBuilder.CreateRoadtrain(parent, name, spawnCFrame, bodyColor)
	elseif vehicleType == "Bike" then
		return VehicleBuilder.CreateBike(parent, name, spawnCFrame, bodyColor)
	end
	error(string.format("Unknown vehicle type %q", vehicleType), 2)
end

return VehicleBuilder
