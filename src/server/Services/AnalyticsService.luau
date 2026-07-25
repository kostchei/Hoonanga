--!strict

export type TelemetryEvent = {
	EventName: string,
	UserId: number,
	Timestamp: number,
	Data: { [string]: any },
}

local eventLog: { TelemetryEvent } = {}

local AnalyticsService = {}

function AnalyticsService.Start()
	-- AnalyticsService ready
end

function AnalyticsService.LogEvent(player: Player, eventName: string, data: { [string]: any }?)
	local event: TelemetryEvent = {
		EventName = eventName,
		UserId = player.UserId,
		Timestamp = DateTime.now().UnixTimestampMillis,
		Data = data or {},
	}
	table.insert(eventLog, event)
	if #eventLog > 500 then
		table.remove(eventLog, 1)
	end
end

function AnalyticsService.GetLoggedEvents(): { TelemetryEvent }
	return eventLog
end

return AnalyticsService
