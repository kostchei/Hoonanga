--!strict

local RunService = game:GetService("RunService")

local currentFps = 60
local isLowPerformance = false

local PerformanceMonitor = {}

function PerformanceMonitor.Start()
	local frameCount = 0
	local elapsedTime = 0

	RunService.RenderStepped:Connect(function(dt)
		frameCount += 1
		elapsedTime += dt

		if elapsedTime >= 1.0 then
			currentFps = frameCount / elapsedTime
			isLowPerformance = currentFps < 40
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
