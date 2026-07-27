--!strict

local ControllerInput = {}

function ControllerInput.ApplyDeadzone(value: number, deadzone: number): number
	local magnitude = math.abs(value)
	if magnitude <= deadzone then
		return 0
	end
	local scaled = (magnitude - deadzone) / (1 - deadzone)
	return math.sign(value) * math.clamp(scaled, 0, 1)
end

function ControllerInput.ComposeDriveInput(
	steer: number,
	throttleTrigger: number,
	brakeTrigger: number,
	stickDeadzone: number,
	triggerDeadzone: number
): (number, number)
	local resolvedSteer = ControllerInput.ApplyDeadzone(steer, stickDeadzone)
	local throttle = ControllerInput.ApplyDeadzone(throttleTrigger, triggerDeadzone)
	local brake = ControllerInput.ApplyDeadzone(brakeTrigger, triggerDeadzone)
	return math.clamp(throttle - brake, -1, 1), resolvedSteer
end

function ControllerInput.WrapSlot(current: number, direction: number, count: number): number
	if count <= 0 then
		return 0
	end
	return ((current - 1 + direction) % count) + 1
end

return ControllerInput
