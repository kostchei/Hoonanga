--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ConvoyConfig = require(ReplicatedStorage.Shared.Config.ConvoyConfig)
local VehicleBuilder = require(script.Parent.VehicleBuilder)

export type ConvoyRecord = {
	Id: string,
	OwnerUserId: number,
	Faction: string,
	ClassId: string,
	Model: Folder,
	Members: { Model },
	ControlledVehicle: Model?,
	Fuel: number,
	MaxFuel: number,
	State: string,
	Ended: boolean,
	RunDistance: number,
}

local recordsById: { [string]: ConvoyRecord } = {}
local recordsByVehicle: { [Model]: ConvoyRecord } = setmetatable({}, { __mode = "k" }) :: any
local playerConvoys: { [number]: ConvoyRecord } = {}
local sequence = 0

local memberLostEvent = Instance.new("BindableEvent")
local controlChangedEvent = Instance.new("BindableEvent")
local convoyEndedEvent = Instance.new("BindableEvent")

local function getConvoysFolder(): Folder
	local world = Workspace:WaitForChild("HoonangaWorld")
	local existing = world:FindFirstChild("Convoys")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Convoys"
	folder.Parent = world
	return folder
end

local function mirrorFuel(record: ConvoyRecord)
	record.Model:SetAttribute("Fuel", record.Fuel)
	record.Model:SetAttribute("MaxFuel", record.MaxFuel)
	local outOfFuel = record.Fuel <= 0
	record.Model:SetAttribute("OutOfFuel", outOfFuel)
	for _, vehicle in record.Members do
		if vehicle.Parent then
			vehicle:SetAttribute("Fuel", record.Fuel)
			vehicle:SetAttribute("MaxFuel", record.MaxFuel)
			vehicle:SetAttribute("OutOfFuel", outOfFuel)
		end
	end
end

local function operational(vehicle: Model): boolean
	return vehicle.Parent ~= nil
		and vehicle:GetAttribute("Operational") == true
		and vehicle:GetAttribute("Destroyed") ~= true
		and vehicle:GetAttribute("OperatorAlive") ~= false
end

local function makeId(): string
	sequence += 1
	return string.format(
		"convoy-%04d-%s",
		sequence,
		string.sub(HttpService:GenerateGUID(false), 1, 8)
	)
end

local function setControlled(record: ConvoyRecord, vehicle: Model?)
	local previous = record.ControlledVehicle
	if previous == vehicle then
		return
	end
	if previous then
		previous:SetAttribute("ControlledByUserId", nil)
		previous:SetAttribute("ServerThrottle", 0)
		previous:SetAttribute("ServerSteer", 0)
		previous:SetAttribute("ServerHandbrake", false)
	end
	record.ControlledVehicle = vehicle
	record.Model:SetAttribute("ControlledVehicleName", if vehicle then vehicle.Name else "")
	if vehicle and record.OwnerUserId > 0 then
		vehicle:SetAttribute("ControlledByUserId", record.OwnerUserId)
	end
	controlChangedEvent:Fire(record, previous, vehicle)
end

local function bestSurvivor(record: ConvoyRecord, previous: Model?): Model?
	local best: Model? = nil
	local bestScore = -math.huge
	local previousPosition = if previous and previous.PrimaryPart
		then previous.PrimaryPart.Position
		else nil
	for index, vehicle in record.Members do
		if not operational(vehicle) then
			continue
		end
		local hull = vehicle:GetAttribute("Hull")
		local maxHull = vehicle:GetAttribute("MaxHull")
		local healthRatio = if typeof(hull) == "number"
				and typeof(maxHull) == "number"
				and maxHull > 0
			then hull / maxHull
			else 0
		local distance = if previousPosition and vehicle.PrimaryPart
			then (vehicle.PrimaryPart.Position - previousPosition).Magnitude
			else 0
		local roadValid = if vehicle:GetAttribute("RunDistance") ~= nil then 1 else 0
		local score = roadValid * 10000 - distance * 2 + healthRatio * 100 - index
		if score > bestScore then
			bestScore = score
			best = vehicle
		end
	end
	return best
end

local function registerVehicle(record: ConvoyRecord, vehicle: Model, slotIndex: number, slot: any)
	vehicle:SetAttribute("ConvoyId", record.Id)
	vehicle:SetAttribute("ConvoyOwnerUserId", record.OwnerUserId)
	vehicle:SetAttribute("Faction", record.Faction)
	vehicle:SetAttribute("Team", record.Faction)
	vehicle:SetAttribute("OwnerUserId", record.OwnerUserId)
	vehicle:SetAttribute("FormationSlot", slotIndex)
	vehicle:SetAttribute("FormationRole", slot.Role)
	vehicle:SetAttribute("FormationLateral", slot.Lateral)
	vehicle:SetAttribute("FormationBehind", slot.Behind)
	vehicle:SetAttribute("Operational", true)
	vehicle:SetAttribute("OperatorAlive", true)
	table.insert(record.Members, vehicle)
	recordsByVehicle[vehicle] = record
end

local ConvoyService = {}

function ConvoyService.Start()
	table.clear(recordsById)
	table.clear(recordsByVehicle)
	table.clear(playerConvoys)
	sequence = 0
	getConvoysFolder()
end

function ConvoyService.Create(
	ownerUserId: number,
	faction: string,
	classId: string,
	spawnCFrame: CFrame
): ConvoyRecord
	local composition = ConvoyConfig[classId]
	assert(composition, string.format("Unknown convoy class %q", classId))
	local id = makeId()
	local model = Instance.new("Folder")
	model.Name = id
	model:SetAttribute("ConvoyId", id)
	model:SetAttribute("OwnerUserId", ownerUserId)
	model:SetAttribute("Faction", faction)
	model:SetAttribute("ClassId", classId)
	model:SetAttribute("State", "Active")
	model:SetAttribute("Ended", false)
	model:SetAttribute("RunDistance", 0)
	model.Parent = getConvoysFolder()

	local record: ConvoyRecord = {
		Id = id,
		OwnerUserId = ownerUserId,
		Faction = faction,
		ClassId = classId,
		Model = model,
		Members = {},
		ControlledVehicle = nil,
		Fuel = composition.StartingFuel,
		MaxFuel = composition.MaxFuel,
		State = "Active",
		Ended = false,
		RunDistance = 0,
	}
	recordsById[id] = record
	if ownerUserId > 0 then
		playerConvoys[ownerUserId] = record
	end

	local vehiclesFolder = Workspace:WaitForChild("HoonangaWorld"):WaitForChild("Vehicles")
	for index, slot in composition.Slots do
		local spawn = spawnCFrame * CFrame.new(slot.Lateral, 0, slot.Behind)
		local vehicle = VehicleBuilder.Create(
			composition.VehicleType,
			vehiclesFolder,
			string.format("%s_%s_%02d", faction, classId, index),
			spawn,
			if faction == "Player" then Color3.fromRGB(184, 73, 42) else Color3.fromRGB(58, 91, 122)
		)
		registerVehicle(record, vehicle, index, slot)
	end
	mirrorFuel(record)
	setControlled(record, if ownerUserId > 0 then record.Members[1] else nil)
	return record
end

function ConvoyService.CreateSingleNPC(
	faction: string,
	vehicleType: string,
	name: string,
	spawnCFrame: CFrame
): ConvoyRecord
	local id = makeId()
	local model = Instance.new("Folder")
	model.Name = id
	model:SetAttribute("ConvoyId", id)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("Faction", faction)
	model:SetAttribute("ClassId", vehicleType)
	model:SetAttribute("State", "Active")
	model:SetAttribute("Ended", false)
	model:SetAttribute("RunDistance", 0)
	model.Parent = getConvoysFolder()
	local vehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)[vehicleType]
	assert(vehicleConfig, string.format("Unknown vehicle type %q", vehicleType))
	local record: ConvoyRecord = {
		Id = id,
		OwnerUserId = 0,
		Faction = faction,
		ClassId = vehicleType,
		Model = model,
		Members = {},
		ControlledVehicle = nil,
		Fuel = vehicleConfig.FuelCapacity,
		MaxFuel = vehicleConfig.FuelCapacity,
		State = "Active",
		Ended = false,
		RunDistance = 0,
	}
	recordsById[id] = record
	local vehiclesFolder = Workspace:WaitForChild("HoonangaWorld"):WaitForChild("Vehicles")
	local vehicle = VehicleBuilder.Create(
		vehicleType,
		vehiclesFolder,
		name,
		spawnCFrame,
		Color3.fromRGB(58, 91, 122)
	)
	registerVehicle(record, vehicle, 1, { Role = "Leader", Lateral = 0, Behind = 0 })
	mirrorFuel(record)
	return record
end

function ConvoyService.GetById(id: string): ConvoyRecord?
	return recordsById[id]
end

function ConvoyService.GetByVehicle(vehicle: Model): ConvoyRecord?
	return recordsByVehicle[vehicle]
end

function ConvoyService.GetForPlayer(player: Player): ConvoyRecord?
	return playerConvoys[player.UserId]
end

function ConvoyService.GetControlledVehicle(player: Player): Model?
	local record = playerConvoys[player.UserId]
	return if record then record.ControlledVehicle else nil
end

function ConvoyService.GetAll(): { ConvoyRecord }
	local result = {}
	for _, record in recordsById do
		table.insert(result, record)
	end
	return result
end

function ConvoyService.GetOperationalMembers(record: ConvoyRecord): { Model }
	local result = {}
	for _, vehicle in record.Members do
		if operational(vehicle) then
			table.insert(result, vehicle)
		end
	end
	return result
end

function ConvoyService.IsOperational(vehicle: Model): boolean
	return operational(vehicle)
end

function ConvoyService.SetControlled(record: ConvoyRecord, vehicle: Model?)
	if vehicle then
		assert(recordsByVehicle[vehicle] == record, "controlled vehicle must belong to convoy")
		assert(operational(vehicle), "controlled vehicle must be operational")
	end
	setControlled(record, vehicle)
end

function ConvoyService.MarkMemberLost(vehicle: Model, reason: string)
	local record = recordsByVehicle[vehicle]
	if not record or vehicle:GetAttribute("Operational") == false then
		return
	end
	vehicle:SetAttribute("Operational", false)
	vehicle:SetAttribute("LossReason", reason)
	memberLostEvent:Fire(record, vehicle, reason)
	if record.ControlledVehicle == vehicle then
		setControlled(record, bestSurvivor(record, vehicle))
	end
	if #ConvoyService.GetOperationalMembers(record) == 0 then
		ConvoyService.End(record, "Eliminated")
	end
end

function ConvoyService.End(record: ConvoyRecord, reason: string)
	if record.Ended then
		return
	end
	record.Ended = true
	record.State = reason == "OutOfFuel" and "Stranded" or "Eliminated"
	record.Model:SetAttribute("Ended", true)
	record.Model:SetAttribute("State", record.State)
	record.Model:SetAttribute("EndReason", reason)
	setControlled(record, nil)
	convoyEndedEvent:Fire(record, reason)
end

function ConvoyService.SetFuel(record: ConvoyRecord, amount: number)
	record.Fuel = math.clamp(amount, 0, record.MaxFuel)
	mirrorFuel(record)
end

function ConvoyService.AddFuel(record: ConvoyRecord, amount: number): number
	local before = record.Fuel
	ConvoyService.SetFuel(record, record.Fuel + math.max(0, amount))
	if record.Fuel > 0 and not record.Ended then
		record.State = "Active"
		record.Model:SetAttribute("State", "Active")
	end
	return record.Fuel - before
end

function ConvoyService.FindMostDamaged(record: ConvoyRecord): Model?
	local target: Model? = nil
	local worstRatio = math.huge
	for index, vehicle in record.Members do
		if not operational(vehicle) then
			continue
		end
		local hull = vehicle:GetAttribute("Hull")
		local maxHull = vehicle:GetAttribute("MaxHull")
		if typeof(hull) == "number" and typeof(maxHull) == "number" and maxHull > 0 then
			local ratio = hull / maxHull + index * 0.000001
			if ratio < worstRatio then
				worstRatio = ratio
				target = vehicle
			end
		end
	end
	return target
end

function ConvoyService.SetRunDistance(record: ConvoyRecord, distance: number)
	record.RunDistance = math.max(record.RunDistance, distance)
	record.Model:SetAttribute("RunDistance", record.RunDistance)
end

function ConvoyService.Remove(record: ConvoyRecord, destroyVehicles: boolean?)
	if recordsById[record.Id] ~= record then
		return
	end
	recordsById[record.Id] = nil
	if record.OwnerUserId > 0 and playerConvoys[record.OwnerUserId] == record then
		playerConvoys[record.OwnerUserId] = nil
	end
	for _, vehicle in record.Members do
		recordsByVehicle[vehicle] = nil
		if destroyVehicles and vehicle.Parent then
			vehicle:Destroy()
		end
	end
	record.Model:Destroy()
end

function ConvoyService.MemberLostSignal(): RBXScriptSignal
	return memberLostEvent.Event
end

function ConvoyService.ControlChangedSignal(): RBXScriptSignal
	return controlChangedEvent.Event
end

function ConvoyService.ConvoyEndedSignal(): RBXScriptSignal
	return convoyEndedEvent.Event
end

return ConvoyService
