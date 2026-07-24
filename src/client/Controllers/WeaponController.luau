--!strict

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)

local localPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("HoonangaRemotes")
local fireRemote = remotes:WaitForChild("FireWeapon") :: RemoteEvent
local reloadRemote = remotes:WaitForChild("ReloadWeapon") :: RemoteEvent
local weaponFiredRemote = remotes:WaitForChild("WeaponFired") :: RemoteEvent

local firing = false
local lastLocalShot = 0

local function currentVehicle(): Model?
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	if not seat or not seat:IsA("VehicleSeat") then
		return nil
	end
	local vehicle = seat:FindFirstAncestorOfClass("Model")
	if vehicle and vehicle:GetAttribute("VehicleType") then
		return vehicle
	end
	return nil
end

local function drawTracer(origin: Vector3, endPosition: Vector3)
	local distance = (endPosition - origin).Magnitude
	if distance <= 0.05 then
		return
	end

	local tracer = Instance.new("Part")
	tracer.Name = "LocalTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 181, 74)
	tracer.Size = Vector3.new(0.08, 0.08, distance)
	tracer.CFrame = CFrame.lookAt((origin + endPosition) / 2, endPosition)
	tracer.Parent = Workspace
	Debris:AddItem(tracer, 0.055)
end

local WeaponController = {}

function WeaponController.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = true
		elseif input.KeyCode == Enum.KeyCode.R and currentVehicle() then
			reloadRemote:FireServer()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = false
		end
	end)

	weaponFiredRemote.OnClientEvent:Connect(function(origin, endPosition)
		if typeof(origin) == "Vector3" and typeof(endPosition) == "Vector3" then
			drawTracer(origin, endPosition)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not firing or not currentVehicle() then
			return
		end

		local now = os.clock()
		if now - lastLocalShot < WeaponConfig.MachineGun.FireInterval then
			return
		end
		lastLocalShot = now
		fireRemote:FireServer(Workspace.CurrentCamera.CFrame.LookVector)
	end)
end

return WeaponController
