--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)

type ChunkRecord = {
	Index: number,
	Model: Model,
}

local ROAD_Y = 0
-- Red-centre palette: iron-oxide reds and oranges, worn browns, and the
-- bleached white of a dry salt pan for contrast.
local ROAD_COLORS = {
	Asphalt = Color3.fromRGB(64, 56, 52),
	WornDirt = Color3.fromRGB(150, 82, 48),
	LooseStone = Color3.fromRGB(174, 96, 54),
	Sand = Color3.fromRGB(214, 148, 84),
	SaltPan = Color3.fromRGB(232, 228, 216),
	Mud = Color3.fromRGB(56, 38, 25),
	Oil = Color3.fromRGB(9, 9, 10),
	CanyonRock = Color3.fromRGB(142, 70, 45),
}

-- Sections should read as distinct stretches of country rather than one
-- flat tone repeated forever, so each chunk's terrain is nudged warmer
-- (toward rust) or darker (toward shadowed earth) by a deterministic
-- per-chunk amount. Deterministic so a rebuilt chunk keeps its colour.
local VARIEGATION_WARM = Color3.fromRGB(198, 84, 38)
local VARIEGATION_DARK = Color3.fromRGB(46, 28, 20)

local function variegate(base: Color3, index: number, amount: number): Color3
	local shift = math.noise(index * 0.41, 1.7) * 2
	if shift >= 0 then
		return base:Lerp(VARIEGATION_WARM, math.clamp(shift, 0, 1) * amount)
	end
	return base:Lerp(VARIEGATION_DARK, math.clamp(-shift, 0, 1) * amount)
end

-- Road families cycle in runs of 4-8 chunks (GDD 8.6) rather than the whole
-- road being one family forever, both for driving variety and to mitigate
-- the "procedural repetition" risk (GDD 26). True per-chunk curvature isn't
-- implemented yet - every chunk is still a straight corridor along Z - so
-- families are differentiated by width, surface, and hazards rather than
-- path shape for now.
--
-- Weighted rather than uniform: the run should mostly be ground-level
-- racing through canyons, boulder plains and sandy desert. RaisedHighway is
-- deliberately rare because its whole identity is exposure and falling, and
-- at even odds it turned "a lot of the road" into elevated deck where the
-- player was falling off constantly instead of racing.
-- Run length is per-family, not global. Weight alone controls how often a
-- family is *picked*; without per-family run lengths a rarely-picked family
-- still occupied 4-8 chunks whenever it came up, so "occasional mudflat"
-- turned into a third of the run spent in mud. The staple families get long
-- stretches; the event biomes get short ones.
--
-- RaisedHighway must never run shorter than 3: the first chunk of a run is
-- the up-ramp and the last is the down-ramp, so a 1-2 chunk run would ramp
-- up to the elevated deck and stop there, leaving the road ending in a
-- sheer drop.
-- CooldownRuns blocks a family from being re-picked for that many
-- subsequent runs. Low weight alone was not enough to make the highway
-- rare: picking it is uncommon, but it occupies 3-4 chunks each time and
-- nothing stopped it being picked again one short run later, which in
-- practice produced stretches that were nearly 40% elevated deck.
local ROAD_FAMILY_WEIGHTS = {
	{ Name = "BoulderPlain", Weight = 10, MinRun = 4, MaxRun = 8, CooldownRuns = 0 },
	{ Name = "SandyDesert", Weight = 10, MinRun = 4, MaxRun = 8, CooldownRuns = 0 },
	{ Name = "Canyon", Weight = 9, MinRun = 3, MaxRun = 6, CooldownRuns = 1 },
	{ Name = "Mudflat", Weight = 5, MinRun = 1, MaxRun = 3, CooldownRuns = 2 },
	{ Name = "RaisedHighway", Weight = 2, MinRun = 3, MaxRun = 4, CooldownRuns = 5 },
}

-- The good ground you actually race on: a clear road down the middle of far
-- wider drivable terrain. The terrain either side is rougher (loose stone,
-- sand) and costs grip, but it is still ground - you can leave the road,
-- swing a U-turn and come back without falling off anything.
local ROAD_SURFACE_WIDTH = 38
-- "Small vehicle-length mud patches at most" - a chassis is ~15 studs long,
-- so a patch is a thing you hit and power through, not a bog you live in.
local MUD_PATCH_SIZE = Vector3.new(17, 0.18, 20)

local CANYON_WIDTH = 92
local CANYON_WALL_HEIGHT = 60
local HIGHWAY_WIDTH = 96
local HIGHWAY_RISE = 22
local HIGHWAY_RAIL_HEIGHT = 3.4

-- Terrain rolls and grades rather than being one dead-flat plane forever.
-- A chunk is built flat and then rotated as a whole about its own centre,
-- with the running ground height tracked so each chunk's entry edge starts
-- exactly where the previous chunk's exit edge finished - the seams stay
-- flush no matter how the elevation drifts.
--
-- Angles are deliberately small. Pitch is free (tracked height keeps seams
-- flush), but a roll *change* between chunks steps the surface by
-- halfWidth * tan(delta) out at the chunk edge, so the cap is what keeps
-- that step driveable. Near the road centre, where the player actually is,
-- the step is a fraction of a stud.
local SLOPE_RUN_CHANCE = 0.25
local MAX_PITCH = math.rad(2)
local MAX_ROLL = math.rad(2.5)
-- The band the road is allowed to drift within. The floor matters: a vehicle
-- below CollisionDamageService's FALL_DESTROY_Y (-80) is destroyed as having
-- fallen out of the world, so the road descending anywhere near that would
-- kill the player while they were driving along solid ground. This keeps a
-- wide margin under the lowest the road can ever get.
local MIN_ELEVATION = -25
local MAX_ELEVATION = 65
-- Pitching a chunk about its centre shortens its footprint along Z by
-- cos(pitch), which would open a thin gap at the seam. Base terrain slabs
-- are lengthened so neighbours overlap instead.
local CHUNK_Z_OVERLAP = 24

-- A fork is one wide chunk split into two parallel, differently-hazarded
-- lanes with a boulder line down the middle forcing the player to commit to
-- one side, rather than GDD 8.7's full multi-chunk diverge/reconverge
-- branch geometry - that needs a chunk heading/curvature system this
-- service doesn't have yet. This still delivers the actual design goal (a
-- real route choice with a real tradeoff) with the existing straight-corridor
-- chunk model, and reconverges trivially since the lanes never physically
-- separated.
local FORK_LANE_WIDTH = 72
local FORK_MIN_INTERVAL = 6
local FORK_MAX_INTERVAL = 10

-- Every generation decision draws from this one seeded stream rather than
-- the global math.random (GDD 8.5). A run is therefore reproducible from its
-- seed alone, which makes a terrain bug something you can hand to someone
-- else and have them see, and is the prerequisite for daily-challenge style
-- modes later. Player actions stay non-deterministic - only the road is
-- pinned.
local directorSeed = 0
local directorRandom = Random.new()

local chunks: { ChunkRecord } = {}
local chunkFolder: Folder
local nextChunkIndex = 0
local running = false
local currentFamily = "BoulderPlain"
local remainingInFamily = 0
local chunksUntilFork = 0
local familyCooldowns: { [string]: number } = {}
-- Height of the road at the seam the next chunk starts from, plus the slope
-- the current family run is driving at.
local groundExitY = 0
local runPitch = 0
local runRoll = 0

-- Mud and salt are flats. They read as flats, and they are the two surfaces
-- where the player is already fighting for grip, so tilting them is neither
-- truthful to the terrain nor kind.
local function familyIsFlat(family: string): boolean
	return family == "Mudflat" or family == "RaisedHighway"
end

-- isFirstOfRun/isLastOfRun let RaisedHighway bracket itself with ramp
-- chunks: every other family sits at ROAD_Y, but the highway deck sits 22
-- studs up, so a bare family transition would leave the road ending in a
-- sheer cliff instead of a drivable slope.
local function pickNextFamily(): (string, boolean, boolean)
	local isFirstOfRun = false
	if remainingInFamily <= 0 then
		for name, remaining in familyCooldowns do
			familyCooldowns[name] = if remaining > 1 then remaining - 1 else nil
		end

		local function isEligible(entry): boolean
			return entry.Name ~= currentFamily and familyCooldowns[entry.Name] == nil
		end

		local totalWeight = 0
		for _, entry in ROAD_FAMILY_WEIGHTS do
			if isEligible(entry) then
				totalWeight += entry.Weight
			end
		end

		local roll = directorRandom:NextNumber() * totalWeight
		for _, entry in ROAD_FAMILY_WEIGHTS do
			if isEligible(entry) then
				roll -= entry.Weight
				if roll <= 0 then
					currentFamily = entry.Name
					remainingInFamily = directorRandom:NextInteger(entry.MinRun, entry.MaxRun)
					if entry.CooldownRuns > 0 then
						familyCooldowns[entry.Name] = entry.CooldownRuns + 1
					end

					if
						familyIsFlat(entry.Name)
						or directorRandom:NextNumber() > SLOPE_RUN_CHANCE
					then
						runPitch = 0
						runRoll = 0
					else
						runPitch = directorRandom:NextNumber(-1, 1) * MAX_PITCH
						runRoll = directorRandom:NextNumber(-1, 1) * MAX_ROLL
					end
					break
				end
			end
		end

		isFirstOfRun = true
	end

	remainingInFamily -= 1
	local isLastOfRun = remainingInFamily <= 0
	return currentFamily, isFirstOfRun, isLastOfRun
end

local function makeSurface(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	profile: string,
	color: Color3,
	material: Enum.Material
): Part
	local surface = Instance.new("Part")
	surface.Name = name
	surface.Anchored = true
	surface.Size = size
	surface.CFrame = cframe
	surface.Color = color
	surface.Material = material
	surface.TopSurface = Enum.SurfaceType.Smooth
	surface.BottomSurface = Enum.SurfaceType.Smooth
	surface:SetAttribute("SurfaceProfile", profile)
	surface.Parent = parent
	CollectionService:AddTag(surface, "RoadSurface")
	return surface
end

local function addBoulder(parent: Instance, position: Vector3, scale: number)
	local boulder = Instance.new("Part")
	boulder.Name = "Boulder"
	boulder.Anchored = true
	boulder.Size = Vector3.new(5.5, 4, 6.5) * scale
	boulder.Position = position
	boulder.Orientation = Vector3.new(12, (position.Z * 17) % 180, 8)
	-- Seeded off the boulder's own position so a field reads as mixed rock
	-- rather than a row of identical props.
	boulder.Color = variegate(ROAD_COLORS.CanyonRock, position.Z * 0.05 + position.X, 0.4)
	boulder.Material = Enum.Material.Slate
	boulder.Parent = parent
	CollectionService:AddTag(boulder, "RoadHardBoundary")
end

local function addFuelPickup(chunk: Model, cframe: CFrame)
	local fuelPickup = Instance.new("Part")
	fuelPickup.Name = "FuelPickup"
	fuelPickup.Anchored = true
	fuelPickup.CanCollide = false
	fuelPickup.Size = Vector3.new(3.2, 4, 3.2)
	fuelPickup.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	fuelPickup.Shape = Enum.PartType.Cylinder
	fuelPickup.Color = Color3.fromRGB(191, 59, 41)
	fuelPickup.Material = Enum.Material.Metal
	fuelPickup:SetAttribute("FuelAmount", 90)
	fuelPickup.Parent = chunk
	CollectionService:AddTag(fuelPickup, "FuelPickup")
end

local function addSockets(chunk: Model, centerZ: number, chunkLength: number)
	local socketStart = Instance.new("Part")
	socketStart.Name = "StartSocket"
	socketStart.Anchored = true
	socketStart.CanCollide = false
	socketStart.CanQuery = false
	socketStart.Transparency = 1
	socketStart.Size = Vector3.one
	socketStart.CFrame = CFrame.new(0, 0, centerZ + chunkLength / 2)
	socketStart.Parent = chunk

	local socketEnd = socketStart:Clone()
	socketEnd.Name = "EndSocket"
	socketEnd.CFrame = CFrame.new(0, 0, centerZ - chunkLength / 2)
	socketEnd.Parent = chunk
end

-- Every ground-level chunk lays this first, spanning the full chunk width,
-- before anything narrower goes on top. Families whose feature geometry is
-- narrower than the chunk (the canyon floor, the fork's split lanes) would
-- otherwise leave the uncovered remainder as open air, which is a pit at
-- speed rather than a visible edge. road_coverage_test.luau guards this.
local function addBaseTerrain(
	chunk: Model,
	index: number,
	centerZ: number,
	name: string,
	profile: string,
	color: Color3,
	material: Enum.Material
)
	local road = WorldConfig.Road
	makeSurface(
		chunk,
		name,
		Vector3.new(road.ChunkWidth, 1, road.ChunkLength + CHUNK_Z_OVERLAP),
		CFrame.new(0, ROAD_Y, centerZ) * CFrame.new(0, -0.55, 0),
		profile,
		variegate(color, index, 0.35),
		material
	)
end

-- Shared layout for the ground-level families: wide drivable terrain with a
-- clear good-ground road down the middle, plus the occasional hazard sitting
-- on that road. Hazard cadence is index-driven rather than random so a run
-- is reproducible and the smoke test can rely on seeing each surface type.
local function addGroundRoad(
	chunk: Model,
	index: number,
	centerZ: number,
	terrainName: string,
	terrainProfile: string,
	terrainColor: Color3,
	terrainMaterial: Enum.Material
)
	local road = WorldConfig.Road
	local center = CFrame.new(0, ROAD_Y, centerZ)

	makeSurface(
		chunk,
		terrainName,
		Vector3.new(road.ChunkWidth, 1, road.ChunkLength + CHUNK_Z_OVERLAP),
		center * CFrame.new(0, -0.55, 0),
		terrainProfile,
		variegate(terrainColor, index, 0.35),
		terrainMaterial
	)

	local isAsphalt = index % 4 == 0
	makeSurface(
		chunk,
		if isAsphalt then "AsphaltRoad" else "WornTrack",
		Vector3.new(ROAD_SURFACE_WIDTH, 0.25, road.ChunkLength),
		center * CFrame.new(0, 0.08, 0),
		if isAsphalt then "Asphalt" else "WornDirt",
		if isAsphalt then ROAD_COLORS.Asphalt else variegate(ROAD_COLORS.WornDirt, index * 3, 0.22),
		if isAsphalt then Enum.Material.Asphalt else Enum.Material.Ground
	)

	if index % 3 == 1 then
		local mud = makeSurface(
			chunk,
			"MudPatch",
			MUD_PATCH_SIZE,
			center * CFrame.new(-8, 0.24, -60),
			"Mud",
			ROAD_COLORS.Mud,
			Enum.Material.Mud
		)
		mud:SetAttribute("HazardType", "Mud")
	end

	if index % 5 == 2 then
		local oil = makeSurface(
			chunk,
			"OilSlick",
			Vector3.new(15, 0.08, 34),
			center * CFrame.new(7, 0.29, 40),
			"Oil",
			ROAD_COLORS.Oil,
			Enum.Material.SmoothPlastic
		)
		oil.Transparency = 0.12
		oil:SetAttribute("HazardType", "Oil")
	end

	if index % 4 == 3 then
		addFuelPickup(chunk, center * CFrame.new(-13, 2.25, -30))
	end

	chunk:SetAttribute("PreferredLaneX", 0)
end

-- Open stony plain: the road threads between scattered boulder fields that
-- are hard boundaries, so leaving the road is possible but has to be picked
-- carefully rather than driven blindly.
local function configureBoulderPlainChunk(chunk: Model, index: number, centerZ: number)
	local road = WorldConfig.Road
	addGroundRoad(
		chunk,
		index,
		centerZ,
		"LooseStone",
		"LooseStone",
		ROAD_COLORS.LooseStone,
		Enum.Material.Slate
	)

	local edge = road.ChunkWidth / 2
	local roadEdge = ROAD_SURFACE_WIDTH / 2
	for _, side in { -1, 1 } do
		for cluster = 0, 2 do
			-- Spread across the runoff, never onto the road itself.
			local spread = roadEdge
				+ 14
				+ ((index * 37 + cluster * 53) % math.max(1, edge - roadEdge - 20))
			addBoulder(
				chunk,
				Vector3.new(side * spread, 1.6, centerZ - 180 + cluster * 160 + side * 24),
				0.7 + ((index + cluster) % 3) * 0.2
			)
		end
	end
end

-- Open sand: fewer obstacles and longer sightlines than the boulder plain,
-- but the runoff is soft (low grip, mild bogging) so pushing wide to cut a
-- corner costs speed.
local function configureSandyDesertChunk(chunk: Model, index: number, centerZ: number)
	-- Alternating stretches of orange sand and bleached salt pan, so a desert
	-- run reads as varied country rather than one endless tone. The salt is
	-- also the one fast off-road surface, which changes how the section plays
	-- and not just how it looks.
	-- Salt flats are flat, so a graded or cambered run stays all sand.
	local isSaltPan = (index // 2) % 2 == 1 and runPitch == 0 and runRoll == 0
	if isSaltPan then
		addGroundRoad(
			chunk,
			index,
			centerZ,
			"SaltPan",
			"SaltPan",
			ROAD_COLORS.SaltPan,
			Enum.Material.Salt
		)
	else
		addGroundRoad(
			chunk,
			index,
			centerZ,
			"SandFlat",
			"Sand",
			ROAD_COLORS.Sand,
			Enum.Material.Sand
		)
	end

	local side = if index % 2 == 0 then -1 else 1
	addBoulder(
		chunk,
		Vector3.new(side * (ROAD_SURFACE_WIDTH / 2 + 30), 1.4, centerZ - 60),
		0.6 + (index % 3) * 0.2
	)
end

-- Narrow choke-point corridor with real wall collision geometry (GDD 9.2):
-- hitting a wall at speed triggers CollisionDamageService's existing
-- RoadHardBoundary impact handling, the same mechanism boulders already use.
local function configureCanyonChunk(chunk: Model, index: number, centerZ: number)
	local road = WorldConfig.Road
	local center = CFrame.new(0, ROAD_Y, centerZ)

	-- Rock shelf running the full chunk width, so the ground outside the
	-- canyon walls is solid. The walls are the boundary, not a cliff edge.
	addBaseTerrain(
		chunk,
		index,
		centerZ,
		"CanyonShelf",
		"LooseStone",
		ROAD_COLORS.CanyonRock,
		Enum.Material.Rock
	)

	makeSurface(
		chunk,
		"CanyonFloor",
		Vector3.new(CANYON_WIDTH, 1, road.ChunkLength),
		center * CFrame.new(0, -0.4, 0),
		"WornDirt",
		variegate(ROAD_COLORS.WornDirt, index * 5, 0.2),
		Enum.Material.Ground
	)

	for _, side in { -1, 1 } do
		local wall = Instance.new("Part")
		wall.Name = "CanyonWall"
		wall.Anchored = true
		wall.Size = Vector3.new(16, CANYON_WALL_HEIGHT, road.ChunkLength)
		wall.CFrame = center
			* CFrame.new(side * (CANYON_WIDTH / 2 + 8), CANYON_WALL_HEIGHT / 2 - 3, 0)
		-- Each wall shifted independently so a canyon has banded strata
		-- rather than two flat slabs of identical colour.
		wall.Color = variegate(ROAD_COLORS.CanyonRock, index * 2 + side, 0.42)
		wall.Material = Enum.Material.Rock
		wall.Parent = chunk
		CollectionService:AddTag(wall, "RoadHardBoundary")
	end

	-- A boulder pinched toward one side per chunk, alternating, for a mild
	-- slalom (GDD 9.2 "fallen boulder slalom") without fully blocking the
	-- narrow corridor.
	local pinchSide = if index % 2 == 0 then -1 else 1
	addBoulder(chunk, Vector3.new(pinchSide * (CANYON_WIDTH / 2 - 6), 1.8, centerZ), 0.85)

	if index % 4 == 3 then
		addFuelPickup(chunk, center * CFrame.new(-pinchSide * 8, 2.25, -120))
	end

	chunk:SetAttribute("PreferredLaneX", 0)
end

-- Elevated straight with an exposed edge (GDD 9.1): the road is a floating
-- strip with nothing beneath it off to the sides, so driving (or being
-- rammed) off either edge is a genuine fall - CollisionDamageService's
-- existing RoadLethalZone/FALL_DESTROY_Y handling already destroys a
-- vehicle that drops far enough, no new fall-detection code needed here.
-- The guard rail is deliberately missing on one side each chunk ("missing
-- outer barrier" from the chunk idea list) so the exposure is asymmetric.
local function configureHighwayChunk(chunk: Model, index: number, centerZ: number, baseY: number)
	local road = WorldConfig.Road
	local center = CFrame.new(0, baseY + HIGHWAY_RISE, centerZ)

	makeSurface(
		chunk,
		"HighwayDeck",
		Vector3.new(HIGHWAY_WIDTH, 1.4, road.ChunkLength),
		center,
		"Asphalt",
		ROAD_COLORS.Asphalt,
		Enum.Material.Asphalt
	)

	local railedSide = if index % 2 == 0 then -1 else 1
	local rail = Instance.new("Part")
	rail.Name = "HighwayGuardRail"
	rail.Anchored = true
	rail.Size = Vector3.new(1.6, HIGHWAY_RAIL_HEIGHT, road.ChunkLength)
	rail.CFrame = center
		* CFrame.new(railedSide * (HIGHWAY_WIDTH / 2 - 0.8), HIGHWAY_RAIL_HEIGHT / 2 + 0.7, 0)
	rail.Color = Color3.fromRGB(150, 150, 145)
	rail.Material = Enum.Material.Metal
	rail.Parent = chunk
	CollectionService:AddTag(rail, "RoadHardBoundary")

	if index % 4 == 3 then
		addFuelPickup(chunk, center * CFrame.new(-railedSide * (HIGHWAY_WIDTH / 2 - 6), 2.25, -100))
	end

	chunk:SetAttribute("PreferredLaneX", 0)
end

-- A gentle sloped deck bridging the ground and the elevated deck at the start/end of
-- every highway run (GDD 8.3: "vertical changes remain gentle enough for
-- vehicle suspension unless the chunk is intentionally a ramp"). Travel
-- runs from a chunk's StartSocket (higher Z) to its EndSocket (lower Z), so
-- ramping up means low-Z-side is elevated and ramping down means
-- high-Z-side still is.
local function configureHighwayRampChunk(
	chunk: Model,
	centerZ: number,
	rampingUp: boolean,
	baseY: number
)
	local road = WorldConfig.Road
	local startY = if rampingUp then baseY else baseY + HIGHWAY_RISE
	local endY = if rampingUp then baseY + HIGHWAY_RISE else baseY
	local startPos = Vector3.new(0, startY, centerZ + road.ChunkLength / 2)
	local endPos = Vector3.new(0, endY, centerZ - road.ChunkLength / 2)
	local midpoint = (startPos + endPos) / 2
	local slopeLength = (endPos - startPos).Magnitude

	local ramp = Instance.new("Part")
	ramp.Name = "HighwayRamp"
	ramp.Anchored = true
	ramp.Size = Vector3.new(HIGHWAY_WIDTH, 1.4, slopeLength)
	ramp.CFrame = CFrame.new(midpoint, endPos)
	ramp.Color = ROAD_COLORS.Asphalt
	ramp.Material = Enum.Material.Asphalt
	ramp:SetAttribute("SurfaceProfile", "Asphalt")
	ramp.Parent = chunk
	CollectionService:AddTag(ramp, "RoadSurface")

	chunk:SetAttribute("PreferredLaneX", 0)
end

-- A genuine mudflat biome (GDD 9.3), distinct from the small mud patches
-- that sit on the ordinary road: here the mud is the terrain and the good
-- ground is a firm path threaded through it, so the route-reading is the
-- point. Weighted low so crossing one is an occasional event rather than
-- the default texture of a run.
local function configureMudflatChunk(chunk: Model, index: number, centerZ: number)
	local road = WorldConfig.Road
	local center = CFrame.new(0, ROAD_Y, centerZ)
	local pathOffset = if index % 2 == 0 then -16 else 16

	makeSurface(
		chunk,
		"MudExpanse",
		Vector3.new(road.ChunkWidth, 1, road.ChunkLength + CHUNK_Z_OVERLAP),
		center * CFrame.new(0, -0.5, 0),
		"Mud",
		variegate(ROAD_COLORS.Mud, index, 0.25),
		Enum.Material.Mud
	)

	makeSurface(
		chunk,
		"FirmPath",
		Vector3.new(ROAD_SURFACE_WIDTH, 0.22, road.ChunkLength),
		center * CFrame.new(pathOffset, 0.05, 0),
		"WornDirt",
		variegate(ROAD_COLORS.WornDirt, index * 3, 0.22),
		Enum.Material.Ground
	)

	if index % 4 == 3 then
		addFuelPickup(chunk, center * CFrame.new(pathOffset, 2.25, -160))
	end

	chunk:SetAttribute("PreferredLaneX", pathOffset)
end

-- Left lane trades grip for a fuel pickup, right lane keeps normal grip and
-- offers nothing - a direct instance of GDD 8.7's example tradeoff ("exposed
-- highway with fuel versus protected canyon without fuel").
local function configureForkChunk(chunk: Model, index: number, centerZ: number)
	local center = CFrame.new(0, ROAD_Y, centerZ)
	local laneOffset = FORK_LANE_WIDTH / 2 + 10

	-- Solid ground under the whole chunk. The lanes and the boulder divider
	-- sit on top of it: the divider should make you commit to a side, not
	-- open a pit down the centre line you were already driving along.
	addBaseTerrain(
		chunk,
		index,
		centerZ,
		"ForkGround",
		"LooseStone",
		ROAD_COLORS.LooseStone,
		Enum.Material.Slate
	)

	local leftLane = makeSurface(
		chunk,
		"ForkLaneLeft",
		Vector3.new(FORK_LANE_WIDTH, 0.9, WorldConfig.Road.ChunkLength),
		center * CFrame.new(-laneOffset, -0.4, 0),
		"Mud",
		ROAD_COLORS.Mud,
		Enum.Material.Mud
	)
	leftLane:SetAttribute("HazardType", "Mud")
	addFuelPickup(chunk, center * CFrame.new(-laneOffset, 2.25, 0))

	makeSurface(
		chunk,
		"ForkLaneRight",
		Vector3.new(FORK_LANE_WIDTH, 1, WorldConfig.Road.ChunkLength),
		center * CFrame.new(laneOffset, -0.55, 0),
		"LooseStone",
		ROAD_COLORS.LooseStone,
		Enum.Material.Slate
	)

	for offsetZ = -1, 1 do
		addBoulder(chunk, Vector3.new(0, 2, centerZ + offsetZ * 150), 0.9)
	end

	-- Steer AI toward the predictable right lane rather than the boulder
	-- divider it would otherwise drive straight at.
	chunk:SetAttribute("PreferredLaneX", laneOffset)
end

-- Chunks are built flat around (0, ROAD_Y, centerZ) and then tilted as a
-- whole. Rotating about the chunk's own centre means the entry edge drops by
-- the same amount the exit edge rises, so placing the centre at
-- previousExit + sin(pitch) * halfLength lands the entry edge exactly on the
-- previous chunk's exit edge and the seam stays flush.
local function applyChunkSlope(chunk: Model, centerZ: number, pitch: number, roll: number): number
	local halfLength = WorldConfig.Road.ChunkLength / 2
	local rise = math.sin(pitch) * halfLength
	local centerY = groundExitY + rise

	if pitch ~= 0 or roll ~= 0 then
		chunk.WorldPivot = CFrame.new(0, ROAD_Y, centerZ)
		chunk:PivotTo(CFrame.new(0, centerY, centerZ) * CFrame.Angles(pitch, 0, roll))
	elseif centerY ~= ROAD_Y then
		chunk.WorldPivot = CFrame.new(0, ROAD_Y, centerZ)
		chunk:PivotTo(CFrame.new(0, centerY, centerZ))
	end

	return centerY + rise
end

local function configureChunk(chunk: Model, index: number)
	local road = WorldConfig.Road
	local centerZ = -(index * road.ChunkLength)
	chunk.Name = string.format("Chunk_%04d", index)
	chunk:SetAttribute("ChunkIndex", index)

	-- A fork mid-highway-run would sit at ground level between deck chunks -
	-- the same cliff problem the ramp chunks exist to avoid. currentFamily
	-- still reads "RaisedHighway" for every chunk of an in-progress run
	-- right up until pickNextFamily next advances it, so this defers the
	-- fork rather than dropping it into the middle of the highway.
	-- The highway builds its own absolute heights off groundExitY, so it opts
	-- out of the generic tilt; everything else is built flat and then tilted.
	local pitch, roll = runPitch, runRoll

	if chunksUntilFork <= 0 and currentFamily ~= "RaisedHighway" then
		chunksUntilFork = directorRandom:NextInteger(FORK_MIN_INTERVAL, FORK_MAX_INTERVAL)
		chunk:SetAttribute("RoadFamily", "Fork")
		configureForkChunk(chunk, index, centerZ)
	else
		if chunksUntilFork > 0 then
			chunksUntilFork -= 1
		end
		local family, isFirstOfRun, isLastOfRun = pickNextFamily()
		chunk:SetAttribute("RoadFamily", family)
		if family == "Canyon" then
			configureCanyonChunk(chunk, index, centerZ)
		elseif family == "SandyDesert" then
			configureSandyDesertChunk(chunk, index, centerZ)
		elseif family == "Mudflat" then
			configureMudflatChunk(chunk, index, centerZ)
		elseif family == "RaisedHighway" then
			pitch, roll = 0, 0
			if isFirstOfRun then
				configureHighwayRampChunk(chunk, centerZ, true, groundExitY)
			elseif isLastOfRun then
				configureHighwayRampChunk(chunk, centerZ, false, groundExitY)
			else
				configureHighwayChunk(chunk, index, centerZ, groundExitY)
			end
		else
			configureBoulderPlainChunk(chunk, index, centerZ)
		end
	end

	if not (currentFamily == "RaisedHighway" and chunk:GetAttribute("RoadFamily") ~= "Fork") then
		-- Keep the running elevation inside its band. Level off on reaching
		-- the limit rather than reversing the grade: flipping the sign made
		-- the road sawtooth up and down every chunk once it saturated,
		-- which reads as a ramp field rather than rolling country.
		local projected = groundExitY + math.sin(pitch) * road.ChunkLength
		if projected > MAX_ELEVATION or projected < MIN_ELEVATION then
			local limit = if projected > MAX_ELEVATION then MAX_ELEVATION else MIN_ELEVATION
			pitch = math.asin(math.clamp((limit - groundExitY) / road.ChunkLength, -1, 1))
			runPitch = 0
		end
		groundExitY = applyChunkSlope(chunk, centerZ, pitch, roll)
	end

	chunk:SetAttribute("GroundExitY", groundExitY)
	addSockets(chunk, centerZ, road.ChunkLength)
end

local function createChunk(index: number): ChunkRecord
	local model = Instance.new("Model")
	model.Parent = chunkFolder
	configureChunk(model, index)
	return {
		Index = index,
		Model = model,
	}
end

local function slowestPlayerProgress(): number
	local slowest: number? = nil
	for _, vehicle in CollectionService:GetTagged("HoonangaVehicle") do
		if
			vehicle:IsA("Model")
			and vehicle.PrimaryPart
			and not vehicle:GetAttribute("Destroyed")
			and vehicle:GetAttribute("Team") == "Player"
		then
			local progress = -vehicle.PrimaryPart.Position.Z
			slowest = if slowest then math.min(slowest, progress) else progress
		end
	end
	return slowest or 0
end

local function recyclePassedChunks()
	local road = WorldConfig.Road
	local progress = slowestPlayerProgress()
	table.sort(chunks, function(a, b)
		return a.Index < b.Index
	end)

	while #chunks > 0 do
		local first = chunks[1]
		local chunkEndProgress = (first.Index + 0.5) * road.ChunkLength
		if progress - chunkEndProgress < road.RecycleDistance then
			break
		end

		table.remove(chunks, 1)
		first.Model:Destroy()
		local replacement = createChunk(nextChunkIndex)
		nextChunkIndex += 1
		table.insert(chunks, replacement)
	end
end

local RoadService = {}

-- Pass a seed to reproduce a specific run exactly; omit it and one is drawn
-- from the clock and logged so a run you stumble into can still be replayed.
function RoadService.Start(seed: number?)
	if running then
		return
	end
	running = true

	directorSeed = seed or (DateTime.now().UnixTimestampMillis % 2 ^ 31)
	directorRandom = Random.new(directorSeed)
	print(string.format("[Hoonanga] Road seed %d", directorSeed))

	local existing = Workspace:FindFirstChild("HoonangaWorld")
	if existing then
		existing:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "HoonangaWorld"
	world.Parent = Workspace

	chunkFolder = Instance.new("Folder")
	chunkFolder.Name = "RoadChunks"
	chunkFolder.Parent = world

	local vehicles = Instance.new("Folder")
	vehicles.Name = "Vehicles"
	vehicles.Parent = world

	local fallbackSpawn = Instance.new("SpawnLocation")
	fallbackSpawn.Name = "FallbackSpawn"
	fallbackSpawn.Anchored = true
	fallbackSpawn.CanCollide = true
	fallbackSpawn.Neutral = true
	fallbackSpawn.Duration = 0
	fallbackSpawn.Size = Vector3.new(10, 1, 10)
	fallbackSpawn.Position = Vector3.new(-34, 0.75, 120)
	fallbackSpawn.Color = Color3.fromRGB(176, 123, 63)
	fallbackSpawn.Material = Enum.Material.Metal
	fallbackSpawn.Transparency = 0.25
	fallbackSpawn.Parent = world

	local killPlane = Instance.new("Part")
	killPlane.Name = "KillPlane"
	killPlane.Anchored = true
	killPlane.CanCollide = false
	killPlane.Transparency = 1
	killPlane.Size = Vector3.new(2000, 4, 100000)
	killPlane.Position = Vector3.new(0, -120, -49000)
	killPlane:SetAttribute("Lethal", true)
	killPlane.Parent = world
	CollectionService:AddTag(killPlane, "RoadLethalZone")

	chunks = {}
	-- Every run opens on a stretch of boulder plain: forgiving terrain with
	-- clear sightlines, per the design doc's pressure curve (GDD 4.3).
	currentFamily = "BoulderPlain"
	remainingInFamily = directorRandom:NextInteger(4, 8)
	familyCooldowns = {}
	-- The opening stretch is flat and at ground level so the spawn area is
	-- predictable.
	groundExitY = 0
	runPitch = 0
	runRoll = 0
	chunksUntilFork = directorRandom:NextInteger(FORK_MIN_INTERVAL, FORK_MAX_INTERVAL)
	nextChunkIndex = WorldConfig.Road.InitialChunkCount
	for index = 0, WorldConfig.Road.InitialChunkCount - 1 do
		table.insert(chunks, createChunk(index))
	end

	task.spawn(function()
		while running do
			recyclePassedChunks()
			task.wait(0.5)
		end
	end)
end

function RoadService.GetSeed(): number
	return directorSeed
end

-- Releases the re-entry guard so the road can be regenerated in-process.
-- Exists for tests that need to build the same road twice and compare;
-- gameplay only ever starts the road once.
function RoadService.Reset()
	running = false
	chunks = {}
end

return RoadService
