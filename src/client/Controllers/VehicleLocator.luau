--!strict

local Workspace = game:GetService("Workspace")

local VehicleLocator = {}

local function findVehicle(player: Player, includeDestroyed: boolean): Model?
	local world = Workspace:FindFirstChild("HoonangaWorld")
	local vehicles = if world then world:FindFirstChild("Vehicles") else nil
	if not vehicles then
		return nil
	end

	for _, candidate in vehicles:GetChildren() do
		if
			candidate:IsA("Model")
			and candidate:GetAttribute("OwnerUserId") == player.UserId
			and (includeDestroyed or candidate:GetAttribute("Destroyed") ~= true)
		then
			return candidate
		end
	end

	return nil
end

function VehicleLocator.ForPlayer(player: Player): Model?
	return findVehicle(player, false)
end

-- Used by RunResultController, which needs to observe the moment a vehicle
-- transitions to Destroyed rather than have it disappear immediately.
function VehicleLocator.ForPlayerIncludingDestroyed(player: Player): Model?
	return findVehicle(player, true)
end

return VehicleLocator
