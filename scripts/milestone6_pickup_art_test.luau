--!strict

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local services = ServerScriptService.Server.Services
local PickupArtBuilder = require(services.PickupArtBuilder)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[M6_PICKUP_ART] " .. message, 2)
	end
end

local folder = Instance.new("Folder")
folder.Name = "PickupArtTest"
folder.Parent = Workspace

local fuel = PickupArtBuilder.Create(folder, CFrame.new(-4, 4, 0), "Fuel", 90)
local ammo = PickupArtBuilder.Create(folder, CFrame.new(4, 4, 0), "Bullets", 160)

expect(fuel:GetAttribute("PickupArtStyle") == "FuelJerrycan", "fuel is not a jerrycan")
expect(fuel:FindFirstChild("CanHandleGrip") ~= nil, "jerrycan has no handle")
expect(fuel:FindFirstChild("SpoutCollar") ~= nil, "jerrycan has no spout collar")
expect(fuel:FindFirstChild("SpoutTube") ~= nil, "jerrycan has no pouring spout")
expect(fuel:FindFirstChild("BreatherCap") ~= nil, "jerrycan has no cap")

expect(ammo:GetAttribute("PickupArtStyle") == "OpenAmmoCrate", "ammo is not an open crate")
expect(ammo:FindFirstChild("OpenLid") ~= nil, "ammo crate has no open lid")
expect(ammo:FindFirstChild("CarryGrip") ~= nil, "ammo crate has no handle")
expect(ammo:FindFirstChild("AmmoRound01") ~= nil, "ammo crate has no visible contents")
expect(ammo:FindFirstChild("HangingRound05") ~= nil, "ammo belt does not hang outside")

for _, pickup in { fuel, ammo } do
	expect(pickup:IsA("BasePart"), "collector root is not a BasePart")
	expect(pickup.Transparency == 1, "collector root is visibly blocking the art")
	expect(pickup.CanTouch, "collector root cannot register collection")
	expect(not pickup.CanCollide, "collector root collides with vehicles")
	expect(CollectionService:HasTag(pickup, "HoonangaPickup"), "collector root is untagged")
	expect(pickup:GetAttribute("PickupTextureReady") == true, "pickup has no texture hook")

	for _, descendant in pickup:GetDescendants() do
		if descendant:IsA("BasePart") then
			expect(descendant.Anchored, descendant.Name .. " is not anchored")
			expect(not descendant.CanCollide, descendant.Name .. " collides with vehicles")
			expect(not descendant.CanTouch, descendant.Name .. " duplicates the touch collector")
		end
	end
end

folder:Destroy()
print("[M6_PICKUP_ART] PASS: open ammo crate and handled fuel jerrycan are collectible")
