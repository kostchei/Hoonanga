--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local VehicleLocator = require(script.Parent.VehicleLocator)

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local MAX_YAW = math.rad(82)
local MIN_PITCH = math.rad(-32)
local MAX_PITCH = math.rad(24)
local MOUSE_SENSITIVITY = 0.0024
local CAMERA_SMOOTHING = 16

local activeAttachment: Attachment? = nil
local yaw = 0
local pitch = 0
local currentCFrame: CFrame? = nil

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
	currentCFrame = nil

	if activeAttachment then
		camera.CameraType = Enum.CameraType.Scriptable
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else
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
		function(deltaTime)
			local resolvedAttachment = findCameraAttachment()
			if resolvedAttachment ~= activeAttachment then
				refreshCameraMode()
			end

			local attachment = activeAttachment
			if not attachment or not attachment.Parent then
				return
			end

			local target = attachment.WorldCFrame
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(pitch, 0, 0)
			local alpha = 1 - math.exp(-CAMERA_SMOOTHING * deltaTime)
			currentCFrame = if currentCFrame then currentCFrame:Lerp(target, alpha) else target
			camera.CFrame = currentCFrame
		end
	)
end

return CameraController
