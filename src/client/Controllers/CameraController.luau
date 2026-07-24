--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local VehicleLocator = require(script.Parent.VehicleLocator)

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local MAX_YAW = math.rad(175)
local MIN_PITCH = math.rad(-32)
local MAX_PITCH = math.rad(24)
local MOUSE_SENSITIVITY = 0.0024

local activeAttachment: Attachment? = nil
local yaw = 0
local pitch = 0
local hiddenParts: { BasePart } = {}

local function restoreHiddenParts()
	for _, part in hiddenParts do
		if part.Parent then
			part.LocalTransparencyModifier = 0
		end
	end
	table.clear(hiddenParts)
end

local function hideFirstPersonObstructions(attachment: Attachment)
	restoreHiddenParts()

	local chassis = attachment.Parent
	local vehicle = if chassis then chassis:FindFirstAncestorOfClass("Model") else nil
	if not vehicle then
		return
	end

	for _, name in { "Chassis", "Ballast", "Cabin", "DriverSeat", "Windshield" } do
		local part = vehicle:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.LocalTransparencyModifier = 1
			table.insert(hiddenParts, part)
		end
	end

	for _, descendant in vehicle:GetDescendants() do
		if
			descendant:IsA("BasePart")
			and (
				descendant.Name:find("Turret") ~= nil
				or descendant:FindFirstAncestor("CreatorStoreTurret") ~= nil
			)
		then
			descendant.LocalTransparencyModifier = 1
			table.insert(hiddenParts, descendant)
		end
	end
end

local function findCameraAttachment(): Attachment?
	local vehicle = VehicleLocator.ForPlayer(localPlayer)
	local chassis = if vehicle then vehicle.PrimaryPart else nil
	local attachment = if chassis then chassis:FindFirstChild("CameraAttachment") else nil
	if attachment and attachment:IsA("Attachment") then
		return attachment
	end
	return nil
end

local function refreshCameraMode()
	activeAttachment = findCameraAttachment()
	yaw = 0
	pitch = 0

	if activeAttachment then
		hideFirstPersonObstructions(activeAttachment)
		camera.CameraType = Enum.CameraType.Scriptable
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else
		restoreHiddenParts()
		camera.CameraType = Enum.CameraType.Custom
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end

local CameraController = {}

function CameraController.Start()
	UserInputService.InputChanged:Connect(function(input)
		if not activeAttachment or input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end

		yaw = math.clamp(yaw - input.Delta.X * MOUSE_SENSITIVITY, -MAX_YAW, MAX_YAW)
		pitch = math.clamp(pitch - input.Delta.Y * MOUSE_SENSITIVITY, MIN_PITCH, MAX_PITCH)
	end)

	refreshCameraMode()

	RunService:BindToRenderStep(
		"HoonangaVehicleCamera",
		Enum.RenderPriority.Camera.Value + 1,
		function()
			local resolvedAttachment = findCameraAttachment()
			if resolvedAttachment ~= activeAttachment then
				refreshCameraMode()
			end

			local attachment = activeAttachment
			if not attachment or not attachment.Parent then
				return
			end

			local chassis = attachment.Parent
			if not chassis:IsA("BasePart") then
				return
			end

			-- Use the exact replicated chassis frame for both the cab and camera.
			-- Smoothing or predicting this transform makes the viewpoint drift
			-- relative to the visible vehicle whenever it accelerates.
			camera.CFrame = chassis.CFrame
				* attachment.CFrame
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(pitch, 0, 0)
		end
	)
end

return CameraController
