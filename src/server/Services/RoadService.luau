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
	WornDirt = Color3.fromRGB(125, 92, 58),
	LooseStone = Color3.fromRGB(151, 119, 80),
	Mud = Color3.fromRGB(78, 61, 43),
	Oil = Color3.fromRGB(25, 24, 21),
}

local chunks: { ChunkRecord } = {}
local chunkFolder: Folder
local nextChunkIndex = 0
local running = false

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

local function configureChunk(chunk: Model, index: number)
	local road = WorldConfig.Road
	local centerZ = -(index * road.ChunkLength)
	local center = CFrame.new(0, ROAD_Y, centerZ)
	chunk.Name = string.format("Chunk_%04d", index)
	chunk:SetAttribute("ChunkIndex", index)
	chunk:SetAttribute("RoadFamily", "StonyDesert")

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
		"WornTrack",
		Vector3.new(48, 0.25, road.ChunkLength),
		center * CFrame.new(0, 0.08, 0),
		"WornDirt",
		ROAD_COLORS.WornDirt,
		Enum.Material.Ground
	)

	local variant = index % 4
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
	end

	local socketStart = Instance.new("Part")
	socketStart.Name = "StartSocket"
	socketStart.Anchored = true
	socketStart.CanCollide = false
	socketStart.CanQuery = false
	socketStart.Transparency = 1
	socketStart.Size = Vector3.one
	socketStart.CFrame = CFrame.new(0, 0, centerZ + road.ChunkLength / 2)
	socketStart.Parent = chunk

	local socketEnd = socketStart:Clone()
	socketEnd.Name = "EndSocket"
	socketEnd.CFrame = CFrame.new(0, 0, centerZ - road.ChunkLength / 2)
	socketEnd.Parent = chunk

	for _, side in { -1, 1 } do
		local baseX = side * (road.ChunkWidth / 2 - 8)
		addBoulder(
			chunk,
			Vector3.new(baseX, 1.6, centerZ - 120 + side * 32),
			0.7 + (index % 3) * 0.15
		)
		addBoulder(chunk, Vector3.new(baseX - side * 7, 1.2, centerZ + 145 - side * 18), 0.55)
	end
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

local function furthestVehicleProgress(): number
	local furthest = 0
	for _, vehicle in CollectionService:GetTagged("HoonangaVehicle") do
		if
			vehicle:IsA("Model")
			and vehicle.PrimaryPart
			and not vehicle:GetAttribute("Destroyed")
		then
			furthest = math.max(furthest, -vehicle.PrimaryPart.Position.Z)
		end
	end
	return furthest
end

local function recyclePassedChunks()
	local road = WorldConfig.Road
	local progress = furthestVehicleProgress()
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

	local killPlane = Instance.new("Part")
	killPlane.Name = "KillPlane"
	killPlane.Anchored = true
	killPlane.CanCollide = false
	killPlane.Transparency = 1
	killPlane.Size = Vector3.new(2000, 4, 100000)
	killPlane.Position = Vector3.new(0, -120, -49000)
	killPlane:SetAttribute("Lethal", true)
	killPlane.Parent = world

	chunks = {}
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
