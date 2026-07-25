--!strict

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatService = require(script.Parent.CombatService)

local VEHICLE_IMPACT_THRESHOLD = 18
local BOUNDARY_IMPACT_THRESHOLD = 28
local VEHICLE_IMPACT_COOLDOWN = 0.65
local BOUNDARY_IMPACT_COOLDOWN = 0.45
local FALL_DESTROY_Y = -80

local boundVehicles: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local previousVelocities: { [Model]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any
local lastBoundaryImpact: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local lastVehicleImpact: { [Model]: { [Model]: number } } = setmetatable({}, { __mode = "k" }) :: any

local function getVehicleFromPart(part: Instance?): Model?
	local current = part
	while current and current ~= Workspace do
		if current:IsA("Model") and CollectionService:HasTag(current, "HoonangaVehicle") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function vehicleVelocity(vehicle: Model): Vector3
	local previous = previousVelocities[vehicle]
	if previous then
		return previous
	end
	local chassis = vehicle.PrimaryPart
	return if chassis then chassis.AssemblyLinearVelocity else Vector3.zero
end

local function pairImpactIsCoolingDown(first: Model, second: Model, now: number): boolean
	local firstImpacts = lastVehicleImpact[first]
	local lastImpact = if firstImpacts then firstImpacts[second] else nil
	if lastImpact and now - lastImpact < VEHICLE_IMPACT_COOLDOWN then
		return true
	end

	if not firstImpacts then
		firstImpacts = setmetatable({}, { __mode = "k" }) :: any
		lastVehicleImpact[first] = firstImpacts
	end
	local secondImpacts = lastVehicleImpact[second]
	if not secondImpacts then
		secondImpacts = setmetatable({}, { __mode = "k" }) :: any
		lastVehicleImpact[second] = secondImpacts
	end
	firstImpacts[second] = now
	secondImpacts[first] = now
	return false
end

local function applyVehicleImpact(first: Model, second: Model)
	if first:GetAttribute("Destroyed") or second:GetAttribute("Destroyed") then
		return
	end

	local firstChassis = first.PrimaryPart
	local secondChassis = second.PrimaryPart
	if not firstChassis or not secondChassis then
		return
	end

	local separation = firstChassis.Position - secondChassis.Position
	local collisionNormal = if separation.Magnitude > 0.01 then separation.Unit else Vector3.xAxis
	local relativeVelocity = vehicleVelocity(first) - vehicleVelocity(second)
	local closingSpeed =
		math.max(0, -relativeVelocity:Dot(collisionNormal), relativeVelocity.Magnitude * 0.35)
	if closingSpeed < VEHICLE_IMPACT_THRESHOLD then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if pairImpactIsCoolingDown(first, second, now) then
		return
	end

	local firstMass = math.max(1, firstChassis.AssemblyMass)
	local secondMass = math.max(1, secondChassis.AssemblyMass)
	local baseDamage = ((closingSpeed - VEHICLE_IMPACT_THRESHOLD) ^ 1.15) * 0.12
	local firstConvoy = first:GetAttribute("ConvoyId")
	local sameConvoy = typeof(firstConvoy) == "string"
		and firstConvoy == second:GetAttribute("ConvoyId")
	-- Catch-up help remains bounded and never grants collision immunity:
	-- companions still trade damage, but a legitimate recovery sprint is less
	-- likely to erase the convoy when it reaches formation.
	if
		sameConvoy
		and (
			first:GetAttribute("CatchUpActive") == true
			or second:GetAttribute("CatchUpActive") == true
		)
	then
		baseDamage *= 0.45
	end
	local damageToFirst = baseDamage * math.clamp(secondMass / firstMass, 0.55, 1.8)
	local damageToSecond = baseDamage * math.clamp(firstMass / secondMass, 0.55, 1.8)

	first:SetAttribute("LastImpactSpeed", closingSpeed)
	first:SetAttribute("LastImpactType", "Vehicle")
	first:SetAttribute("LastImpactAt", now)
	second:SetAttribute("LastImpactSpeed", closingSpeed)
	second:SetAttribute("LastImpactType", "Vehicle")
	second:SetAttribute("LastImpactAt", now)
	-- Impact rather than hull, so ram equipment on either vehicle modifies
	-- the exchange (GDD 11.4). Deliberately not friendly-fire immune: two
	-- convoy vehicles that collide at 60 studs a second have still collided.
	CombatService.ApplyImpactDamage(first, damageToFirst, second)
	CombatService.ApplyImpactDamage(second, damageToSecond, first)
end

local function applyBoundaryImpact(vehicle: Model, boundary: BasePart)
	if vehicle:GetAttribute("Destroyed") then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local lastImpact = lastBoundaryImpact[vehicle]
	if lastImpact and now - lastImpact < BOUNDARY_IMPACT_COOLDOWN then
		return
	end

	local speed = vehicleVelocity(vehicle).Magnitude
	if speed < BOUNDARY_IMPACT_THRESHOLD then
		return
	end
	lastBoundaryImpact[vehicle] = now

	local damage = ((speed - BOUNDARY_IMPACT_THRESHOLD) ^ 1.18) * 0.1
	vehicle:SetAttribute("LastImpactSpeed", speed)
	vehicle:SetAttribute("LastImpactType", boundary:GetAttribute("BoundaryType") or "Terrain")
	vehicle:SetAttribute("LastImpactAt", now)
	-- Terrain, not impact: a ram bar helps you win a ramming exchange, it
	-- does not help you hit a canyon wall.
	CombatService.ApplyDamage(vehicle, "Terrain", damage, nil)
end

local function bindVehicle(instance: Instance)
	if not instance:IsA("Model") or boundVehicles[instance] then
		return
	end
	local chassis = instance.PrimaryPart
	if not chassis then
		return
	end
	boundVehicles[instance] = true

	chassis.Touched:Connect(function(otherPart)
		if not instance.Parent or instance:GetAttribute("Destroyed") then
			return
		end

		local otherVehicle = getVehicleFromPart(otherPart)
		if otherVehicle and otherVehicle ~= instance then
			applyVehicleImpact(instance, otherVehicle)
			return
		end

		if
			otherPart:GetAttribute("Lethal") == true
			or CollectionService:HasTag(otherPart, "RoadLethalZone")
		then
			CombatService.DestroyVehicle(instance, nil)
		elseif CollectionService:HasTag(otherPart, "RoadHardBoundary") then
			applyBoundaryImpact(instance, otherPart)
		end
	end)
end

local function captureVelocities()
	for _, vehicle in CollectionService:GetTagged("HoonangaVehicle") do
		if vehicle:IsA("Model") and vehicle.PrimaryPart then
			previousVelocities[vehicle] = vehicle.PrimaryPart.AssemblyLinearVelocity
		end
	end
end

local CollisionDamageService = {}

function CollisionDamageService.Start()
	for _, vehicle in CollectionService:GetTagged("HoonangaVehicle") do
		bindVehicle(vehicle)
	end
	CollectionService:GetInstanceAddedSignal("HoonangaVehicle"):Connect(bindVehicle)

	RunService.PreSimulation:Connect(captureVelocities)

	task.spawn(function()
		while true do
			for _, vehicle in CollectionService:GetTagged("HoonangaVehicle") do
				if
					vehicle:IsA("Model")
					and vehicle.PrimaryPart
					and not vehicle:GetAttribute("Destroyed")
					and vehicle.PrimaryPart.Position.Y < FALL_DESTROY_Y
				then
					vehicle:SetAttribute("LastImpactType", "Fall")
					CombatService.DestroyVehicle(vehicle, nil)
				end
			end
			task.wait(0.1)
		end
	end)
end

function CollisionDamageService.ApplyVehicleImpactForTest(first: Model, second: Model)
	applyVehicleImpact(first, second)
end

function CollisionDamageService.ApplyBoundaryImpactForTest(vehicle: Model, boundary: BasePart)
	applyBoundaryImpact(vehicle, boundary)
end

function CollisionDamageService.CaptureVelocitiesForTest()
	captureVelocities()
end

return CollisionDamageService
