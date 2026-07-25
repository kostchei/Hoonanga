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
local ROAD_COLORS = {
	Asphalt = Color3.fromRGB(72, 70, 66),
	WornDirt = Color3.fromRGB(125, 92, 58),
	LooseStone = Color3.fromRGB(151, 119, 80),
	Mud = Color3.fromRGB(78, 61, 43),
	Oil = Color3.fromRGB(25, 24, 21),
	CanyonRock = Color3.fromRGB(96, 80, 66),
}

-- Road families cycle in runs of 4-8 chunks (GDD 8.6) rather than the whole
-- road being one family forever, both for driving variety and to mitigate
-- the "procedural repetition" risk (GDD 26). True per-chunk curvature isn't
-- implemented yet - every chunk is still a straight corridor along Z - so
-- families are differentiated by width, surface, and hazards rather than
-- path shape for now.
local ROAD_FAMILIES = { "StonyDesert", "Canyon", "Mudflat", "RaisedHighway" }
local CANYON_WIDTH = 34
local CANYON_WALL_HEIGHT = 60
local HIGHWAY_WIDTH = 44
local HIGHWAY_Y = 22
local HIGHWAY_RAIL_HEIGHT = 3.4

-- A fork is one wide chunk split into two parallel, differently-hazarded
-- lanes with a boulder line down the middle forcing the player to commit to
-- one side, rather than GDD 8.7's full multi-chunk diverge/reconverge
-- branch geometry - that needs a chunk heading/curvature system this
-- service doesn't have yet. This still delivers the actual design goal (a
-- real route choice with a real tradeoff) with the existing straight-corridor
-- chunk model, and reconverges trivially since the lanes never physically
-- separated.
local FORK_LANE_WIDTH = 38
local FORK_MIN_INTERVAL = 6
local FORK_MAX_INTERVAL = 10

local chunks: { ChunkRecord } = {}
local chunkFolder: Folder
local nextChunkIndex = 0
local running = false
local currentFamily = "StonyDesert"
local remainingInFamily = 0
local chunksUntilFork = 0

-- isFirstOfRun/isLastOfRun let RaisedHighway bracket itself with ramp
-- chunks: every other family sits at ROAD_Y, but the highway deck sits 22
-- studs up, so a bare family transition would leave the road ending in a
-- sheer cliff instead of a drivable slope.
local function pickNextFamily(): (string, boolean, boolean)
	local isFirstOfRun = false
	if remainingInFamily <= 0 then
		local candidates = {}
		for _, family in ROAD_FAMILIES do
			if family ~= currentFamily then
				table.insert(candidates, family)
			end
		end

		currentFamily = candidates[math.random(1, #candidates)]
		remainingInFamily = math.random(4, 8)
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
	boulder.Color = Color3.fromRGB(103, 78, 56)
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

local function configureStonyDesertChunk(chunk: Model, index: number, centerZ: number)
	local road = WorldConfig.Road
	local center = CFrame.new(0, ROAD_Y, centerZ)
	local variant = index % 4
	local isAsphalt = variant == 0

	makeSurface(
		chunk,
		"LooseStone",
		Vector3.new(road.ChunkWidth, 1, road.ChunkLength),
		center * CFrame.new(0, -0.55, 0),
		"LooseStone",
		ROAD_COLORS.LooseStone,
		Enum.Material.Slate
	)

	makeSurface(
		chunk,
		if isAsphalt then "AsphaltRoad" else "WornTrack",
		Vector3.new(48, 0.25, road.ChunkLength),
		center * CFrame.new(0, 0.08, 0),
		if isAsphalt then "Asphalt" else "WornDirt",
		if isAsphalt then ROAD_COLORS.Asphalt else ROAD_COLORS.WornDirt,
		if isAsphalt then Enum.Material.Asphalt else Enum.Material.Ground
	)

	if variant == 1 then
		local mud = makeSurface(
			chunk,
			"MudPatch",
			Vector3.new(28, 0.18, 90),
			center * CFrame.new(-7, 0.24, -40),
			"Mud",
			ROAD_COLORS.Mud,
			Enum.Material.Mud
		)
		mud:SetAttribute("HazardType", "Mud")
	elseif variant == 2 then
		local oil = makeSurface(
			chunk,
			"OilSlick",
			Vector3.new(18, 0.08, 52),
			center * CFrame.new(8, 0.29, -15),
			"Oil",
			ROAD_COLORS.Oil,
			Enum.Material.SmoothPlastic
		)
		oil.Transparency = 0.12
		oil:SetAttribute("HazardType", "Oil")
	elseif variant == 3 then
		addFuelPickup(chunk, center * CFrame.new(-13, 2.25, -30))
	end

	for _, side in { -1, 1 } do
		local baseX = side * (road.ChunkWidth / 2 - 8)
		addBoulder(
			chunk,
			Vector3.new(baseX, 1.6, centerZ - 120 + side * 32),
			0.7 + (index % 3) * 0.15
		)
		addBoulder(chunk, Vector3.new(baseX - side * 7, 1.2, centerZ + 145 - side * 18), 0.55)
	end

	chunk:SetAttribute("PreferredLaneX", 0)
end

-- Narrow choke-point corridor with real wall collision geometry (GDD 9.2):
-- hitting a wall at speed triggers CollisionDamageService's existing
-- RoadHardBoundary impact handling, the same mechanism boulders already use.
local function configureCanyonChunk(chunk: Model, index: number, centerZ: number)
	local road = WorldConfig.Road
	local center = CFrame.new(0, ROAD_Y, centerZ)

	makeSurface(
		chunk,
		"CanyonFloor",
		Vector3.new(CANYON_WIDTH, 1, road.ChunkLength),
		center * CFrame.new(0, -0.4, 0),
		"WornDirt",
		ROAD_COLORS.WornDirt,
		Enum.Material.Ground
	)

	for _, side in { -1, 1 } do
		local wall = Instance.new("Part")
		wall.Name = "CanyonWall"
		wall.Anchored = true
		wall.Size = Vector3.new(16, CANYON_WALL_HEIGHT, road.ChunkLength)
		wall.CFrame = center
			* CFrame.new(side * (CANYON_WIDTH / 2 + 8), CANYON_WALL_HEIGHT / 2 - 3, 0)
		wall.Color = ROAD_COLORS.CanyonRock
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
local function configureHighwayChunk(chunk: Model, index: number, centerZ: number)
	local road = WorldConfig.Road
	local center = CFrame.new(0, HIGHWAY_Y, centerZ)

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

-- A gentle sloped deck bridging ROAD_Y and HIGHWAY_Y at the start/end of
-- every highway run (GDD 8.3: "vertical changes remain gentle enough for
-- vehicle suspension unless the chunk is intentionally a ramp"). Travel
-- runs from a chunk's StartSocket (higher Z) to its EndSocket (lower Z), so
-- ramping up means low-Z-side is elevated and ramping down means
-- high-Z-side still is.
local function configureHighwayRampChunk(chunk: Model, centerZ: number, rampingUp: boolean)
	local road = WorldConfig.Road
	local startY = if rampingUp then ROAD_Y else HIGHWAY_Y
	local endY = if rampingUp then HIGHWAY_Y else ROAD_Y
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

-- Wide, mostly-mud expanse with a firmer path threaded through it (GDD 9.3):
-- straying off the path costs grip and builds BogLevel through the existing
-- VehiclePhysics surface-profile handling, no new physics code needed.
local function configureMudflatChunk(chunk: Model, index: number, centerZ: number)
	local road = WorldConfig.Road
	local center = CFrame.new(0, ROAD_Y, centerZ)
	local pathOffset = if index % 2 == 0 then -18 else 18

	makeSurface(
		chunk,
		"MudExpanse",
		Vector3.new(road.ChunkWidth, 1, road.ChunkLength),
		center * CFrame.new(0, -0.5, 0),
		"Mud",
		ROAD_COLORS.Mud,
		Enum.Material.Mud
	)

	makeSurface(
		chunk,
		"FirmPath",
		Vector3.new(22, 0.22, road.ChunkLength),
		center * CFrame.new(pathOffset, 0.05, 0),
		"WornDirt",
		ROAD_COLORS.WornDirt,
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
local function configureForkChunk(chunk: Model, centerZ: number)
	local center = CFrame.new(0, ROAD_Y, centerZ)
	local laneOffset = FORK_LANE_WIDTH / 2 + 10

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

local function configureChunk(chunk: Model, index: number)
	local road = WorldConfig.Road
	local centerZ = -(index * road.ChunkLength)
	chunk.Name = string.format("Chunk_%04d", index)
	chunk:SetAttribute("ChunkIndex", index)

	-- A fork mid-highway-run would sit at ROAD_Y between HIGHWAY_Y chunks -
	-- the same cliff problem the ramp chunks exist to avoid. currentFamily
	-- still reads "RaisedHighway" for every chunk of an in-progress run
	-- right up until pickNextFamily next advances it, so this defers the
	-- fork rather than dropping it into the middle of the highway.
	if chunksUntilFork <= 0 and currentFamily ~= "RaisedHighway" then
		chunksUntilFork = math.random(FORK_MIN_INTERVAL, FORK_MAX_INTERVAL)
		chunk:SetAttribute("RoadFamily", "Fork")
		configureForkChunk(chunk, centerZ)
	else
		if chunksUntilFork > 0 then
			chunksUntilFork -= 1
		end
		local family, isFirstOfRun, isLastOfRun = pickNextFamily()
		chunk:SetAttribute("RoadFamily", family)
		if family == "Canyon" then
			configureCanyonChunk(chunk, index, centerZ)
		elseif family == "Mudflat" then
			configureMudflatChunk(chunk, index, centerZ)
		elseif family == "RaisedHighway" then
			if isFirstOfRun then
				configureHighwayRampChunk(chunk, centerZ, true)
			elseif isLastOfRun then
				configureHighwayRampChunk(chunk, centerZ, false)
			else
				configureHighwayChunk(chunk, index, centerZ)
			end
		else
			configureStonyDesertChunk(chunk, index, centerZ)
		end
	end

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

function RoadService.Start()
	if running then
		return
	end
	running = true

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
	currentFamily = "StonyDesert"
	remainingInFamily = math.random(4, 8)
	chunksUntilFork = math.random(FORK_MIN_INTERVAL, FORK_MAX_INTERVAL)
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

return RoadService
