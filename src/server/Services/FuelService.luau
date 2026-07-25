--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SurfaceProfiles = require(ReplicatedStorage.Shared.Config.SurfaceProfiles)
local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
local CombatService = require(script.Parent.CombatService)

local UPDATE_INTERVAL = 0.25
-- GDD 4.2 lists fuel loss as its own distinct way a run ends, separate from
-- elimination - without this, running dry just leaves the player coasting
-- to a stop forever with no resolution. The delay gives them a moment to
-- see the OUT OF FUEL warning and coast down rather than ending the run the
-- instant the tank reads zero while still moving at speed.
local STRAND_SPEED_THRESHOLD = 3
local STRAND_DELAY = 3

local strandedTimers: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function sampleFuelMultiplier(vehicle: Model): (string, number)
	local chassis = vehicle.PrimaryPart
	if not chassis then
		return "Air", 1
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { vehicle }
	local result = Workspace:Raycast(chassis.Position, -chassis.CFrame.UpVector * 7, params)
	if not result then
		return "Air", 1
	end

	local profileName = result.Instance:GetAttribute("SurfaceProfile")
	if typeof(profileName) ~= "string" or not SurfaceProfiles[profileName] then
		profileName = "WornDirt"
	end
	return profileName, SurfaceProfiles[profileName].FuelUse
end

local function updateStrandedTimer(vehicle: Model, outOfFuel: boolean, deltaTime: number)
	if not outOfFuel then
		strandedTimers[vehicle] = nil
		return
	end

	local chassis = vehicle.PrimaryPart
	local speed = if chassis then chassis.AssemblyLinearVelocity.Magnitude else 0
	if speed > STRAND_SPEED_THRESHOLD then
		strandedTimers[vehicle] = nil
		return
	end

	local elapsed = (strandedTimers[vehicle] or 0) + deltaTime
	strandedTimers[vehicle] = elapsed
	if elapsed >= STRAND_DELAY then
		strandedTimers[vehicle] = nil
		CombatService.StrandVehicle(vehicle)
	end
end

local function updateVehicle(vehicle: Model, deltaTime: number)
	if vehicle:GetAttribute("Destroyed") or vehicle:GetAttribute("Team") ~= "Player" then
		return
	end

	local fuel = vehicle:GetAttribute("Fuel")
	if typeof(fuel) ~= "number" or fuel <= 0 then
		vehicle:SetAttribute("Fuel", 0)
		vehicle:SetAttribute("OutOfFuel", true)
		updateStrandedTimer(vehicle, true, deltaTime)
		return
	end

	local vehicleType = vehicle:GetAttribute("VehicleType") or "Ute"
	local config = VehicleConfig[vehicleType]
	if not config then
		return
	end

	local serverThrottle = vehicle:GetAttribute("ServerThrottle")
	local throttle = if typeof(serverThrottle) == "number" then math.abs(serverThrottle) else 0
	local surfaceName, fuelMultiplier = sampleFuelMultiplier(vehicle)
	local consumption = (config.IdleFuelPerSecond + throttle * config.ThrottleFuelPerSecond)
		* fuelMultiplier
	fuel = math.max(0, fuel - consumption * deltaTime)

	local outOfFuel = fuel <= 0
	vehicle:SetAttribute("Fuel", fuel)
	vehicle:SetAttribute("OutOfFuel", outOfFuel)
	updateStrandedTimer(vehicle, outOfFuel, deltaTime)
	vehicle:SetAttribute("ServerSurfaceProfile", surfaceName)
	vehicle:SetAttribute("SurfaceFuelMultiplier", fuelMultiplier)
end

local FuelService = {}

function FuelService.Start()
	task.spawn(function()
		while true do
			for _, vehicle in CollectionService:GetTagged("HoonangaVehicle") do
				if vehicle:IsA("Model") then
					updateVehicle(vehicle, UPDATE_INTERVAL)
				end
			end
			task.wait(UPDATE_INTERVAL)
		end
	end)
end

return FuelService
