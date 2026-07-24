--!strict

local Workspace = game:GetService("Workspace")

local VehicleLocator = {}

function VehicleLocator.ForPlayer(player: Player): Model?
	local world = Workspace:FindFirstChild("HoonangaWorld")
	local vehicles = if world then world:FindFirstChild("Vehicles") else nil
	if not vehicles then
		return nil
	end

	for _, candidate in vehicles:GetChildren() do
		if
			candidate:IsA("Model")
			and candidate:GetAttribute("OwnerUserId") == player.UserId
			and candidate:GetAttribute("Destroyed") ~= true
		then
			return candidate
		end
	end

	return nil
end

return VehicleLocator
