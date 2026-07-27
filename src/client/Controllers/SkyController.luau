--!strict

-- The world beyond the generated road is empty space, so without this the
-- road ends in a hard edge with skybox underneath it - there is no horizon,
-- just a strip of terrain floating in blue. This lays a ground plane and a
-- distant ridge line that follow the camera, so the desert always runs out
-- to a skyline however far the run gets, and draws the dark corona around
-- the low sun.
--
-- All of it is client-side and none of it exists on the server. That is not
-- just a performance choice: a horizon plane the size of a small suburb sits
-- directly under every vehicle, and if the server knew about it, it would be
-- the first thing every weapon raycast and suspension probe hit. Every part
-- created here has CanQuery, CanCollide and CanTouch off for the same reason,
-- because the *client* still runs suspension raycasts for the vehicle it owns.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PerformanceConfig = require(ReplicatedStorage.Shared.Config.PerformanceConfig)

-- 3x3 tiles of 2000 studs reaches 3000 studs in every direction, which is
-- past the point where the atmosphere has hazed the ground into the sky.
local HORIZON_TILE_SIZE = 2000
local HORIZON_TILES = 3
-- How far below the ground under the camera the plane sits. Enough to clear
-- the road slabs without opening a visible cliff at the terrain edge.
local HORIZON_DROP = 6
local HORIZON_COLOR = Color3.fromRGB(163, 96, 58)

-- A ring of distant mesas. They stay at a fixed distance rather than being
-- approached, which is how distant scenery works in every driving game: at
-- 2600 studs and heavily hazed, the eye reads them as far-off country and
-- never as props.
local RIDGE_COUNT = 26
local RIDGE_DISTANCE = 2600
local RIDGE_MIN_HEIGHT = 90
local RIDGE_MAX_HEIGHT = 260
local RIDGE_COLOR = Color3.fromRGB(120, 66, 48)

-- Concentric rings of decreasing opacity around the sun disc. Roblox has no
-- property for this and a custom sun texture would need an uploaded asset,
-- so the corona is drawn in screen space over the sun's projected position.
local HALO_RINGS = 9
local HALO_INNER_RADIUS = 44
local HALO_OUTER_RADIUS = 190
local HALO_COLOR = Color3.fromRGB(26, 15, 11)
local HALO_INNER_TRANSPARENCY = 0.42
local HALO_SUN_DISTANCE = 4000

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = true

local horizonFolder: Folder
local horizonTiles: { BasePart } = {}
local ridgeParts: { BasePart } = {}
local haloContainer: Frame
-- The plane's height is smoothed toward the ground under the camera rather
-- than snapped to it, so cresting a rise does not make the whole horizon
-- jump.
local horizonY = 0
local horizonInitialised = false

local function makeScenery(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Sand
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = horizonFolder
	return part
end

local function buildHorizon()
	local previous = Workspace:FindFirstChild("HoonangaHorizon")
	if previous then
		previous:Destroy()
	end
	table.clear(horizonTiles)
	table.clear(ridgeParts)

	horizonFolder = Instance.new("Folder")
	horizonFolder.Name = "HoonangaHorizon"
	horizonFolder.Parent = Workspace

	for tile = 1, HORIZON_TILES * HORIZON_TILES do
		table.insert(
			horizonTiles,
			makeScenery(
				string.format("HorizonTile_%02d", tile),
				Vector3.new(HORIZON_TILE_SIZE, 8, HORIZON_TILE_SIZE),
				HORIZON_COLOR
			)
		)
	end

	for index = 1, RIDGE_COUNT do
		-- Deterministic rather than random so the skyline is the same shape
		-- every session and reads as a place rather than as noise.
		local rise = math.noise(index * 0.37, 4.2)
		local height = RIDGE_MIN_HEIGHT
			+ (RIDGE_MAX_HEIGHT - RIDGE_MIN_HEIGHT) * math.clamp(rise + 0.5, 0, 1)
		local width = 420 + math.abs(math.noise(index * 0.71, 8.5)) * 520
		local mesa = makeScenery(
			string.format("HorizonMesa_%02d", index),
			Vector3.new(width, height, 260),
			RIDGE_COLOR
		)
		mesa.Material = Enum.Material.Rock
		table.insert(ridgeParts, mesa)
	end
end

local function buildHalo(parent: ScreenGui)
	haloContainer = Instance.new("Frame")
	haloContainer.Name = "SunHalo"
	haloContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	haloContainer.Size = UDim2.fromOffset(1, 1)
	haloContainer.BackgroundTransparency = 1
	haloContainer.Visible = false
	haloContainer.ZIndex = 0
	haloContainer.Parent = parent

	for index = 1, HALO_RINGS do
		local alpha = (index - 1) / (HALO_RINGS - 1)
		local radius = HALO_INNER_RADIUS + (HALO_OUTER_RADIUS - HALO_INNER_RADIUS) * alpha

		local ring = Instance.new("Frame")
		ring.Name = string.format("HaloRing_%02d", index)
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromOffset(radius * 2, radius * 2)
		ring.BackgroundTransparency = 1
		ring.ZIndex = 0
		ring.Parent = haloContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = ring

		-- Stroke rather than fill: a filled disc would black out the sun
		-- instead of ringing it. Thickness grows outward so the rings stay
		-- touching as their radius increases, which is what makes nine hard
		-- outlines read as one soft corona.
		local stroke = Instance.new("UIStroke")
		stroke.Color = HALO_COLOR
		stroke.Thickness = 10 + alpha * 14
		stroke.Transparency = HALO_INNER_TRANSPARENCY + (1 - HALO_INNER_TRANSPARENCY) * alpha ^ 0.75
		stroke.Parent = ring
	end
end

-- The probe is vertically aligned with the camera. Even though its ray starts
-- above the cab, the first thing below it is still the ute's own bodywork
-- rather than the road. Vehicles are excluded whole and other non-ground
-- geometry is punched through until real desert ground turns up; without this
-- the horizon plane tracks the vehicle roof and rises up around the player.
local MAX_PIERCED_PARTS = 12
local piercedParts: { Instance } = {}

local function groundHeightUnder(position: Vector3): number?
	table.clear(piercedParts)
	table.insert(piercedParts, horizonFolder)
	-- Exclude whole vehicles rather than piercing one body part at a time.
	-- A ute contains more queryable parts than the pierce limit, and a vertical
	-- probe can otherwise stop on its chassis, ballast, seat or turret before
	-- it ever reaches the road.
	for _, vehicle in CollectionService:GetTagged("HoonangaVehicle") do
		table.insert(piercedParts, vehicle)
	end

	for _ = 1, MAX_PIERCED_PARTS do
		groundParams.FilterDescendantsInstances = piercedParts
		local result = Workspace:Raycast(position, Vector3.new(0, -600, 0), groundParams)
		if not result then
			return nil
		end
		if
			result.Instance:GetAttribute("SurfaceProfile")
			and result.Instance:GetAttribute("HorizonGround") ~= false
		then
			return result.Position.Y
		end
		table.insert(piercedParts, result.Instance)
	end

	return nil
end

local function updateHorizon(camera: Camera, deltaTime: number)
	local origin = camera.CFrame.Position
	local ground = groundHeightUnder(origin + Vector3.new(0, 200, 0))
	local targetY = (ground or horizonY) - HORIZON_DROP
	if not horizonInitialised then
		horizonY = targetY
		horizonInitialised = true
	else
		-- Frame-rate independent smoothing toward the local ground height.
		horizonY += (targetY - horizonY) * math.min(1, deltaTime * 2.5)
	end

	local half = (HORIZON_TILES - 1) / 2
	local tile = 0
	for row = -half, half do
		for column = -half, half do
			tile += 1
			horizonTiles[tile].Position = Vector3.new(
				origin.X + column * HORIZON_TILE_SIZE,
				horizonY,
				origin.Z + row * HORIZON_TILE_SIZE
			)
		end
	end

	for index, mesa in ridgeParts do
		local angle = (index - 1) / RIDGE_COUNT * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * RIDGE_DISTANCE
		mesa.CFrame = CFrame.new(
			origin.X + offset.X,
			horizonY + mesa.Size.Y / 2 - 10,
			origin.Z + offset.Z
		) * CFrame.Angles(0, -angle, 0)
	end
end

local function updateHalo(camera: Camera)
	local sunDirection = Lighting:GetSunDirection()
	-- Below the skyline there is no disc to ring.
	if sunDirection.Y <= 0 then
		haloContainer.Visible = false
		return
	end

	local sunPoint = camera.CFrame.Position + sunDirection * HALO_SUN_DISTANCE
	local screenPoint, onScreen = camera:WorldToViewportPoint(sunPoint)
	if not onScreen then
		haloContainer.Visible = false
		return
	end

	haloContainer.Visible = true
	haloContainer.Position = UDim2.fromOffset(screenPoint.X, screenPoint.Y)
end

local SkyController = {}

function SkyController.Start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "HoonangaSky"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	-- Behind the HUD: the corona is part of the world, not part of the
	-- instrument panel, and must never draw over the crosshair.
	gui.DisplayOrder = -1
	gui.Parent = player:WaitForChild("PlayerGui")

	buildHorizon()
	buildHalo(gui)

	local lowModeElapsed = 0
	RunService.RenderStepped:Connect(function(deltaTime)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		if player:GetAttribute("LowPerformanceMode") == true then
			lowModeElapsed += deltaTime
			if lowModeElapsed < 1 / PerformanceConfig.LowModeVisualHz then
				return
			end
			deltaTime = lowModeElapsed
			lowModeElapsed = 0
		end
		updateHorizon(camera, deltaTime)
		updateHalo(camera)
	end)
end

-- Builds the world half without touching PlayerGui, so the invariant that
-- matters most here - that none of this scenery is visible to a raycast -
-- can be checked without a client session.
function SkyController.BuildSceneryForTest(): Folder
	buildHorizon()
	return horizonFolder
end

function SkyController.GroundHeightForTest(position: Vector3): number?
	return groundHeightUnder(position)
end

return SkyController
