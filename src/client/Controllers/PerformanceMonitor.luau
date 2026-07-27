--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PerformanceConfig = require(ReplicatedStorage.Shared.Config.PerformanceConfig)
local PerformancePolicy = require(ReplicatedStorage.Shared.PerformancePolicy)

local localPlayer = Players.LocalPlayer
local currentFps = 60
local isLowPerformance = false
local recoverySamples = 0

local PerformanceMonitor = {}

function PerformanceMonitor.Start()
	local frameCount = 0
	local elapsedTime = 0
	localPlayer:SetAttribute("LowPerformanceMode", false)
	localPlayer:SetAttribute("PerformanceFPS", currentFps)

	RunService.RenderStepped:Connect(function(dt)
		frameCount += 1
		elapsedTime += dt

		if elapsedTime >= PerformanceConfig.SampleSeconds then
			currentFps = frameCount / elapsedTime
			isLowPerformance, recoverySamples = PerformancePolicy.NextState(
				isLowPerformance,
				recoverySamples,
				currentFps,
				PerformanceConfig.EnterLowFps,
				PerformanceConfig.ExitLowFps,
				PerformanceConfig.RecoverySamples
			)
			localPlayer:SetAttribute("LowPerformanceMode", isLowPerformance)
			localPlayer:SetAttribute("PerformanceFPS", math.floor(currentFps + 0.5))
			frameCount = 0
			elapsedTime = 0
		end
	end)
end

function PerformanceMonitor.GetFPS(): number
	return currentFps
end

function PerformanceMonitor.IsLowPerformanceMode(): boolean
	return isLowPerformance
end

return PerformanceMonitor
