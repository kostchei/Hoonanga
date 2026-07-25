--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EnvironmentConfig = require(ReplicatedStorage.Shared.Config.EnvironmentConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local ConvoyService = require(script.Parent.ConvoyService)

-- Frames are world-space CFrames sampled along the chunk's centre line, with
-- Distances holding the arc length of each one from the very start of the
-- run. Together they are the road's actual path: since the road curves, "how
-- far has this vehicle got" and "which chunk is it in" can no longer be read
-- off a world coordinate and have to be measured against this polyline
-- instead.
type ChunkRecord = {
	Index: number,
	Model: Model,
	EntryCFrame: CFrame,
	ExitCFrame: CFrame,
	Curvature: number,
	PathDistance: number,
	LaneX: number,
	Frames: { CFrame },
	Distances: { number },
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
-- the "procedural repetition" risk (GDD 26). Families differ in width,
-- surface and hazards; curvature is a separate axis applied on top, so a
-- canyon can be a sweeping left-hander and a boulder plain can be straight.
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
-- Difficulty/MinSpeed/MaxActiveEnemies/AllowsFork are the per-family half of
-- GDD 8.2's chunk metadata. Formation AI consumes road capacity today; a
-- future encounter director will also read MaxActiveEnemies. The attributes
-- they are published on every chunk now so that director has something to
-- read, and so a chunk can be inspected in the explorer and understood.
local ROAD_FAMILY_WEIGHTS = {
	{
		Name = "BoulderPlain",
		Weight = 10,
		MinRun = 4,
		MaxRun = 8,
		CooldownRuns = 0,
		Difficulty = 1,
		MinSpeed = 0,
		MaxActiveEnemies = 3,
		AllowsFork = true,
	},
	{
		Name = "SandyDesert",
		Weight = 10,
		MinRun = 4,
		MaxRun = 8,
		CooldownRuns = 0,
		Difficulty = 1,
		MinSpeed = 0,
		MaxActiveEnemies = 3,
		AllowsFork = true,
	},
	{
		Name = "Canyon",
		Weight = 9,
		MinRun = 3,
		MaxRun = 6,
		CooldownRuns = 1,
		Difficulty = 3,
		MinSpeed = 0,
		MaxActiveEnemies = 2,
		AllowsFork = false,
	},
	{
		Name = "Mudflat",
		Weight = 5,
		MinRun = 1,
		MaxRun = 3,
		CooldownRuns = 2,
		Difficulty = 2,
		MinSpeed = 0,
		MaxActiveEnemies = 2,
		AllowsFork = true,
	},
	{
		Name = "RaisedHighway",
		Weight = 2,
		MinRun = 3,
		MaxRun = 4,
		CooldownRuns = 5,
		Difficulty = 4,
		-- Crawling on an exposed deck is how you get rammed off it.
		MinSpeed = 25,
		MaxActiveEnemies = 1,
		AllowsFork = false,
	},
}

local FAMILY_BY_NAME: { [string]: any } = {}
for _, entry in ROAD_FAMILY_WEIGHTS do
	FAMILY_BY_NAME[entry.Name] = entry
end

-- Fork is placed on its own schedule rather than being weight-selected, so
-- it is not in the table above, but it still needs metadata like any other
-- chunk. AllowsFork is false because you are already committing to a branch.
FAMILY_BY_NAME.Fork = {
	Name = "Fork",
	Weight = 0,
	Difficulty = 2,
	MinSpeed = 0,
	MaxActiveEnemies = 2,
	AllowsFork = false,
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
-- A chunk is built flat in its own local space and then placed with a pitch
-- and roll about its entry seam, so each chunk's entry edge starts exactly
-- where the previous chunk's exit edge finished and the seams stay flush no
-- matter how the elevation drifts.
--
-- Angles are deliberately small. Pitch is free (the running path frame keeps
-- seams flush), but a roll *change* between chunks steps the surface by
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
-- Pitching a chunk shortens its footprint along its own travel axis by
-- cos(pitch), which would open a thin gap at the seam. Base terrain slabs
-- are lengthened so neighbours overlap instead.
local CHUNK_Z_OVERLAP = 24

-- A fork is one wide chunk split into two parallel, differently-hazarded
-- lanes with a boulder line down the middle forcing the player to commit to
-- one side, rather than GDD 8.7's full multi-chunk diverge/reconverge
-- branch geometry. This still delivers the actual design goal (a real route
-- choice with a real tradeoff) and reconverges trivially since the lanes
-- never physically separated.
local FORK_LANE_WIDTH = 72
local FORK_MIN_INTERVAL = 6
local FORK_MAX_INTERVAL = 10

-- Curvature (GDD 8.2 EntryHeading/ExitHeading, 8.3 socket rules). A chunk
-- either runs straight or sweeps through a constant-radius arc; the running
-- path frame picks up the heading change so the next chunk continues from
-- wherever this one pointed.
--
-- Three severities rather than a continuous range, because they read as
-- three different driving problems: a slight bend you take flat, a medium
-- one you lift for, and a ninety you brake for. A 90 degree turn over a
-- 512-stud chunk is a 326-stud radius, which is a fast sweeper rather than
-- a hairpin.
local CURVE_CHANCE = 0.25
local CURVE_KINDS = {
	{ Name = "Slight", Weight = 55, MinDegrees = 6, MaxDegrees = 14 },
	{ Name = "Medium", Weight = 30, MinDegrees = 22, MaxDegrees = 40 },
	{ Name = "Hard", Weight = 15, MinDegrees = 90, MaxDegrees = 90 },
}
-- Curves alternate: without this the same sign keeps coming up and the road
-- spirals into a coil instead of weaving through country. Not 100%, because
-- two bends the same way in a row is a real road feature and a road that
-- alternates perfectly is its own kind of monotony.
local CURVE_OPPOSITE_CHANCE = 0.75
-- How many rectangular slabs approximate one curved chunk's arc. Twelve
-- keeps the polygon error well under a stud at the widest chunk while
-- staying cheap enough to rebuild during play.
local CURVE_SEGMENTS = 12
-- Spine samples stored per chunk for path queries. Nine points is fine
-- enough that the straight-line error between samples is negligible even on
-- a ninety.
local SPINE_SAMPLES = 12

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

-- The running path frame: where the next chunk's entry seam sits, which way
-- it points, and how far along the road that is. This replaces the old
-- "chunk index times chunk length" world-Z placement, which could only ever
-- describe a straight road.
local pathPosition = Vector3.zero
local pathYaw = 0
local pathDistance = 0
local runPitch = 0
local runRoll = 0
-- Which way the last curve went, so the next one can lean the other way.
local lastCurveSign = 1

-- Curvature of the chunk currently being built, in radians per stud. Module
-- state rather than a parameter threaded through every builder: every
-- geometry helper below needs it, and a chunk is only ever built by one
-- caller at a time.
local chunkCurvature = 0

local function chunkLength(): number
	return WorldConfig.Road.ChunkLength
end

-- The frame at arc length t from the chunk's entry seam, in chunk-local
-- space. Travel runs toward -Z, so a straight chunk is just a translation;
-- a curved one integrates a constant yaw rate into a circular arc.
local function arcFrame(t: number, curvature: number): CFrame
	if curvature == 0 then
		return CFrame.new(0, 0, -t)
	end
	local phi = curvature * t
	return CFrame.new((math.cos(phi) - 1) / curvature, 0, -math.sin(phi) / curvature)
		* CFrame.Angles(0, phi, 0)
end

-- Chunk builders were written when every chunk was a straight corridor and
-- placed things relative to the chunk *centre*, so this keeps that meaning:
-- z is measured from the centre and negative z is further along the road.
-- The result follows the chunk's curve, so a hazard 60 studs past the centre
-- of a left-hander lands on the road rather than out in the scenery.
local function spine(x: number, y: number, z: number): CFrame
	return arcFrame(chunkLength() / 2 - z, chunkCurvature) * CFrame.new(x, y, 0)
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

-- A surface running the full length of the chunk. On a straight chunk this
-- is one slab, exactly as it always was. On a curved chunk it becomes a fan
-- of slabs following the arc.
--
-- Consecutive slabs on a curve meet at an angle, which leaves a wedge-shaped
-- hole on the outside of the bend up to halfWidth * tan(delta) long. Each
-- segment is lengthened by more than that so neighbours overlap and the hole
-- cannot exist. The overlap costs nothing visually because curved chunks are
-- always flat (see configureChunk), so overlapping slabs are coplanar and
-- there is no step to trip over.
local function makeStrip(
	chunk: Model,
	name: string,
	width: number,
	thickness: number,
	xOffset: number,
	yOffset: number,
	profile: string,
	color: Color3,
	material: Enum.Material,
	padding: number?
): { Part }
	local extra = padding or 0
	local length = chunkLength()

	if chunkCurvature == 0 then
		return {
			makeSurface(
				chunk,
				name,
				Vector3.new(width, thickness, length + extra),
				spine(xOffset, yOffset, 0),
				profile,
				color,
				material
			),
		}
	end

	local segmentLength = length / CURVE_SEGMENTS
	local deltaAngle = chunkCurvature * segmentLength
	local overlap = width * math.abs(math.tan(deltaAngle)) + 4
	local parts = table.create(CURVE_SEGMENTS)
	for index = 0, CURVE_SEGMENTS - 1 do
		table.insert(
			parts,
			makeSurface(
				chunk,
				string.format("%s_%02d", name, index),
				Vector3.new(width, thickness, segmentLength + overlap + extra),
				arcFrame((index + 0.5) * segmentLength, chunkCurvature)
					* CFrame.new(xOffset, yOffset, 0),
				profile,
				color,
				material
			)
		)
	end
	return parts
end

-- Hard boundaries (canyon walls, guard rails) get the same segmented
-- treatment, minus the surface profile and RoadSurface tag.
local function makeBarrier(
	chunk: Model,
	name: string,
	width: number,
	height: number,
	xOffset: number,
	yOffset: number,
	color: Color3,
	material: Enum.Material
)
	local length = chunkLength()
	local count = if chunkCurvature == 0 then 1 else CURVE_SEGMENTS
	local segmentLength = length / count
	local overlap = if chunkCurvature == 0
		then 0
		else (math.abs(xOffset) * 2 + width) * math.abs(
			math.tan(chunkCurvature * segmentLength / 2)
		) + 4

	for index = 0, count - 1 do
		local barrier = Instance.new("Part")
		barrier.Name = if count == 1 then name else string.format("%s_%02d", name, index)
		barrier.Anchored = true
		barrier.Size = Vector3.new(width, height, segmentLength + overlap)
		barrier.CFrame = arcFrame((index + 0.5) * segmentLength, chunkCurvature)
			* CFrame.new(xOffset, yOffset, 0)
		barrier.Color = color
		barrier.Material = material
		barrier.Parent = chunk
		CollectionService:AddTag(barrier, "RoadHardBoundary")
	end
end

-- Placed in chunk-local space so a boulder field follows the road round a
-- bend, and so its colour and orientation stay identical when the chunk is
-- rebuilt from the same seed - both were previously derived from world Z,
-- which curvature would have made meaningless.
local function addBoulder(chunk: Model, x: number, y: number, z: number, scale: number)
	local boulder = Instance.new("Part")
	boulder.Name = "Boulder"
	boulder.Anchored = true
	boulder.Size = Vector3.new(5.5, 4, 6.5) * scale
	boulder.CFrame = spine(x, y, z)
		* CFrame.Angles(math.rad(12), math.rad((z * 17) % 180), math.rad(8))
	-- Seeded off the boulder's own place in the chunk so a field reads as
	-- mixed rock rather than a row of identical props.
	boulder.Color = variegate(ROAD_COLORS.CanyonRock, z * 0.05 + x, 0.4)
	boulder.Material = Enum.Material.Slate
	boulder.Parent = chunk
	CollectionService:AddTag(boulder, "RoadHardBoundary")
end

local FUEL_PICKUP_AMOUNT = 90

-- Pickups have to be told apart at a glance from a moving vehicle, so each
-- type gets its own colour and silhouette rather than a label nobody can read
-- at 90 studs a second (GDD 15.3).
local PICKUP_STYLES: { [string]: { Color: Color3, Shape: Enum.PartType, Size: Vector3 } } = {
	Fuel = {
		Color = Color3.fromRGB(191, 59, 41),
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3.2, 4, 3.2),
	},
	Bullets = {
		Color = Color3.fromRGB(198, 164, 66),
		Shape = Enum.PartType.Block,
		Size = Vector3.new(4, 2.6, 3),
	},
	Rockets = {
		Color = Color3.fromRGB(96, 108, 150),
		Shape = Enum.PartType.Block,
		Size = Vector3.new(3, 3, 5.4),
	},
	FlameFuel = {
		Color = Color3.fromRGB(214, 118, 38),
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 3.4, 3),
	},
	Throwables = {
		Color = Color3.fromRGB(150, 176, 92),
		Shape = Enum.PartType.Block,
		Size = Vector3.new(3.2, 2.8, 3.2),
	},
	Repair = {
		Color = Color3.fromRGB(228, 228, 222),
		Shape = Enum.PartType.Block,
		Size = Vector3.new(4, 3, 4),
	},
}

local function pickupAmount(pickupType: string): number
	if pickupType == "Fuel" then
		return FUEL_PICKUP_AMOUNT
	elseif pickupType == "Repair" then
		return WeaponConfig.RepairAmount
	end

	local pool = WeaponConfig.AmmoPools[pickupType]
	if not pool then
		error(string.format("No pickup amount defined for %q", pickupType))
	end
	return pool.PickupAmount
end

local function addPickup(chunk: Model, cframe: CFrame, pickupType: string)
	local style = PICKUP_STYLES[pickupType]
	if not style then
		error(string.format("No pickup style defined for %q", pickupType))
	end

	local pickup = Instance.new("Part")
	pickup.Name = pickupType .. "Pickup"
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.Size = style.Size
	pickup.Shape = style.Shape
	pickup.CFrame = if style.Shape == Enum.PartType.Cylinder
		then cframe * CFrame.Angles(0, 0, math.rad(90))
		else cframe
	pickup.Color = style.Color
	pickup.Material = Enum.Material.Metal
	pickup:SetAttribute("PickupType", pickupType)
	pickup:SetAttribute("PickupAmount", pickupAmount(pickupType))
	pickup.Parent = chunk
	CollectionService:AddTag(pickup, "HoonangaPickup")
end

-- Ammunition types rotate rather than being rolled, so a run's supply line is
-- predictable enough to plan around: you can decide to save rockets knowing
-- more will come, instead of hoarding them because they might not.
local AMMO_CYCLE = { "Bullets", "Rockets", "Bullets", "FlameFuel", "Bullets", "Throwables" }

-- The whole supply line for one chunk. Cadence is index-driven rather than
-- random so a seed reproduces the same run (GDD 8.5) and the tests can rely
-- on seeing each pickup type inside the initial chunk count.
--
-- laneX is the chunk's drivable centre line and halfWidth how far either side
-- of it is still road, so a pickup can be offset for interest without ending
-- up in a canyon wall or off a highway deck.
--
-- baseY lifts the whole supply line onto whatever surface the family
-- actually drives on: on the raised highway that is the deck, not the open
-- air 22 studs below it.
local function addChunkPickups(
	chunk: Model,
	index: number,
	laneX: number,
	halfWidth: number,
	baseY: number
)
	local function place(offsetX: number, offsetZ: number, pickupType: string)
		local x = laneX + math.clamp(offsetX, -halfWidth + 4, halfWidth - 4)
		addPickup(chunk, spine(x, baseY + 2.25, offsetZ), pickupType)
	end

	if index % 4 == 3 then
		place(-13, -30, "Fuel")
	end
	if index % 3 == 0 then
		place(11, 60, AMMO_CYCLE[(index // 3) % #AMMO_CYCLE + 1])
	end
	if index % 7 == 5 then
		place(0, 150, "Repair")
	end
end

-- GDD 8.3 sockets. Now that chunks curve, the exit socket is not simply the
-- entry socket pushed along -Z: it carries the heading the next chunk has to
-- start from, which is exactly what socket matching is for.
local function addSockets(chunk: Model)
	local socketStart = Instance.new("Part")
	socketStart.Name = "StartSocket"
	socketStart.Anchored = true
	socketStart.CanCollide = false
	socketStart.CanQuery = false
	socketStart.Transparency = 1
	socketStart.Size = Vector3.one
	socketStart.CFrame = CFrame.identity
	socketStart.Parent = chunk

	local socketEnd = socketStart:Clone()
	socketEnd.Name = "EndSocket"
	socketEnd.CFrame = arcFrame(chunkLength(), chunkCurvature)
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
	name: string,
	profile: string,
	color: Color3,
	material: Enum.Material
)
	makeStrip(
		chunk,
		name,
		WorldConfig.Road.ChunkWidth,
		1,
		0,
		ROAD_Y - 0.55,
		profile,
		variegate(color, index, 0.35),
		material,
		CHUNK_Z_OVERLAP
	)
end

-- Shared layout for the ground-level families: wide drivable terrain with a
-- clear good-ground road down the middle, plus the occasional hazard sitting
-- on that road. Hazard cadence is index-driven rather than random so a run
-- is reproducible and the smoke test can rely on seeing each surface type.
local function addGroundRoad(
	chunk: Model,
	index: number,
	terrainName: string,
	terrainProfile: string,
	terrainColor: Color3,
	terrainMaterial: Enum.Material
)
	addBaseTerrain(chunk, index, terrainName, terrainProfile, terrainColor, terrainMaterial)

	local isAsphalt = index % 4 == 0
	makeStrip(
		chunk,
		if isAsphalt then "AsphaltRoad" else "WornTrack",
		ROAD_SURFACE_WIDTH,
		0.25,
		0,
		0.08,
		if isAsphalt then "Asphalt" else "WornDirt",
		if isAsphalt then ROAD_COLORS.Asphalt else variegate(ROAD_COLORS.WornDirt, index * 3, 0.22),
		if isAsphalt then Enum.Material.Asphalt else Enum.Material.Ground
	)

	if index % 3 == 1 then
		local mud = makeSurface(
			chunk,
			"MudPatch",
			MUD_PATCH_SIZE,
			spine(-8, 0.24, -60),
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
			spine(7, 0.29, 40),
			"Oil",
			ROAD_COLORS.Oil,
			Enum.Material.SmoothPlastic
		)
		oil.Transparency = 0.12
		oil:SetAttribute("HazardType", "Oil")
	end

	addChunkPickups(chunk, index, 0, ROAD_SURFACE_WIDTH / 2 + 12, 0)

	chunk:SetAttribute("PreferredLaneX", 0)
end

-- Open stony plain: the road threads between scattered boulder fields that
-- are hard boundaries, so leaving the road is possible but has to be picked
-- carefully rather than driven blindly.
local function configureBoulderPlainChunk(chunk: Model, index: number)
	addGroundRoad(
		chunk,
		index,
		"LooseStone",
		"LooseStone",
		ROAD_COLORS.LooseStone,
		Enum.Material.Slate
	)

	local edge = WorldConfig.Road.ChunkWidth / 2
	local roadEdge = ROAD_SURFACE_WIDTH / 2
	for _, side in { -1, 1 } do
		for cluster = 0, 2 do
			-- Spread across the runoff, never onto the road itself.
			local spread = roadEdge
				+ 14
				+ ((index * 37 + cluster * 53) % math.max(1, edge - roadEdge - 20))
			addBoulder(
				chunk,
				side * spread,
				1.6,
				-180 + cluster * 160 + side * 24,
				0.7 + ((index + cluster) % 3) * 0.2
			)
		end
	end
end

-- Open sand: fewer obstacles and longer sightlines than the boulder plain,
-- but the runoff is soft (low grip, mild bogging) so pushing wide to cut a
-- corner costs speed.
local function configureSandyDesertChunk(chunk: Model, index: number)
	-- Alternating stretches of orange sand and bleached salt pan, so a desert
	-- run reads as varied country rather than one endless tone. The salt is
	-- also the one fast off-road surface, which changes how the section plays
	-- and not just how it looks.
	-- Salt flats are flat: a graded or cambered run stays all sand. A curved
	-- chunk is always laid flat (see configureChunk), so bends are eligible
	-- whatever grade the rest of the run is driving at.
	local isFlatHere = chunkCurvature ~= 0 or (runPitch == 0 and runRoll == 0)
	local isSaltPan = (index // 2) % 2 == 1 and isFlatHere
	if isSaltPan then
		addGroundRoad(chunk, index, "SaltPan", "SaltPan", ROAD_COLORS.SaltPan, Enum.Material.Salt)
	else
		addGroundRoad(chunk, index, "SandFlat", "Sand", ROAD_COLORS.Sand, Enum.Material.Sand)
	end

	local side = if index % 2 == 0 then -1 else 1
	addBoulder(chunk, side * (ROAD_SURFACE_WIDTH / 2 + 30), 1.4, -60, 0.6 + (index % 3) * 0.2)
end

-- Narrow choke-point corridor with real wall collision geometry (GDD 9.2):
-- hitting a wall at speed triggers CollisionDamageService's existing
-- RoadHardBoundary impact handling, the same mechanism boulders already use.
local function configureCanyonChunk(chunk: Model, index: number)
	-- Rock shelf running the full chunk width, so the ground outside the
	-- canyon walls is solid. The walls are the boundary, not a cliff edge.
	addBaseTerrain(
		chunk,
		index,
		"CanyonShelf",
		"LooseStone",
		ROAD_COLORS.CanyonRock,
		Enum.Material.Rock
	)

	makeStrip(
		chunk,
		"CanyonFloor",
		CANYON_WIDTH,
		1,
		0,
		-0.4,
		"WornDirt",
		variegate(ROAD_COLORS.WornDirt, index * 5, 0.2),
		Enum.Material.Ground
	)

	for _, side in { -1, 1 } do
		makeBarrier(
			chunk,
			"CanyonWall",
			16,
			CANYON_WALL_HEIGHT,
			side * (CANYON_WIDTH / 2 + 8),
			CANYON_WALL_HEIGHT / 2 - 3,
			-- Each wall shifted independently so a canyon has banded strata
			-- rather than two flat slabs of identical colour.
			variegate(ROAD_COLORS.CanyonRock, index * 2 + side, 0.42),
			Enum.Material.Rock
		)
	end

	-- A boulder pinched toward one side per chunk, alternating, for a mild
	-- slalom (GDD 9.2 "fallen boulder slalom") without fully blocking the
	-- narrow corridor.
	local pinchSide = if index % 2 == 0 then -1 else 1
	addBoulder(chunk, pinchSide * (CANYON_WIDTH / 2 - 6), 1.8, 0, 0.85)

	addChunkPickups(chunk, index, 0, CANYON_WIDTH / 2, 0)

	chunk:SetAttribute("PreferredLaneX", 0)
end

-- Elevated straight with an exposed edge (GDD 9.1): the road is a floating
-- strip with nothing beneath it off to the sides, so driving (or being
-- rammed) off either edge is a genuine fall - CollisionDamageService's
-- existing fall handling already destroys a vehicle that drops far enough,
-- no new fall-detection code needed here. The guard rail is deliberately
-- missing on one side each chunk ("missing outer barrier" from the chunk
-- idea list) so the exposure is asymmetric.
local function configureHighwayChunk(chunk: Model, index: number)
	local deckParts = makeStrip(
		chunk,
		"HighwayDeck",
		HIGHWAY_WIDTH,
		1.4,
		0,
		HIGHWAY_RISE,
		"Asphalt",
		ROAD_COLORS.Asphalt,
		Enum.Material.Asphalt
	)
	for _, deck in deckParts do
		-- The visual horizon belongs at desert-ground height. Treating this
		-- elevated deck as ground raises the client-side desert plane until it
		-- sits just beneath the bridge, making the intended fall disappear.
		deck:SetAttribute("HorizonGround", false)
	end

	local railedSide = if index % 2 == 0 then -1 else 1
	makeBarrier(
		chunk,
		"HighwayGuardRail",
		1.6,
		HIGHWAY_RAIL_HEIGHT,
		railedSide * (HIGHWAY_WIDTH / 2 - 0.8),
		HIGHWAY_RISE + HIGHWAY_RAIL_HEIGHT / 2 + 0.7,
		Color3.fromRGB(150, 150, 145),
		Enum.Material.Metal
	)

	addChunkPickups(chunk, index, 0, HIGHWAY_WIDTH / 2, HIGHWAY_RISE)

	chunk:SetAttribute("PreferredLaneX", 0)
end

-- A gentle sloped deck bridging the ground and the elevated deck at the
-- start/end of every highway run (GDD 8.3: "vertical changes remain gentle
-- enough for vehicle suspension unless the chunk is intentionally a ramp").
-- Travel runs from the chunk's entry seam at local origin to its exit one
-- chunk-length along, so ramping up means the far end is elevated and
-- ramping down means the near end still is.
local function configureHighwayRampChunk(chunk: Model, rampingUp: boolean)
	local length = chunkLength()
	local startPos = Vector3.new(0, if rampingUp then 0 else HIGHWAY_RISE, 0)
	local endPos = Vector3.new(0, if rampingUp then HIGHWAY_RISE else 0, -length)
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
	ramp:SetAttribute("HorizonGround", false)
	ramp.Parent = chunk
	CollectionService:AddTag(ramp, "RoadSurface")

	chunk:SetAttribute("PreferredLaneX", 0)
end

-- A genuine mudflat biome (GDD 9.3), distinct from the small mud patches
-- that sit on the ordinary road: here the mud is the terrain and the good
-- ground is a firm path threaded through it, so the route-reading is the
-- point. Weighted low so crossing one is an occasional event rather than
-- the default texture of a run.
local function configureMudflatChunk(chunk: Model, index: number)
	local pathOffset = if index % 2 == 0 then -16 else 16

	makeStrip(
		chunk,
		"MudExpanse",
		WorldConfig.Road.ChunkWidth,
		1,
		0,
		-0.5,
		"Mud",
		variegate(ROAD_COLORS.Mud, index, 0.25),
		Enum.Material.Mud,
		CHUNK_Z_OVERLAP
	)

	makeStrip(
		chunk,
		"FirmPath",
		ROAD_SURFACE_WIDTH,
		0.22,
		pathOffset,
		0.05,
		"WornDirt",
		variegate(ROAD_COLORS.WornDirt, index * 3, 0.22),
		Enum.Material.Ground
	)

	addChunkPickups(chunk, index, pathOffset, ROAD_SURFACE_WIDTH / 2, 0)

	chunk:SetAttribute("PreferredLaneX", pathOffset)
end

-- Left lane trades grip for a fuel pickup, right lane keeps normal grip and
-- offers nothing - a direct instance of GDD 8.7's example tradeoff ("exposed
-- highway with fuel versus protected canyon without fuel").
local function configureForkChunk(chunk: Model, index: number)
	local laneOffset = FORK_LANE_WIDTH / 2 + 10

	-- Solid ground under the whole chunk. The lanes and the boulder divider
	-- sit on top of it: the divider should make you commit to a side, not
	-- open a pit down the centre line you were already driving along.
	addBaseTerrain(
		chunk,
		index,
		"ForkGround",
		"LooseStone",
		ROAD_COLORS.LooseStone,
		Enum.Material.Slate
	)

	local leftLane = makeStrip(
		chunk,
		"ForkLaneLeft",
		FORK_LANE_WIDTH,
		0.9,
		-laneOffset,
		-0.4,
		"Mud",
		ROAD_COLORS.Mud,
		Enum.Material.Mud
	)
	for _, lane in leftLane do
		lane:SetAttribute("HazardType", "Mud")
	end
	-- The fork's fuel is unconditional and sits in the mud lane: it is the
	-- tradeoff the whole chunk exists for, not part of the ordinary cadence.
	addPickup(chunk, spine(-laneOffset, 2.25, 0), "Fuel")

	makeStrip(
		chunk,
		"ForkLaneRight",
		FORK_LANE_WIDTH,
		1,
		laneOffset,
		-0.55,
		"LooseStone",
		ROAD_COLORS.LooseStone,
		Enum.Material.Slate
	)

	for offsetZ = -1, 1 do
		addBoulder(chunk, 0, 2, offsetZ * 150, 0.9)
	end

	addChunkPickups(chunk, index, laneOffset, FORK_LANE_WIDTH / 2, 0)

	-- Steer AI toward the predictable right lane rather than the boulder
	-- divider it would otherwise drive straight at.
	chunk:SetAttribute("PreferredLaneX", laneOffset)
end

-- Decides this chunk's curve. Returns the total turn in radians.
--
-- The highway and the fork opt out: the highway's deck, ramps and rails are
-- built from absolute heights and would need their own arc treatment, and
-- the fork's whole point is two parallel lanes with a boulder line between
-- them. Everything else can bend, so roughly a quarter of ordinary chunks
-- curve.
local function pickCurve(family: string): number
	if family == "RaisedHighway" or family == "Fork" then
		return 0
	end
	if directorRandom:NextNumber() > CURVE_CHANCE then
		return 0
	end

	local totalWeight = 0
	for _, kind in CURVE_KINDS do
		totalWeight += kind.Weight
	end

	local roll = directorRandom:NextNumber() * totalWeight
	local chosen = CURVE_KINDS[#CURVE_KINDS]
	for _, kind in CURVE_KINDS do
		roll -= kind.Weight
		if roll <= 0 then
			chosen = kind
			break
		end
	end

	local sign = if directorRandom:NextNumber() < CURVE_OPPOSITE_CHANCE
		then -lastCurveSign
		else lastCurveSign
	lastCurveSign = sign

	local degrees = directorRandom:NextNumber(chosen.MinDegrees, chosen.MaxDegrees)
	return math.rad(degrees) * sign
end

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

-- Decides what this chunk is, without building anything. Split from the
-- build because curvature has to be chosen before any geometry is laid (it
-- changes how every strip in the chunk is placed) and whether a chunk may
-- curve at all depends on which family it turned out to be. Peeking at
-- currentFamily instead would be wrong precisely at a run boundary, where
-- the next chunk is the first of a new family - which is exactly where a
-- highway ramp appears.
local function decideChunk(): (string, boolean, boolean)
	if chunksUntilFork <= 0 and currentFamily ~= "RaisedHighway" then
		-- A fork mid-highway-run would sit at ground level between deck
		-- chunks - the same cliff problem the ramp chunks exist to avoid.
		-- currentFamily still reads "RaisedHighway" for every chunk of an
		-- in-progress run right up until pickNextFamily next advances it, so
		-- this defers the fork rather than dropping it into the middle of
		-- the highway.
		chunksUntilFork = directorRandom:NextInteger(FORK_MIN_INTERVAL, FORK_MAX_INTERVAL)
		return "Fork", false, false
	end

	if chunksUntilFork > 0 then
		chunksUntilFork -= 1
	end
	return pickNextFamily()
end

local function buildChunkGeometry(
	chunk: Model,
	index: number,
	family: string,
	isFirstOfRun: boolean,
	isLastOfRun: boolean
)
	if family == "Fork" then
		configureForkChunk(chunk, index)
	elseif family == "Canyon" then
		configureCanyonChunk(chunk, index)
	elseif family == "SandyDesert" then
		configureSandyDesertChunk(chunk, index)
	elseif family == "Mudflat" then
		configureMudflatChunk(chunk, index)
	elseif family == "RaisedHighway" then
		if isFirstOfRun then
			configureHighwayRampChunk(chunk, true)
		elseif isLastOfRun then
			configureHighwayRampChunk(chunk, false)
		else
			configureHighwayChunk(chunk, index)
		end
	else
		configureBoulderPlainChunk(chunk, index)
	end
end

local function configureChunk(chunk: Model, index: number): ChunkRecord
	local length = chunkLength()
	chunk.Name = string.format("Chunk_%04d", index)
	chunk:SetAttribute("ChunkIndex", index)

	local family, isFirstOfRun, isLastOfRun = decideChunk()
	local biome = EnvironmentConfig.Biomes[family] or EnvironmentConfig.Biomes.BoulderPlain
	chunk:SetAttribute("EnvironmentBiome", biome.Name)
	-- Spawn positions are authored in world space inside chunk zero. Keeping
	-- the opening chunk straight guarantees those positions remain on the
	-- road and prevents the first input a player makes from being a ninety.
	chunkCurvature = if index == 0 then 0 else pickCurve(family) / length
	buildChunkGeometry(chunk, index, family, isFirstOfRun, isLastOfRun)

	-- A curved chunk is always flat. Pitch and roll are applied to the chunk
	-- as a rigid body about its entry seam, so on a chunk whose far end has
	-- swung ninety degrees they would arrive there as roll and pitch
	-- respectively - the grade would twist along the bend and step the
	-- surface between segments. Keeping bends flat also spares the player
	-- from taking a ninety on camber.
	local pitch, roll = runPitch, runRoll
	if chunkCurvature ~= 0 or family == "RaisedHighway" then
		pitch, roll = 0, 0
	end

	if pitch ~= 0 then
		-- Keep the running elevation inside its band. Level off on reaching
		-- the limit rather than reversing the grade: flipping the sign made
		-- the road sawtooth up and down every chunk once it saturated,
		-- which reads as a ramp field rather than rolling country.
		local projected = pathPosition.Y + math.sin(pitch) * length
		if projected > MAX_ELEVATION or projected < MIN_ELEVATION then
			local limit = if projected > MAX_ELEVATION then MAX_ELEVATION else MIN_ELEVATION
			pitch = math.asin(math.clamp((limit - pathPosition.Y) / length, -1, 1))
			runPitch = 0
		end
	end

	local entryCFrame = CFrame.new(pathPosition) * CFrame.Angles(0, pathYaw, 0)
	local placement = entryCFrame * CFrame.Angles(pitch, 0, roll)
	chunk.WorldPivot = CFrame.identity
	chunk:PivotTo(placement)

	local curveAngle = chunkCurvature * length
	local exitCFrame = placement * arcFrame(length, chunkCurvature)

	local frames = table.create(SPINE_SAMPLES + 1)
	local distances = table.create(SPINE_SAMPLES + 1)
	for sample = 0, SPINE_SAMPLES do
		local t = length * sample / SPINE_SAMPLES
		table.insert(frames, placement * arcFrame(t, chunkCurvature))
		table.insert(distances, pathDistance + t)
	end

	local laneX = chunk:GetAttribute("PreferredLaneX")
	if typeof(laneX) ~= "number" then
		error(string.format("chunk %d did not publish a PreferredLaneX", index))
	end

	local record: ChunkRecord = {
		Index = index,
		Model = chunk,
		EntryCFrame = entryCFrame,
		ExitCFrame = exitCFrame,
		Curvature = chunkCurvature,
		PathDistance = pathDistance,
		LaneX = laneX,
		Frames = frames,
		Distances = distances,
	}

	-- GDD 8.2 chunk metadata. EntryHeading and ExitHeading are real now: they
	-- are the compass headings a chunk has to be entered and left on, which
	-- is what socket matching checks.
	local familyInfo = FAMILY_BY_NAME[family]
	chunk:SetAttribute("RoadFamily", family)
	chunk:SetAttribute("ChunkId", string.format("%s_%04d", family, index))
	chunk:SetAttribute("Length", length)
	chunk:SetAttribute("EntryHeading", math.deg(pathYaw))
	chunk:SetAttribute("ExitHeading", math.deg(pathYaw + curveAngle))
	chunk:SetAttribute("CurveDegrees", math.deg(curveAngle))
	chunk:SetAttribute("PathDistance", pathDistance)
	chunk:SetAttribute("EntryCFrame", entryCFrame)
	chunk:SetAttribute("ExitCFrame", exitCFrame)
	chunk:SetAttribute("GroundEntryY", pathPosition.Y)
	chunk:SetAttribute("GroundExitY", exitCFrame.Position.Y)
	chunk:SetAttribute("Difficulty", if familyInfo then familyInfo.Difficulty else 2)
	chunk:SetAttribute("MinSpeed", if familyInfo then familyInfo.MinSpeed else 0)
	chunk:SetAttribute("MaxActiveEnemies", if familyInfo then familyInfo.MaxActiveEnemies else 2)
	chunk:SetAttribute("AllowsFork", if familyInfo then familyInfo.AllowsFork else true)
	chunk:SetAttribute("Weight", if familyInfo then familyInfo.Weight else 0)
	local formationHalfWidth = if family == "Canyon"
		then 9
		elseif family == "Highway" or family == "Fork" then 12
		elseif family == "Mudflat" then 14
		else 18
	chunk:SetAttribute("FormationHalfWidth", formationHalfWidth)

	addSockets(chunk)

	-- Advance the running path frame so the next chunk starts exactly where
	-- this one finished, pointing the way this one ended up pointing.
	pathPosition = exitCFrame.Position
	pathYaw += curveAngle
	pathDistance += length

	return record
end

local function createChunk(index: number): ChunkRecord
	local model = Instance.new("Model")
	-- GDD 8.4 lifecycle. Reserved covers the window where the director has
	-- committed to a chunk but its geometry does not exist yet; Placed means
	-- built and positioned; Active means it is part of the live road.
	model:SetAttribute("LifecycleState", "Reserved")
	model.Parent = chunkFolder
	local record = configureChunk(model, index)
	model:SetAttribute("LifecycleState", "Placed")
	model:SetAttribute("Occupancy", 0)
	model:SetAttribute("LifecycleState", "Active")
	return record
end

local RoadService = {}

export type PathLocation = {
	Record: ChunkRecord,
	Distance: number,
	Lateral: number,
}

-- Where a world position sits on the road. Distance is arc length from the
-- start of the run - the curved-road replacement for "how far down -Z are
-- you" - and Lateral is how far off the centre line it is.
--
-- Measured against each chunk's stored spine polyline rather than solved
-- analytically from the arc. The polyline is exact at the sample points and
-- negligibly off between them, and it keeps working unchanged if a future
-- chunk shape is not a constant-radius arc.
function RoadService.LocateOnPath(position: Vector3): PathLocation?
	local best: PathLocation? = nil
	local bestSquared = math.huge

	for _, record in chunks do
		local frames = record.Frames
		for sample = 1, #frames - 1 do
			local a = frames[sample].Position
			local b = frames[sample + 1].Position
			local segment = b - a
			local lengthSquared = segment:Dot(segment)
			if lengthSquared <= 0 then
				continue
			end

			local alpha = math.clamp((position - a):Dot(segment) / lengthSquared, 0, 1)
			local closest = a + segment * alpha
			local offset = position - closest
			local squared = offset:Dot(offset)
			if squared < bestSquared then
				bestSquared = squared
				local distanceA = record.Distances[sample]
				local distanceB = record.Distances[sample + 1]
				best = {
					Record = record,
					Distance = distanceA + (distanceB - distanceA) * alpha,
					Lateral = math.sqrt(squared),
				}
			end
		end
	end

	return best
end

function RoadService.GetProgress(position: Vector3): number
	local location = RoadService.LocateOnPath(position)
	return if location then location.Distance else 0
end

-- The point on the drivable line a given distance further along the road.
-- This is what lets the AI follow a bend instead of driving straight off the
-- outside of it: it asks where the road will be, not where -Z is.
function RoadService.GetLaneTarget(position: Vector3, lookAhead: number): Vector3?
	local location = RoadService.LocateOnPath(position)
	if not location then
		return nil
	end

	local target = location.Distance + lookAhead
	local first = chunks[1]
	if first and target <= first.Distances[1] then
		return (first.Frames[1] * CFrame.new(first.LaneX, 0, 0)).Position
	end
	for _, record in chunks do
		local distances = record.Distances
		if target < distances[1] or target > distances[#distances] then
			continue
		end
		for sample = 1, #distances - 1 do
			if target <= distances[sample + 1] then
				local span = distances[sample + 1] - distances[sample]
				local alpha = if span > 0 then (target - distances[sample]) / span else 0
				local frame = record.Frames[sample]:Lerp(record.Frames[sample + 1], alpha)
				return (frame * CFrame.new(record.LaneX, 0, 0)).Position
			end
		end
	end

	-- Past the end of the generated road: aim straight off the last chunk's
	-- exit rather than returning nothing, so a vehicle that outruns the
	-- generator still has something to steer at.
	local last = chunks[#chunks]
	if not last then
		return nil
	end
	return (last.ExitCFrame * CFrame.new(last.LaneX, 0, -lookAhead)).Position
end

-- Resolves an absolute path distance and lateral formation offset. Formation
-- followers use this instead of chasing a world-space point behind the
-- leader, so they take the same curved spine and chosen fork.
function RoadService.GetPathTarget(distance: number, lateral: number): Vector3?
	local first = chunks[1]
	if first and distance <= first.Distances[1] then
		return (first.Frames[1] * CFrame.new(first.LaneX + lateral, 0, 0)).Position
	end
	for _, record in chunks do
		local distances = record.Distances
		if distance < distances[1] or distance > distances[#distances] then
			continue
		end
		for sample = 1, #distances - 1 do
			if distance <= distances[sample + 1] then
				local span = distances[sample + 1] - distances[sample]
				local alpha = if span > 0 then (distance - distances[sample]) / span else 0
				local frame = record.Frames[sample]:Lerp(record.Frames[sample + 1], alpha)
				return (frame * CFrame.new(record.LaneX + lateral, 0, 0)).Position
			end
		end
	end
	local last = chunks[#chunks]
	if not last then
		return nil
	end
	local beyond = math.max(0, distance - last.Distances[#last.Distances])
	return (last.ExitCFrame * CFrame.new(last.LaneX + lateral, 0, -beyond)).Position
end

function RoadService.GetChunkAt(position: Vector3): Model?
	local location = RoadService.LocateOnPath(position)
	return if location then location.Record.Model else nil
end

-- Counts vehicles physically standing inside each chunk, keyed by chunk
-- index, and publishes each one's progress for the HUD while it is at it.
-- This is the safety net the distance heuristic cannot provide: it is about
-- where things actually *are*, so nothing can have the road deleted out from
-- under it even if the progress rule says the chunk is long past.
local function countOccupancy(): ({ [number]: number }, number?)
	local occupancy = {}
	local slowestPlayer: number? = nil

	for _, vehicle in CollectionService:GetTagged("HoonangaVehicle") do
		if
			not vehicle:IsA("Model")
			or not vehicle.PrimaryPart
			or vehicle:GetAttribute("Destroyed")
			or vehicle:GetAttribute("Operational") == false
		then
			continue
		end

		local location = RoadService.LocateOnPath(vehicle.PrimaryPart.Position)
		if not location then
			continue
		end

		occupancy[location.Record.Index] = (occupancy[location.Record.Index] or 0) + 1
		vehicle:SetAttribute("RunDistance", location.Distance)
		local convoy = ConvoyService.GetByVehicle(vehicle)
		if convoy then
			ConvoyService.SetRunDistance(convoy, location.Distance)
			local owner = if convoy.OwnerUserId > 0
				then Players:GetPlayerByUserId(convoy.OwnerUserId)
				else nil
			if owner then
				owner:SetAttribute("RunDistance", convoy.RunDistance)
			end
		end
		if
			vehicle:GetAttribute("Faction") == "Player"
			or vehicle:GetAttribute("Team") == "Player"
		then
			slowestPlayer = if slowestPlayer
				then math.min(slowestPlayer, location.Distance)
				else location.Distance
		end
	end

	return occupancy, slowestPlayer
end

local function recyclePassedChunks()
	local road = WorldConfig.Road
	local occupancy, slowestPlayer = countOccupancy()
	local progress = slowestPlayer or 0
	table.sort(chunks, function(a, b)
		return a.Index < b.Index
	end)

	for _, record in chunks do
		local occupants = occupancy[record.Index] or 0
		record.Model:SetAttribute("Occupancy", occupants)
		-- Passed: the road behind everyone, still standing but no longer
		-- carrying anything. Chunks flip back to Active if someone doubles
		-- back into them, which is reachable now that the terrain is wide
		-- enough to turn around in.
		if record.Model:GetAttribute("LifecycleState") ~= "Reserved" then
			local chunkEnd = record.PathDistance + road.ChunkLength
			record.Model:SetAttribute(
				"LifecycleState",
				if occupants == 0 and progress > chunkEnd then "Passed" else "Active"
			)
		end
	end

	while #chunks > 0 do
		local first = chunks[1]
		local chunkEndProgress = first.PathDistance + road.ChunkLength
		if progress - chunkEndProgress < road.RecycleDistance then
			break
		end
		-- Never pull the road out from under anything, whatever the
		-- distance rule says.
		if (occupancy[first.Index] or 0) > 0 then
			break
		end

		table.remove(chunks, 1)
		first.Model:SetAttribute("LifecycleState", "Retired")
		first.Model:Destroy()
		local replacement = createChunk(nextChunkIndex)
		nextChunkIndex += 1
		table.insert(chunks, replacement)
	end
end

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

	chunks = {}
	-- Every run opens on a stretch of boulder plain: forgiving terrain with
	-- clear sightlines, per the design doc's pressure curve (GDD 4.3).
	currentFamily = "BoulderPlain"
	remainingInFamily = directorRandom:NextInteger(4, 8)
	familyCooldowns = {}
	-- The opening stretch is flat, level and dead straight, so the spawn area
	-- is predictable and the first thing a player does is not a ninety.
	pathPosition = Vector3.new(0, ROAD_Y, WorldConfig.Road.ChunkLength / 2)
	pathYaw = 0
	pathDistance = 0
	runPitch = 0
	runRoll = 0
	lastCurveSign = if directorRandom:NextNumber() < 0.5 then -1 else 1
	chunkCurvature = 0
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
