--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
local CombatService = require(script.Parent.CombatService)
local ConvoyService = require(script.Parent.ConvoyService)

local UPDATE_INTERVAL = 0.25
local STRAND_SPEED_THRESHOLD = 3
local STRAND_DELAY = 3

local strandedTimers: { [Folder]: number } = setmetatable({}, { __mode = "k" }) :: any
local standaloneTimers: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function memberConsumption(vehicle: Model): number
	local vehicleType = vehicle:GetAttribute("VehicleType") or "Ute"
	local config = VehicleConfig[vehicleType]
	if not config then
		return 0
	end
	local serverThrottle = vehicle:GetAttribute("ServerThrottle")
	local throttle = if typeof(serverThrottle) == "number" then math.abs(serverThrottle) else 0
	local surfaceFuel = vehicle:GetAttribute("SurfaceFuelMultiplier")
	local surfaceMultiplier = if typeof(surfaceFuel) == "number" then surfaceFuel else 1
	local forwardSpeed = vehicle:GetAttribute("ForwardSpeed")
	local loadMultiplier = if typeof(forwardSpeed) == "number"
		then 1 + math.clamp(math.abs(forwardSpeed) / config.MaxForwardSpeed, 0, 1) * 0.08
		else 1
	return (config.IdleFuelPerSecond + throttle * config.ThrottleFuelPerSecond)
		* config.FuelConsumptionMultiplier
		* surfaceMultiplier
		* loadMultiplier
end

local function convoyStopped(record: ConvoyService.ConvoyRecord): boolean
	for _, vehicle in ConvoyService.GetOperationalMembers(record) do
		local chassis = vehicle.PrimaryPart
		if chassis and chassis.AssemblyLinearVelocity.Magnitude > STRAND_SPEED_THRESHOLD then
			return false
		end
	end
	return true
end

local function updateConvoy(record: ConvoyService.ConvoyRecord, deltaTime: number)
	if record.Ended then
		strandedTimers[record.Model] = nil
		return
	end
	local consumption = 0
	for _, vehicle in ConvoyService.GetOperationalMembers(record) do
		consumption += memberConsumption(vehicle)
	end
	ConvoyService.SetFuel(record, record.Fuel - consumption * deltaTime)
	if record.Fuel > 0 then
		strandedTimers[record.Model] = nil
		return
	end
	if not convoyStopped(record) then
		strandedTimers[record.Model] = nil
		return
	end
	local elapsed = (strandedTimers[record.Model] or 0) + deltaTime
	strandedTimers[record.Model] = elapsed
	if elapsed >= STRAND_DELAY then
		strandedTimers[record.Model] = nil
		local member = record.Members[1]
		if member then
			CombatService.StrandVehicle(member)
		else
			ConvoyService.End(record, "OutOfFuel")
		end
	end
end

local function updateStandalone(vehicle: Model, deltaTime: number)
	if
		vehicle:GetAttribute("ConvoyId") ~= nil
		or vehicle:GetAttribute("Destroyed")
		or vehicle:GetAttribute("Team") ~= "Player"
	then
		return
	end
	local fuel = vehicle:GetAttribute("Fuel")
	if typeof(fuel) ~= "number" then
		return
	end
	fuel = math.max(0, fuel - memberConsumption(vehicle) * deltaTime)
	vehicle:SetAttribute("Fuel", fuel)
	vehicle:SetAttribute("OutOfFuel", fuel <= 0)
	if fuel > 0 then
		standaloneTimers[vehicle] = nil
		return
	end
	local chassis = vehicle.PrimaryPart
	if chassis and chassis.AssemblyLinearVelocity.Magnitude > STRAND_SPEED_THRESHOLD then
		standaloneTimers[vehicle] = nil
		return
	end
	local elapsed = (standaloneTimers[vehicle] or 0) + deltaTime
	standaloneTimers[vehicle] = elapsed
	if elapsed >= STRAND_DELAY then
		standaloneTimers[vehicle] = nil
		CombatService.StrandVehicle(vehicle)
	end
end

local FuelService = {}

function FuelService.StepForTest(deltaTime: number)
	for _, record in ConvoyService.GetAll() do
		updateConvoy(record, deltaTime)
	end
	for _, vehicle in CollectionService:GetTagged("HoonangaVehicle") do
		if vehicle:IsA("Model") then
			updateStandalone(vehicle, deltaTime)
		end
	end
end

function FuelService.Start()
	task.spawn(function()
		while true do
			FuelService.StepForTest(UPDATE_INTERVAL)
			task.wait(UPDATE_INTERVAL)
		end
	end)
end

return FuelService
