--!strict

local PerformancePolicy = {}

function PerformancePolicy.NextState(
	isLowMode: boolean,
	recoverySamples: number,
	fps: number,
	enterLowFps: number,
	exitLowFps: number,
	requiredRecoverySamples: number
): (boolean, number)
	if not isLowMode then
		return fps < enterLowFps, 0
	end
	if fps >= exitLowFps then
		local nextSamples = recoverySamples + 1
		if nextSamples >= requiredRecoverySamples then
			return false, 0
		end
		return true, nextSamples
	end
	return true, 0
end

return PerformancePolicy
