--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SurfaceProfiles = require(ReplicatedStorage.Shared.Config.SurfaceProfiles)
local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)

local UPDATE_INTERVAL = 0.25

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

local function updateVehicle(vehicle: Model, deltaTime: number)
	if vehicle:GetAttribute("Destroyed") or vehicle:GetAttribute("Team") ~= "Player" then
		return
	end

	local fuel = vehicle:GetAttribute("Fuel")
	if typeof(fuel) ~= "number" or fuel <= 0 then
		vehicle:SetAttribute("Fuel", 0)
		vehicle:SetAttribute("OutOfFuel", true)
		return
	end

	local vehicleType = vehicle:GetAttribute("VehicleType") or "Ute"
	local config = VehicleConfig[vehicleType]
	if not config then
		return
	end

	local seat = vehicle:FindFirstChild("DriverSeat")
	local throttle = if seat and seat:IsA("VehicleSeat") then math.abs(seat.ThrottleFloat) else 0
	local surfaceName, fuelMultiplier = sampleFuelMultiplier(vehicle)
	local consumption = (config.IdleFuelPerSecond + throttle * config.ThrottleFuelPerSecond)
		* fuelMultiplier
	fuel = math.max(0, fuel - consumption * deltaTime)

	vehicle:SetAttribute("Fuel", fuel)
	vehicle:SetAttribute("OutOfFuel", fuel <= 0)
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
