--!strict

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local bound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function getVehicleFromPart(part: Instance): Model?
	local current: Instance? = part
	while current and current ~= Workspace do
		if current:IsA("Model") and CollectionService:HasTag(current, "HoonangaVehicle") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function bindFuelPickup(instance: Instance)
	if bound[instance] or not instance:IsA("BasePart") then
		return
	end
	bound[instance] = true

	instance.Touched:Connect(function(hit)
		if instance:GetAttribute("Collected") then
			return
		end

		local vehicle = getVehicleFromPart(hit)
		if not vehicle or vehicle:GetAttribute("Team") ~= "Player" then
			return
		end

		local fuel = vehicle:GetAttribute("Fuel")
		local maxFuel = vehicle:GetAttribute("MaxFuel")
		local amount = instance:GetAttribute("FuelAmount")
		if
			typeof(fuel) ~= "number"
			or typeof(maxFuel) ~= "number"
			or typeof(amount) ~= "number"
		then
			return
		end

		instance:SetAttribute("Collected", true)
		vehicle:SetAttribute("Fuel", math.min(maxFuel, fuel + amount))
		vehicle:SetAttribute("OutOfFuel", false)
		instance:Destroy()
	end)
end

local PickupService = {}

function PickupService.Start()
	for _, pickup in CollectionService:GetTagged("FuelPickup") do
		bindFuelPickup(pickup)
	end
	CollectionService:GetInstanceAddedSignal("FuelPickup"):Connect(bindFuelPickup)
end

return PickupService
