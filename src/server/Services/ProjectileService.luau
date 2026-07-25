--!strict

-- Rockets and molotovs (GDD 11.4). Both are simulated server-side as anchored
-- parts stepped by raycast rather than as unanchored physics parts: a
-- physics projectile would be network-owned, replicate late, and let a client
-- decide where its own rocket went. Stepping by raycast also means a fast
-- rocket cannot tunnel through a canyon wall between frames.
--
-- Projectiles live in HoonangaWorld/Effects, never inside a road chunk, so
-- chunk recycling cannot delete a rocket mid-flight (GDD 24.5).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local CombatService = require(script.Parent.CombatService)
local FireService = require(script.Parent.FireService)

type Projectile = {
	Part: Part,
	Config: WeaponConfig.WeaponConfig,
	Spec: WeaponConfig.ProjectileSpec,
	Position: Vector3,
	Velocity: Vector3,
	Source: Model?,
	DamageMultiplier: number,
	ExpiresAt: number,
}

local active: { Projectile } = {}
local running = false

local function effectsFolder(): Folder
	local world = Workspace:FindFirstChild("HoonangaWorld")
	if not world then
		error("HoonangaWorld does not exist; RoadService.Start must run first", 2)
	end
	local existing = world:FindFirstChild("Effects")
	if existing then
		return existing :: Folder
	end
	local folder = Instance.new("Folder")
	folder.Name = "Effects"
	folder.Parent = world
	return folder
end

local ProjectileService = {}

-- GDD 24.3 "explosion force limits". Blast impulse is expressed as a speed
-- change and clamped, rather than as a force, so the cap means the same thing
-- for a light bike and a loaded roadtrain and cannot be defeated by standing
-- a light vehicle right on top of the detonation.
local function applyBlastImpulse(vehicle: Model, blastCentre: Vector3, falloff: number, spec)
	if spec.MaxImpulseSpeed <= 0 then
		return
	end
	local chassis = vehicle.PrimaryPart
	if not chassis then
		return
	end

	local offset = chassis.Position - blastCentre
	local direction = if offset.Magnitude > 0.05 then offset.Unit else Vector3.yAxis
	-- Biased upward so a blast throws a vehicle rather than sliding it, but
	-- still normalised so the total speed change respects the cap.
	direction = (direction + Vector3.new(0, 0.6, 0)).Unit
	chassis.AssemblyLinearVelocity += direction * (spec.MaxImpulseSpeed * falloff)
end

function ProjectileService.Detonate(
	position: Vector3,
	config: WeaponConfig.WeaponConfig,
	spec: WeaponConfig.ProjectileSpec,
	source: Model?,
	damageMultiplier: number,
	directHitVehicle: Model?
)
	if config.FirePatch then
		FireService.CreateFirePatch(position, config.FirePatch, source)
	end

	if spec.BlastRadius > 0 and (spec.BlastHullDamage > 0 or spec.MaxImpulseSpeed > 0) then
		local explosion = Instance.new("Explosion")
		-- Visual only. All force and damage is applied below so it stays
		-- server-authoritative and inside the documented caps, rather than
		-- being whatever Roblox's own blast pressure decides.
		explosion.BlastPressure = 0
		explosion.BlastRadius = spec.BlastRadius
		explosion.DestroyJointRadiusPercent = 0
		explosion.Position = position
		explosion.Parent = Workspace
	end

	for _, vehicle in CollectionService:GetTagged("HoonangaVehicle") do
		if not vehicle:IsA("Model") or not vehicle.PrimaryPart then
			continue
		end
		if vehicle:GetAttribute("Destroyed") then
			continue
		end
		if not CombatService.IsHostile(source, vehicle) then
			continue
		end

		local distance = (vehicle.PrimaryPart.Position - position).Magnitude
		if distance > spec.BlastRadius then
			continue
		end

		-- Linear falloff to zero at the radius edge, so "how close did it
		-- land" is legible to the player from the damage they took.
		local falloff = 1 - distance / spec.BlastRadius
		CombatService.ApplyDamage(
			vehicle,
			"Hull",
			spec.BlastHullDamage * falloff * damageMultiplier,
			source
		)
		CombatService.ApplyDamage(
			vehicle,
			"Personnel",
			spec.BlastPersonnelDamage * falloff * damageMultiplier,
			source
		)
		FireService.AddHeat(vehicle, spec.BlastHeat * falloff, source)
		applyBlastImpulse(vehicle, position, falloff, spec)
	end

	-- The direct hit is on top of the blast: hitting a vehicle square with a
	-- rocket should beat landing one next to it.
	if directHitVehicle and CombatService.IsHostile(source, directHitVehicle) then
		CombatService.ApplyDamage(
			directHitVehicle,
			"Hull",
			config.HullDamage * damageMultiplier,
			source
		)
		CombatService.ApplyDamage(
			directHitVehicle,
			"Personnel",
			config.PersonnelDamage * damageMultiplier,
			source
		)
	end
end

local function destroyProjectile(index: number)
	local projectile = active[index]
	projectile.Part:Destroy()
	table.remove(active, index)
end

local function stepProjectile(projectile: Projectile, deltaTime: number): boolean
	projectile.Velocity -= Vector3.new(0, projectile.Spec.Gravity * deltaTime, 0)
	local travel = projectile.Velocity * deltaTime
	local distance = travel.Magnitude
	if distance <= 0 then
		return true
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {
		projectile.Part,
		(projectile.Source :: any) or projectile.Part,
	}
	params.IgnoreWater = false

	local result = Workspace:Raycast(projectile.Position, travel, params)
	if result then
		local hitVehicle = CombatService.GetVehicleFromPart(result.Instance)
		ProjectileService.Detonate(
			result.Position,
			projectile.Config,
			projectile.Spec,
			projectile.Source,
			projectile.DamageMultiplier,
			hitVehicle
		)
		return false
	end

	projectile.Position += travel
	projectile.Part.CFrame =
		CFrame.lookAt(projectile.Position, projectile.Position + projectile.Velocity)
	return Workspace:GetServerTimeNow() < projectile.ExpiresAt
end

function ProjectileService.Launch(
	source: Model?,
	config: WeaponConfig.WeaponConfig,
	origin: Vector3,
	direction: Vector3,
	damageMultiplier: number
): Part
	local spec = config.Projectile
	if not spec then
		error(string.format("Weapon %s has no projectile spec", config.Id), 2)
	end

	local isThrown = config.Kind == "Thrown"
	local part = Instance.new("Part")
	part.Name = config.Id .. "Projectile"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = if isThrown then Vector3.new(0.8, 0.8, 0.8) else Vector3.new(0.5, 0.5, 2.6)
	part.Color = if isThrown then Color3.fromRGB(214, 168, 74) else Color3.fromRGB(226, 226, 216)
	part.Material = Enum.Material.Neon
	part.CFrame = CFrame.lookAt(origin, origin + direction)
	part.Parent = effectsFolder()

	if isThrown then
		local flame = Instance.new("Fire")
		flame.Size = 2.5
		flame.Heat = 6
		flame.Parent = part
	else
		local trail = Instance.new("Fire")
		trail.Size = 3.5
		trail.Heat = 3
		trail.Color = Color3.fromRGB(255, 190, 120)
		trail.Parent = part
	end

	table.insert(active, {
		Part = part,
		Config = config,
		Spec = spec,
		Position = origin,
		Velocity = direction.Unit * spec.Speed,
		Source = source,
		DamageMultiplier = damageMultiplier,
		ExpiresAt = Workspace:GetServerTimeNow() + spec.Lifetime,
	})

	return part
end

-- Deterministic stepping for tests: advances every live projectile by an
-- exact amount of time rather than waiting on Heartbeat.
function ProjectileService.StepForTest(deltaTime: number)
	for index = #active, 1, -1 do
		if not stepProjectile(active[index], deltaTime) then
			destroyProjectile(index)
		end
	end
end

function ProjectileService.ActiveCount(): number
	return #active
end

function ProjectileService.Start()
	if running then
		return
	end
	running = true

	RunService.Heartbeat:Connect(function(deltaTime)
		for index = #active, 1, -1 do
			if not stepProjectile(active[index], deltaTime) then
				destroyProjectile(index)
			end
		end
	end)
end

return ProjectileService
