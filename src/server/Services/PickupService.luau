--!strict

-- GDD 12.1-12.3. One tag and one attribute cover every pickup type: a pickup
-- declares what it gives (PickupType) and how much (PickupAmount), and this
-- service decides whether the collector can use it. Adding a pickup type is a
-- new branch here plus a placement in RoadService, not a new tag, service or
-- Touched binding.
--
-- A pickup that cannot be used is *not* consumed - driving over a repair crate
-- at full hull leaves it standing for later, which is the difference between
-- a resource and a trap.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local CombatService = require(script.Parent.CombatService)
local ConvoyService = require(script.Parent.ConvoyService)
local WeaponService = require(script.Parent.WeaponService)

local PICKUP_TAG = "HoonangaPickup"

local bound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function requireNumber(instance: Instance, attribute: string): number
	local value = instance:GetAttribute(attribute)
	if typeof(value) ~= "number" then
		error(string.format("%s has no numeric %s attribute", instance:GetFullName(), attribute), 3)
	end
	return value
end

local function collectFuel(vehicle: Model, amount: number): boolean
	local convoy = ConvoyService.GetByVehicle(vehicle)
	if convoy then
		return ConvoyService.AddFuel(convoy, amount) > 0
	end
	local fuel = requireNumber(vehicle, "Fuel")
	local maxFuel = requireNumber(vehicle, "MaxFuel")
	if fuel >= maxFuel then
		return false
	end

	vehicle:SetAttribute("Fuel", math.min(maxFuel, fuel + amount))
	vehicle:SetAttribute("OutOfFuel", false)
	return true
end

local function collect(pickup: BasePart, vehicle: Model): boolean
	local pickupType = pickup:GetAttribute("PickupType")
	if typeof(pickupType) ~= "string" then
		error(string.format("%s has no PickupType attribute", pickup:GetFullName()))
	end
	local amount = requireNumber(pickup, "PickupAmount")

	if pickupType == "Fuel" then
		return collectFuel(vehicle, amount)
	elseif pickupType == "Repair" then
		local convoy = ConvoyService.GetByVehicle(vehicle)
		local repairTarget = if convoy then ConvoyService.FindMostDamaged(convoy) else vehicle
		return repairTarget ~= nil and CombatService.Repair(repairTarget, amount) > 0
	elseif WeaponConfig.AmmoPools[pickupType] then
		return WeaponService.AddAmmo(vehicle, pickupType, amount) > 0
	end

	error(string.format("%s has unknown PickupType %q", pickup:GetFullName(), pickupType))
end

local function bindPickup(instance: Instance)
	if bound[instance] or not instance:IsA("BasePart") then
		return
	end
	bound[instance] = true

	instance.Touched:Connect(function(hit)
		if instance:GetAttribute("Collected") then
			return
		end

		local vehicle = CombatService.GetVehicleFromPart(hit)
		-- Enemy convoys do not resupply from player-route pickups; contention
		-- between convoys is a Milestone 5 problem (GDD 24.4).
		if not vehicle or vehicle:GetAttribute("Team") ~= "Player" then
			return
		end
		if vehicle:GetAttribute("Destroyed") then
			return
		end

		if not collect(instance, vehicle) then
			return
		end

		instance:SetAttribute("Collected", true)
		instance:Destroy()
	end)
end

local PickupService = {}

function PickupService.Start()
	for _, pickup in CollectionService:GetTagged(PICKUP_TAG) do
		bindPickup(pickup)
	end
	CollectionService:GetInstanceAddedSignal(PICKUP_TAG):Connect(bindPickup)
end

-- Exposed for tests, which need to collect a pickup without arranging a real
-- physics touch between two moving bodies.
function PickupService.CollectForTest(pickup: BasePart, vehicle: Model): boolean
	return collect(pickup, vehicle)
end

return PickupService
