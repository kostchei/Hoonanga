--!strict

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local VehiclePhysics = require(ReplicatedStorage.Shared.VehiclePhysics)
local RemoteService = require(script.Parent.RemoteService)
local VehicleService = require(script.Parent.VehicleService)

local lastShotAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

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

local function isPlayerDriving(player: Player, vehicle: Model): boolean
	local seat = vehicle:FindFirstChild("DriverSeat")
	if not seat or not seat:IsA("VehicleSeat") or not seat.Occupant then
		return false
	end
	return Players:GetPlayerFromCharacter(seat.Occupant.Parent) == player
end

local function destroyVehicle(vehicle: Model)
	if vehicle:GetAttribute("Destroyed") then
		return
	end

	vehicle:SetAttribute("Destroyed", true)
	vehicle:SetAttribute("Hull", 0)
	VehiclePhysics.Reset(vehicle)

	local seat = vehicle:FindFirstChild("DriverSeat")
	if seat and seat:IsA("VehicleSeat") and seat.Occupant then
		seat.Occupant.Health = 0
	end

	local chassis = vehicle.PrimaryPart
	if chassis then
		local explosion = Instance.new("Explosion")
		explosion.BlastPressure = 0
		explosion.BlastRadius = 8
		explosion.DestroyJointRadiusPercent = 0
		explosion.Position = chassis.Position
		explosion.Parent = Workspace

		chassis.AssemblyLinearVelocity += Vector3.new(0, 24, 0)
		chassis.AssemblyAngularVelocity += Vector3.new(1.8, 0.8, -1.2)
	end

	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Color = descendant.Color:Lerp(Color3.fromRGB(35, 30, 27), 0.55)
		end
	end

	Debris:AddItem(vehicle, 8)
end

local function applyHullDamage(vehicle: Model, damage: number)
	if vehicle:GetAttribute("Destroyed") then
		return
	end

	local hull = vehicle:GetAttribute("Hull")
	if typeof(hull) ~= "number" then
		return
	end

	hull = math.max(0, hull - damage)
	vehicle:SetAttribute("Hull", hull)
	if hull <= 0 then
		destroyVehicle(vehicle)
	end
end

local CombatService = {}

function CombatService.TryFire(vehicle: Model, desiredDirection: Vector3): boolean
	if vehicle:GetAttribute("Destroyed") or desiredDirection.Magnitude < 0.9 then
		return false
	end

	local chassis = vehicle.PrimaryPart
	if not chassis then
		return false
	end

	local config = WeaponConfig.MachineGun
	local now = Workspace:GetServerTimeNow()
	local lastShot = lastShotAt[vehicle] or 0
	if now - lastShot < config.FireInterval * 0.9 then
		return false
	end

	local ammo = vehicle:GetAttribute("Ammo")
	if typeof(ammo) ~= "number" or ammo <= 0 or vehicle:GetAttribute("Reloading") then
		return false
	end

	local direction = desiredDirection.Unit
	if direction:Dot(chassis.CFrame.LookVector) < math.cos(math.rad(96)) then
		return false
	end

	local muzzle = chassis:FindFirstChild("MuzzleAttachment")
	if not muzzle or not muzzle:IsA("Attachment") then
		return false
	end

	lastShotAt[vehicle] = now
	vehicle:SetAttribute("Ammo", ammo - 1)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { vehicle }
	params.IgnoreWater = false

	local origin = muzzle.WorldPosition
	local result = Workspace:Raycast(origin, direction * config.Range, params)
	local endPosition = origin + direction * config.Range
	if result then
		endPosition = result.Position
		local targetVehicle = getVehicleFromPart(result.Instance)
		if targetVehicle and targetVehicle ~= vehicle then
			local sameTeam = targetVehicle:GetAttribute("Team") == vehicle:GetAttribute("Team")
			if not sameTeam then
				applyHullDamage(targetVehicle, config.Damage)
			end
		end
	end

	RemoteService.Get("WeaponFired"):FireAllClients(origin, endPosition)
	return true
end

function CombatService.Reload(vehicle: Model)
	if vehicle:GetAttribute("Destroyed") or vehicle:GetAttribute("Reloading") then
		return
	end

	local config = WeaponConfig.MachineGun
	local ammo = vehicle:GetAttribute("Ammo")
	local reserve = vehicle:GetAttribute("ReserveAmmo")
	if typeof(ammo) ~= "number" or typeof(reserve) ~= "number" then
		return
	end
	if ammo >= config.MagazineSize or reserve <= 0 then
		return
	end

	vehicle:SetAttribute("Reloading", true)
	task.delay(config.ReloadTime, function()
		if not vehicle.Parent or vehicle:GetAttribute("Destroyed") then
			return
		end

		local currentAmmo = vehicle:GetAttribute("Ammo")
		local currentReserve = vehicle:GetAttribute("ReserveAmmo")
		if typeof(currentAmmo) ~= "number" or typeof(currentReserve) ~= "number" then
			return
		end

		local required = config.MagazineSize - currentAmmo
		local loaded = math.min(required, currentReserve)
		vehicle:SetAttribute("Ammo", currentAmmo + loaded)
		vehicle:SetAttribute("ReserveAmmo", currentReserve - loaded)
		vehicle:SetAttribute("Reloading", false)
	end)
end

function CombatService.Start()
	RemoteService.Get("FireWeapon").OnServerEvent:Connect(function(player, direction)
		if typeof(direction) ~= "Vector3" then
			return
		end

		local vehicle = VehicleService.GetPlayerVehicle(player)
		if vehicle and isPlayerDriving(player, vehicle) then
			CombatService.TryFire(vehicle, direction)
		end
	end)

	RemoteService.Get("ReloadWeapon").OnServerEvent:Connect(function(player)
		local vehicle = VehicleService.GetPlayerVehicle(player)
		if vehicle and isPlayerDriving(player, vehicle) then
			CombatService.Reload(vehicle)
		end
	end)
end

return CombatService
