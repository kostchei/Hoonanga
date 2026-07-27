--!strict

local Players = game:GetService("Players")
local RobloxAnalyticsService = game:GetService("AnalyticsService")

export type TelemetryEvent = {
	EventName: string,
	UserId: number,
	Timestamp: number,
	Value: number,
	Data: { [string]: string | number | boolean },
}

local MAX_BUFFERED_EVENTS = 500
local MAX_EVENT_FIELDS = 16
local eventLog: { TelemetryEvent } = {}
local started = false

local function cleanEventName(eventName: string): string?
	local cleaned = string.sub(eventName, 1, 50)
	if string.match(cleaned, "^[%w_]+$") == nil then
		return nil
	end
	return cleaned
end

local function sanitizeData(data: { [string]: any }?): { [string]: string | number | boolean }
	local clean: { [string]: string | number | boolean } = {}
	if not data then
		return clean
	end
	local count = 0
	for key, value in data do
		if count >= MAX_EVENT_FIELDS then
			break
		end
		if
			typeof(key) == "string"
			and #key <= 40
			and (
				typeof(value) == "string"
				or typeof(value) == "number"
				or typeof(value) == "boolean"
			)
		then
			if typeof(value) == "string" then
				clean[key] = string.sub(value, 1, 80)
			elseif typeof(value) == "number" then
				clean[key] = if value == value
						and value ~= math.huge
						and value ~= -math.huge
					then value
					else 0
			else
				clean[key] = value
			end
			count += 1
		end
	end
	return clean
end

local AnalyticsService = {}

function AnalyticsService.Start()
	if started then
		return
	end
	started = true
	local function joined(player: Player)
		AnalyticsService.LogEvent(player, "PlayerJoined", {
			AccountAgeDays = player.AccountAge,
		})
	end
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerAdded:Connect(joined)
end

function AnalyticsService.LogEvent(player: Player, eventName: string, data: { [string]: any }?)
	local cleanName = cleanEventName(eventName)
	if not cleanName then
		return
	end
	local cleanData = sanitizeData(data)
	local value = cleanData.Value
	local numericValue = if typeof(value) == "number" then value else 1
	local event: TelemetryEvent = {
		EventName = cleanName,
		UserId = player.UserId,
		Timestamp = DateTime.now().UnixTimestampMillis,
		Value = numericValue,
		Data = cleanData,
	}
	table.insert(eventLog, event)
	if #eventLog > MAX_BUFFERED_EVENTS then
		table.remove(eventLog, 1)
	end

	pcall(function()
		RobloxAnalyticsService:LogCustomEvent(player, cleanName, numericValue)
	end)
end

function AnalyticsService.LogEconomyFlow(
	player: Player,
	isSource: boolean,
	currencyType: string,
	amount: number,
	endingBalance: number,
	transactionType: string,
	itemSku: string
)
	local safeAmount = math.max(0, amount)
	if safeAmount <= 0 then
		return
	end
	pcall(function()
		RobloxAnalyticsService:LogEconomyEvent(
			player,
			if isSource
				then Enum.AnalyticsEconomyFlowType.Source
				else Enum.AnalyticsEconomyFlowType.Sink,
			string.sub(currencyType, 1, 40),
			safeAmount,
			math.max(0, endingBalance),
			string.sub(transactionType, 1, 50),
			string.sub(itemSku, 1, 80),
			{}
		)
	end)
	AnalyticsService.LogEvent(player, if isSource then "CurrencySource" else "CurrencySink", {
		Amount = safeAmount,
		EndingBalance = endingBalance,
		Transaction = transactionType,
		ItemSku = itemSku,
	})
end

function AnalyticsService.GetLoggedEvents(): { TelemetryEvent }
	return table.clone(eventLog)
end

function AnalyticsService.SanitizeDataForTest(
	data: { [string]: any }?
): { [string]: string | number | boolean }
	return sanitizeData(data)
end

function AnalyticsService.ClearForTest()
	table.clear(eventLog)
end

return AnalyticsService
