--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DustConfig = require(ReplicatedStorage.Shared.Config.DustConfig)
local DustPolicy = require(ReplicatedStorage.Shared.DustPolicy)
local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)

local localPlayer = Players.LocalPlayer
local emittersByVehicle: { [Model]: { ParticleEmitter } } = setmetatable({}, { __mode = "k" }) :: any

local function makeEmitter(attachment: Attachment): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "DrySurfaceRearDust"
	emitter.Texture = DustConfig.Texture
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.55, 0.9)
	emitter.Speed = NumberRange.new(4, 9)
	emitter.Drag = 2.5
	emitter.Acceleration = Vector3.new(0, 5, 0)
	emitter.SpreadAngle = Vector2.new(22, 14)
	emitter.EmissionDirection = Enum.NormalId.Back
	emitter.Rotation = NumberRange.new(-180, 180)
	emitter.RotSpeed = NumberRange.new(-35, 35)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.35, 1.25),
		NumberSequenceKeypoint.new(1, 2.4),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.28),
		NumberSequenceKeypoint.new(0.55, 0.62),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightInfluence = 0.65
	emitter.VelocityInheritance = 0.12
	emitter.Parent = attachment
	return emitter
end

local function prepareVehicle(instance: Instance)
	if not instance:IsA("Model") or emittersByVehicle[instance] then
		return
	end
	local chassis = instance.PrimaryPart
	local vehicleType = instance:GetAttribute("VehicleType")
	local config = if typeof(vehicleType) == "string" then VehicleConfig[vehicleType] else nil
	if not chassis or not config then
		return
	end

	local emitters: { ParticleEmitter } = {}
	for _, contactName in DustPolicy.RearContactNames(config.WheelContacts) do
		local attachment = chassis:FindFirstChild("SuspensionPoint" .. contactName)
		if attachment and attachment:IsA("Attachment") then
			table.insert(emitters, makeEmitter(attachment))
		end
	end
	emittersByVehicle[instance] = emitters
end

local function disable(emitters: { ParticleEmitter })
	for _, emitter in emitters do
		emitter.Enabled = false
		emitter.Rate = 0
	end
end

local function updateVehicle(vehicle: Model, emitters: { ParticleEmitter })
	if not vehicle.Parent or not vehicle.PrimaryPart then
		disable(emitters)
		return
	end

	local ownedLocally = vehicle:GetAttribute("ControlledByUserId") == localPlayer.UserId
	local localSurface = vehicle:GetAttribute("SurfaceProfile")
	local serverSurface = vehicle:GetAttribute("ServerSurfaceProfile")
	local surface = if ownedLocally and typeof(localSurface) == "string"
		then localSurface
		elseif typeof(serverSurface) == "string" then serverSurface
		elseif typeof(localSurface) == "string" then localSurface
		else "Air"
	local localGrounded = vehicle:GetAttribute("GroundedWheels")
	local serverGrounded = vehicle:GetAttribute("ServerGroundedWheels")
	local groundedWheels = if ownedLocally and typeof(localGrounded) == "number"
		then localGrounded
		elseif typeof(serverGrounded) == "number" then serverGrounded
		elseif typeof(localGrounded) == "number" then localGrounded
		else 0
	local localSpeed = vehicle:GetAttribute("ForwardSpeed")
	local serverSpeed = vehicle:GetAttribute("ServerForwardSpeed")
	local speed = if ownedLocally and typeof(localSpeed) == "number"
		then localSpeed
		elseif typeof(serverSpeed) == "number" then serverSpeed
		elseif typeof(localSpeed) == "number" then localSpeed
		else vehicle.PrimaryPart.AssemblyLinearVelocity.Magnitude
	local shouldEmit = DustPolicy.ShouldEmit(
		surface,
		speed,
		groundedWheels,
		vehicle:GetAttribute("Destroyed") == true
	)
	if not shouldEmit then
		disable(emitters)
		return
	end

	local color = DustConfig.SurfaceColors[surface] or DustConfig.SurfaceColors.WornDirt
	local rate =
		DustPolicy.EmissionRate(speed, localPlayer:GetAttribute("LowPerformanceMode") == true)
	for _, emitter in emitters do
		emitter.Color = ColorSequence.new(color)
		emitter.Rate = rate
		emitter.Enabled = rate > 0
	end
end

local DustController = {}

function DustController.Start()
	for _, vehicle in CollectionService:GetTagged("HoonangaVehicle") do
		prepareVehicle(vehicle)
	end
	CollectionService:GetInstanceAddedSignal("HoonangaVehicle"):Connect(function(instance)
		task.defer(prepareVehicle, instance)
	end)
	CollectionService:GetInstanceRemovedSignal("HoonangaVehicle"):Connect(function(instance)
		if instance:IsA("Model") then
			local emitters = emittersByVehicle[instance]
			if emitters then
				disable(emitters)
				emittersByVehicle[instance] = nil
			end
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < 1 / DustConfig.UpdateHz then
			return
		end
		elapsed = 0
		for vehicle, emitters in emittersByVehicle do
			updateVehicle(vehicle, emitters)
		end
	end)
end

return DustController
