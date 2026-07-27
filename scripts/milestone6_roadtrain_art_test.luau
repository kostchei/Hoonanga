--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local VehicleBuilder = require(ServerScriptService.Server.Services.VehicleBuilder)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[M6_ROADTRAIN_ART] " .. message, 2)
	end
end

VehicleBuilder.SetAssetLoadingEnabledForTests(false)
local folder = Instance.new("Folder")
folder.Name = "RoadtrainArtTest"
folder.Parent = Workspace

local roadtrain = VehicleBuilder.CreateRoadtrain(
	folder,
	"ReferenceRoadtrain",
	CFrame.new(0, 4, 0),
	Color3.fromRGB(126, 48, 40)
)
expect(
	roadtrain:GetAttribute("RoadtrainArtStyle") == "ArmoredEightWheelRig",
	"roadtrain art style was not installed"
)
expect(roadtrain:GetAttribute("RoadtrainTextureReady") == true, "texture hooks are absent")

for _, name in
	{
		"CabinArmor",
		"ArmoredCargoBody",
		"FrontArmorPanel",
		"RearArmorDoor",
		"CargoRoof",
		"RoofHatchFront",
		"RoofHatchRear",
		"SidePipeLeft01",
		"SidePipeRight02",
		"ForwardGunShield",
		"ForwardGunBarrel",
		"RamBeam",
		"RamTooth03",
		"RadioAntenna",
	}
do
	expect(roadtrain:FindFirstChild(name) ~= nil, "missing reference feature " .. name)
end

local wheels = 0
local texturePanels = 0
local visualParts = 0
for _, descendant in roadtrain:GetDescendants() do
	if not descendant:IsA("BasePart") then
		continue
	end
	if descendant:GetAttribute("RoadtrainWheel") == true then
		wheels += 1
		expect(descendant.Shape == Enum.PartType.Cylinder, descendant.Name .. " is not cylindrical")
		expect(descendant.Material == Enum.Material.Rubber, descendant.Name .. " is not rubber")
	end
	if descendant:GetAttribute("RoadtrainTexturePanel") == true then
		texturePanels += 1
	end
	if descendant:GetAttribute("RoadtrainVisual") == true then
		visualParts += 1
		expect(not descendant.CanCollide, descendant.Name .. " collides with the world")
		expect(not descendant.CanTouch, descendant.Name .. " duplicates touch events")
		expect(descendant.Massless, descendant.Name .. " changes vehicle mass")
		expect(
			descendant:FindFirstChild("ChassisWeld") ~= nil,
			descendant.Name .. " is not welded to the chassis"
		)
	end
end
expect(wheels == 8, string.format("expected eight visible wheels, found %d", wheels))
expect(texturePanels >= 4, "front/rear/side/top texture targets are incomplete")
expect(visualParts >= 60, "roadtrain is still too close to the old graybox")

local chassis = roadtrain.PrimaryPart
expect(chassis ~= nil, "roadtrain has no chassis")
local roofHatch = roadtrain:FindFirstChild("RoofHatchRear") :: BasePart
local localHatch = chassis.CFrame:PointToObjectSpace(roofHatch.Position)
expect(localHatch.Y > 7, "roof equipment is embedded in the cargo body")
local turret = roadtrain:FindFirstChild("TurretPedestal")
expect(turret ~= nil and turret:IsA("BasePart"), "roadtrain has no roof turret")
local localTurret = chassis.CFrame:PointToObjectSpace((turret :: BasePart).Position)
expect(localTurret.Y > 7, "turret remained at the old graybox height")

roadtrain:Destroy()
folder:Destroy()
print("[M6_ROADTRAIN_ART] PASS: armored eight-wheel reference roadtrain is runtime-safe")
