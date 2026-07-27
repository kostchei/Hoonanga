--!strict

-- GDD 11.5 fire state. One accumulator - Heat - drives everything; the five
-- states are thresholds on it. "Fire stacking" is therefore just heat
-- arriving faster than it decays, and "extinguishing" is the reverse, so a
-- flamethrower burst and a molotov patch stack naturally without either
-- weapon knowing the other exists.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local CombatService = require(script.Parent.CombatService)

local FIRE_PATCH_TAG = "HoonangaFirePatch"
local fireConfig = WeaponConfig.Fire

-- Who last applied heat to each vehicle, so a kill by fire is still credited
-- to whoever lit it rather than to nobody.
local ignitionSource: { [Model]: Model } = setmetatable({}, { __mode = "kv" }) :: any
-- Rolled per second of Critical, so the loss check needs the leftover
-- fraction of a second carried between frames rather than a per-frame roll
-- whose odds would depend on frame rate.
local criticalAccumulator: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local running = false

local function stateForHeat(heat: number): WeaponConfig.FireStateName
	if heat >= fireConfig.CriticalThreshold then
		return "Critical"
	elseif heat >= fireConfig.BurningThreshold then
		return "Burning"
	elseif heat >= fireConfig.IgnitedThreshold then
		return "Ignited"
	elseif heat >= fireConfig.HeatingThreshold then
		return "Heating"
	end
	return "None"
end

local function isBurning(state: WeaponConfig.FireStateName): boolean
	return state == "Ignited" or state == "Burning" or state == "Critical"
end

local function requireNumber(vehicle: Model, attribute: string): number
	local value = vehicle:GetAttribute(attribute)
	if typeof(value) ~= "number" then
		error(string.format("%s has no numeric %s attribute", vehicle:GetFullName(), attribute), 3)
	end
	return value
end

-- Visible flame on the chassis while the fire is self-sustaining. Created and
-- destroyed rather than toggled so an extinguished vehicle leaves nothing
-- behind to be re-enabled by a stale reference.
local function updateFireEffect(vehicle: Model, state: WeaponConfig.FireStateName)
	local chassis = vehicle.PrimaryPart
	if not chassis then
		return
	end

	local existing = chassis:FindFirstChild("HoonangaFire")
	if not isBurning(state) then
		if existing then
			existing:Destroy()
		end
		return
	end

	local effect = existing :: Fire?
	if not effect then
		local created = Instance.new("Fire")
		created.Name = "HoonangaFire"
		created.Color = Color3.fromRGB(255, 154, 58)
		created.SecondaryColor = Color3.fromRGB(84, 30, 12)
		created.Parent = chassis
		effect = created
	end

	if effect then
		local scale = if state == "Critical" then 3.6 elseif state == "Burning" then 2.4 else 1.4
		effect.Size = 5 * scale
		effect.Heat = 4 * scale
	end
end

local FireService = {}

function FireService.AddHeat(vehicle: Model, amount: number, sourceVehicle: Model?)
	if amount <= 0 or vehicle:GetAttribute("Destroyed") then
		return
	end
	if not CombatService.IsHostile(sourceVehicle, vehicle) then
		return
	end

	local heat = math.min(fireConfig.MaxHeat, requireNumber(vehicle, "Heat") + amount)
	vehicle:SetAttribute("Heat", heat)
	vehicle:SetAttribute("FireState", stateForHeat(heat))
	if sourceVehicle then
		ignitionSource[vehicle] = sourceVehicle
	end
end

-- A burning area left by a molotov (GDD 11.4). Parented to the world rather
-- than to a road chunk so chunk recycling can never strand or silently delete
-- a live patch (GDD 24.5 "chunk retirement containing projectiles or fire").
function FireService.CreateFirePatch(
	position: Vector3,
	spec: WeaponConfig.FirePatchSpec,
	sourceVehicle: Model?
): Part
	local world = Workspace:FindFirstChild("HoonangaWorld")
	if not world then
		error("HoonangaWorld does not exist; RoadService.Start must run first", 2)
	end

	local effects = world:FindFirstChild("Effects")
	if not effects then
		local folder = Instance.new("Folder")
		folder.Name = "Effects"
		folder.Parent = world
		effects = folder
	end

	local patch = Instance.new("Part")
	patch.Name = "FirePatch"
	patch.Anchored = true
	patch.CanCollide = false
	patch.CanQuery = false
	patch.CanTouch = false
	patch.Shape = Enum.PartType.Cylinder
	patch.Size = Vector3.new(0.6, spec.Radius * 2, spec.Radius * 2)
	patch.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	patch.Color = Color3.fromRGB(196, 84, 30)
	patch.Material = Enum.Material.Neon
	patch.Transparency = 0.45
	patch:SetAttribute("Radius", spec.Radius)
	patch:SetAttribute("HeatPerSecond", spec.HeatPerSecond)
	patch:SetAttribute("ExpiresAt", Workspace:GetServerTimeNow() + spec.Duration)
	patch.Parent = effects
	CollectionService:AddTag(patch, FIRE_PATCH_TAG)

	if sourceVehicle then
		local link = Instance.new("ObjectValue")
		link.Name = "SourceVehicle"
		link.Value = sourceVehicle
		link.Parent = patch
	end

	local flame = Instance.new("Fire")
	flame.Size = spec.Radius
	flame.Heat = 12
	flame.Color = Color3.fromRGB(255, 138, 46)
	flame.SecondaryColor = Color3.fromRGB(74, 26, 10)
	flame.Parent = patch

	return patch
end

local function stepFirePatches(now: number, deltaTime: number)
	for _, patch in CollectionService:GetTagged(FIRE_PATCH_TAG) do
		if not patch:IsA("BasePart") then
			continue
		end

		local expiresAt = patch:GetAttribute("ExpiresAt")
		if typeof(expiresAt) ~= "number" then
			error(string.format("%s has no ExpiresAt attribute", patch:GetFullName()))
		end
		if now >= expiresAt then
			patch:Destroy()
			continue
		end

		local radius = patch:GetAttribute("Radius") :: number
		local heatPerSecond = patch:GetAttribute("HeatPerSecond") :: number
		local sourceLink = patch:FindFirstChild("SourceVehicle")
		local source = if sourceLink and sourceLink:IsA("ObjectValue")
			then sourceLink.Value :: Model?
			else nil

		for _, vehicle in CollectionService:GetTagged("HoonangaVehicle") do
			if not vehicle:IsA("Model") or not vehicle.PrimaryPart then
				continue
			end
			if vehicle:GetAttribute("Destroyed") then
				continue
			end
			-- Horizontal test only: a patch on the road should catch a
			-- vehicle driving over it regardless of suspension travel, but
			-- should not reach an elevated highway deck overhead.
			local offset = vehicle.PrimaryPart.Position - patch.Position
			if math.abs(offset.Y) > 12 then
				continue
			end
			if Vector3.new(offset.X, 0, offset.Z).Magnitude > radius then
				continue
			end
			FireService.AddHeat(vehicle, heatPerSecond * deltaTime, source)
		end
	end
end

local function stepVehicle(vehicle: Model, deltaTime: number)
	local heat = requireNumber(vehicle, "Heat")
	if heat <= 0 then
		return
	end

	if vehicle:GetAttribute("Destroyed") then
		vehicle:SetAttribute("Heat", 0)
		vehicle:SetAttribute("FireState", "None")
		updateFireEffect(vehicle, "None")
		return
	end

	local state = stateForHeat(heat)
	local source = ignitionSource[vehicle]

	if isBurning(state) then
		local damage = fireConfig.DamagePerSecond[state]
		CombatService.ApplyDamage(vehicle, "Hull", damage.Hull * deltaTime, source)
		CombatService.ApplyDamage(vehicle, "Personnel", damage.Personnel * deltaTime, source)
		heat += fireConfig.SelfHeatPerSecond[state] * deltaTime

		if state == "Critical" then
			local pending = (criticalAccumulator[vehicle] or 0) + deltaTime
			while pending >= 1 do
				pending -= 1
				if math.random() < fireConfig.CriticalOperatorLossChancePerSecond then
					CombatService.ApplyDamage(
						vehicle,
						"Personnel",
						fireConfig.CriticalOperatorLossDamage,
						source
					)
				end
			end
			criticalAccumulator[vehicle] = pending
		else
			criticalAccumulator[vehicle] = nil
		end
	else
		criticalAccumulator[vehicle] = nil
	end

	local decay = fireConfig.DecayPerSecond

	local surface = vehicle:GetAttribute("SurfaceProfile")
	if typeof(surface) == "string" then
		local multiplier = fireConfig.SurfaceDecayMultiplier[surface]
		if multiplier then
			decay *= multiplier
		end
	end

	-- Airflow strips small external flames quickly but barely touches an
	-- established vehicle fire (GDD 11.5).
	local forwardSpeed = math.abs(requireNumber(vehicle, "ForwardSpeed"))
	local speedDecay = fireConfig.SpeedDecayPerSecond
		* math.clamp(forwardSpeed / fireConfig.SpeedDecayReferenceSpeed, 0, 1)
	if isBurning(state) then
		speedDecay *= fireConfig.EstablishedSpeedDecayScale
	end
	local upgradeCooling = vehicle:GetAttribute("UpgradeHeatCoolMultiplier")
	if typeof(upgradeCooling) == "number" then
		decay *= math.clamp(upgradeCooling, 0.5, 2)
	end

	heat = math.clamp(heat - (decay + speedDecay) * deltaTime, 0, fireConfig.MaxHeat)

	local newState = stateForHeat(heat)
	vehicle:SetAttribute("Heat", heat)
	vehicle:SetAttribute("FireState", newState)
	updateFireEffect(vehicle, newState)

	if heat <= 0 then
		ignitionSource[vehicle] = nil
	end
end

-- Exposed so tests can advance the simulation by an exact amount of time
-- instead of sleeping and hoping the scheduler cooperated.
function FireService.StepForTest(deltaTime: number)
	stepFirePatches(Workspace:GetServerTimeNow(), deltaTime)
	for _, vehicle in CollectionService:GetTagged("HoonangaVehicle") do
		if vehicle:IsA("Model") then
			stepVehicle(vehicle, deltaTime)
		end
	end
end

function FireService.GetState(vehicle: Model): WeaponConfig.FireStateName
	local state = vehicle:GetAttribute("FireState")
	if typeof(state) ~= "string" then
		error(string.format("%s has no FireState attribute", vehicle:GetFullName()), 2)
	end
	return state :: WeaponConfig.FireStateName
end

function FireService.Start()
	if running then
		return
	end
	running = true

	RunService.Heartbeat:Connect(function(deltaTime)
		stepFirePatches(Workspace:GetServerTimeNow(), deltaTime)
		for _, vehicle in CollectionService:GetTagged("HoonangaVehicle") do
			if vehicle:IsA("Model") then
				stepVehicle(vehicle, deltaTime)
			end
		end
	end)
end

return FireService
