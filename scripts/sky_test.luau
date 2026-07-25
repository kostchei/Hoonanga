-- The world's sky and horizon.
--
-- Most of what this covers is a look, and a look is not something a script
-- can judge - that part is eyeballed in Studio. What a script *can* hold
-- onto is the structure the look depends on, and the one invariant that will
-- silently break the whole game if it regresses: the horizon scenery sits
-- directly under and around every vehicle, and if any of it were visible to
-- a raycast it would swallow suspension probes and weapon fire.

local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local function expect(condition, message)
	if not condition then
		error("[SKY] " .. message, 2)
	end
end

---------------------------------------------------------------------------
-- Lighting and atmosphere
---------------------------------------------------------------------------

-- A low sun. ClockTime 12 would put it overhead; the run is meant to read as
-- late afternoon in the red centre.
expect(
	Lighting.ClockTime >= 16 and Lighting.ClockTime <= 18,
	string.format("ClockTime %.1f is not a low afternoon sun", Lighting.ClockTime)
)
expect(Lighting.Brightness >= 2, "the sky is not bright")
-- Lighting.Technology is deliberately not asserted here: it is one of the
-- properties a normal script may not read ("lacking capability
-- RobloxScript"), so it is pinned in default.project.json and can only be
-- confirmed by opening the place.

-- The atmosphere is what turns a flat skybox into a graded one and gives the
-- ground somewhere to fade into, so its absence is the failure mode worth
-- catching.
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
expect(atmosphere ~= nil, "Lighting has no Atmosphere, so the sky has no horizon gradient")
expect(
	atmosphere.Density > 0.1,
	string.format("atmosphere density %.2f is too thin to produce a horizon", atmosphere.Density)
)
expect(atmosphere.Haze > 0.5, "atmosphere haze is too low for distant ground to fade into the sky")

-- Decay is the colour distance fades toward. It has to be the blue end of
-- the sky, not the warm dust colour, or the gradient runs the wrong way and
-- the sky reads flat.
expect(
	atmosphere.Decay.B > atmosphere.Decay.R,
	string.format(
		"atmosphere decay (%.2f, %.2f, %.2f) is not blue-dominant, so the sky gradient is wrong",
		atmosphere.Decay.R,
		atmosphere.Decay.G,
		atmosphere.Decay.B
	)
)
expect(
	atmosphere.Color.B > atmosphere.Color.R,
	string.format(
		"atmosphere colour (%.2f, %.2f, %.2f) is not blue-dominant",
		atmosphere.Color.R,
		atmosphere.Color.G,
		atmosphere.Color.B
	)
)
expect(
	math.abs(atmosphere.Color.R - atmosphere.Decay.R)
			+ math.abs(atmosphere.Color.G - atmosphere.Decay.G)
			+ math.abs(atmosphere.Color.B - atmosphere.Decay.B)
		> 0.1,
	"atmosphere colour and decay are too similar to produce a visible sky gradient"
)
expect(
	Lighting.OutdoorAmbient.B > Lighting.OutdoorAmbient.R,
	"outdoor ambient is not picking up blue bounce from the sky"
)

---------------------------------------------------------------------------
-- Horizon scenery
---------------------------------------------------------------------------

local controllers = StarterPlayer.StarterPlayerScripts.Client.Controllers
local SkyController = require(controllers.SkyController)

local scenery = SkyController.BuildSceneryForTest()
expect(scenery ~= nil, "SkyController built no horizon scenery")

local tiles = 0
local mesas = 0
local groundSpan = 0
for _, part in scenery:GetDescendants() do
	if not part:IsA("BasePart") then
		continue
	end

	-- The invariant. Every one of these parts is within a few thousand studs
	-- of the player at all times.
	expect(
		not part.CanQuery,
		string.format(
			"%s is visible to raycasts and will swallow suspension and weapon fire",
			part.Name
		)
	)
	expect(not part.CanCollide, string.format("%s collides with vehicles", part.Name))
	expect(not part.CanTouch, string.format("%s fires touch events", part.Name))
	expect(part.Anchored, string.format("%s is not anchored and will fall", part.Name))

	if string.find(part.Name, "HorizonTile") then
		tiles += 1
		groundSpan = math.max(groundSpan, part.Size.X)
	elseif string.find(part.Name, "HorizonMesa") then
		mesas += 1
	end
end

expect(tiles >= 9, string.format("only %d horizon ground tiles, expected a 3x3 grid", tiles))
expect(
	groundSpan * 3 >= 6000,
	string.format("horizon ground only reaches %.0f studs across", groundSpan * 3)
)
expect(mesas >= 12, string.format("only %d distant mesas, which is not a skyline", mesas))

-- The probe must ignore both vehicle bodywork and elevated road decks. If it
-- accepts either one, the horizon plane rises with the ute or raised highway
-- and closes the visible fall beneath the road.
local probeFolder = Instance.new("Folder")
probeFolder.Name = "SkyProbeTest"
probeFolder.Parent = Workspace

local base = Instance.new("Part")
base.Name = "DesertGround"
base.Anchored = true
base.Size = Vector3.new(40, 1, 40)
base.Position = Vector3.new(5000, 0, 5000)
base:SetAttribute("SurfaceProfile", "WornDirt")
base.Parent = probeFolder

local elevatedDeck = Instance.new("Part")
elevatedDeck.Name = "RaisedDeck"
elevatedDeck.Anchored = true
elevatedDeck.Size = Vector3.new(40, 1, 40)
elevatedDeck.Position = Vector3.new(5000, 22, 5000)
elevatedDeck:SetAttribute("SurfaceProfile", "Asphalt")
elevatedDeck:SetAttribute("HorizonGround", false)
elevatedDeck.Parent = probeFolder

local fakeVehicle = Instance.new("Model")
fakeVehicle.Name = "ProbeVehicle"
fakeVehicle.Parent = probeFolder
local vehicleRoof = Instance.new("Part")
vehicleRoof.Name = "VehicleRoof"
vehicleRoof.Anchored = true
vehicleRoof.Size = Vector3.new(12, 2, 12)
vehicleRoof.Position = Vector3.new(5000, 36, 5000)
vehicleRoof.Parent = fakeVehicle
CollectionService:AddTag(fakeVehicle, "HoonangaVehicle")

local probedGround = SkyController.GroundHeightForTest(Vector3.new(5000, 100, 5000))
expect(probedGround ~= nil, "horizon probe found no desert ground")
expect(
	math.abs(probedGround - 0.5) < 0.1,
	string.format(
		"horizon probe stopped at %.1f instead of the desert below the vehicle and deck",
		probedGround
	)
)
CollectionService:RemoveTag(fakeVehicle, "HoonangaVehicle")
probeFolder:Destroy()
scenery:Destroy()

print(
	string.format(
		"[SKY] PASS: low sun with graded blue atmosphere, %d ground tiles and %d mesas, none raycast-visible",
		tiles,
		mesas
	)
)
