-- Checks that every ground-level chunk is actually solid all the way across,
-- so the player cannot drive into a hole.
--
-- Chunks are assembled from several overlapping slabs (terrain, road strip,
-- hazard patches, fork lanes) and, on a curved chunk, from a fan of slabs
-- approximating an arc. It is easy to leave a gap between them that is
-- invisible in code review but is a pit at speed.
--
-- The test samples a grid across each chunk's own frame and casts a ray
-- straight down at every sample, which is the same question the vehicle's
-- suspension asks. Sampling in the chunk's frame rather than in world X/Z is
-- what makes this work now that chunks curve: a chunk's "left edge" is no
-- longer a world axis.
--
-- RaisedHighway is exempt: its deck is meant to be a narrow elevated strip
-- with open air either side (GDD 9.1), and falling off it is the point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local RoadService = require(ServerScriptService.Server.Services.RoadService)

local function expect(condition, message)
	if not condition then
		error("[COVERAGE] " .. message, 2)
	end
end

RoadService.Start()
task.wait(1)

local chunkLength = WorldConfig.Road.ChunkLength
local halfWidth = WorldConfig.Road.ChunkWidth / 2
-- Roughly the good-ground road strip, where the player actually drives.
local ROAD_SURFACE_HALF_WIDTH = 20
local LATERAL_STEP = 10
local ALONG_STEP = 32
-- Well above the highest the road is allowed to climb, and long enough to
-- reach through the lowest it may descend to.
local PROBE_HEIGHT = 400
local PROBE_LENGTH = 900

-- Mirrors RoadService's own arc parametrisation. Duplicated deliberately:
-- if the two ever disagree the test should fail, which it cannot do if it
-- imports the very function it is checking.
local function arcFrame(t: number, curvature: number): CFrame
	if curvature == 0 then
		return CFrame.new(0, 0, -t)
	end
	local phi = curvature * t
	return CFrame.new((math.cos(phi) - 1) / curvature, 0, -math.sin(phi) / curvature)
		* CFrame.Angles(0, phi, 0)
end

local surfaceParams = RaycastParams.new()
surfaceParams.FilterType = Enum.RaycastFilterType.Exclude
surfaceParams.FilterDescendantsInstances = {}
surfaceParams.IgnoreWater = true

-- Returns the height of solid road surface under a point, or nil if the ray
-- found nothing but air.
--
-- Canyon walls, boulders and guard rails sit above the road and would stop
-- the ray before it reached the ground, so anything without a surface
-- profile is punched through rather than treated as a floor. Stopping at the
-- first hit reported every canyon as a hole.
local MAX_PIERCED_PARTS = 12

local function groundHeightAt(point: Vector3): number?
	local origin = point + Vector3.new(0, PROBE_HEIGHT, 0)
	local remaining = PROBE_LENGTH
	local pierced = {}

	for _ = 1, MAX_PIERCED_PARTS do
		surfaceParams.FilterDescendantsInstances = pierced
		local result = Workspace:Raycast(origin, Vector3.new(0, -remaining, 0), surfaceParams)
		if not result then
			return nil
		end
		if result.Instance:GetAttribute("SurfaceProfile") then
			return result.Position.Y
		end
		table.insert(pierced, result.Instance)
	end

	return nil
end

local ordered = {}
for _, chunk in Workspace.HoonangaWorld.RoadChunks:GetChildren() do
	table.insert(ordered, chunk)
end
table.sort(ordered, function(a, b)
	return a:GetAttribute("ChunkIndex") < b:GetAttribute("ChunkIndex")
end)
expect(#ordered > 0, "no chunks were generated")

local failures = {}

-- Metadata first: curvature is only meaningful if the headings actually
-- follow it, and a chunk whose exit heading does not match the next chunk's
-- entry heading is a kink in the road (GDD 8.3 socket rules).
local curvedCount = 0
for position, chunk in ordered do
	local curve = chunk:GetAttribute("CurveDegrees")
	local entry = chunk:GetAttribute("EntryHeading")
	local exit = chunk:GetAttribute("ExitHeading")
	expect(typeof(curve) == "number", "chunk has no CurveDegrees")
	expect(typeof(entry) == "number" and typeof(exit) == "number", "chunk has no heading metadata")

	if math.abs(curve) > 0.001 then
		curvedCount += 1
	end
	if math.abs((entry + curve) - exit) > 0.001 then
		table.insert(
			failures,
			string.format(
				"chunk %s exit heading %.2f does not match entry %.2f plus curve %.2f",
				tostring(chunk:GetAttribute("ChunkIndex")),
				exit,
				entry,
				curve
			)
		)
	end

	local following = ordered[position + 1]
	if following and math.abs(following:GetAttribute("EntryHeading") - exit) > 0.001 then
		table.insert(
			failures,
			string.format(
				"kink between chunks %s and %s: exit %.2f, next entry %.2f",
				tostring(chunk:GetAttribute("ChunkIndex")),
				tostring(following:GetAttribute("ChunkIndex")),
				exit,
				following:GetAttribute("EntryHeading")
			)
		)
	end
end

-- Solidity. Every sample inside a ground-level chunk must find road under it.
for _, chunk in ordered do
	local family = chunk:GetAttribute("RoadFamily")
	if family == "RaisedHighway" then
		continue
	end

	local entryCFrame = chunk:GetAttribute("EntryCFrame")
	expect(typeof(entryCFrame) == "CFrame", "chunk has no EntryCFrame")
	local curvature = math.rad(chunk:GetAttribute("CurveDegrees")) / chunkLength

	local holes = 0
	for along = 4, chunkLength - 4, ALONG_STEP do
		local frame = entryCFrame * arcFrame(along, curvature)
		for lateral = -halfWidth + 2, halfWidth - 2, LATERAL_STEP do
			local point = (frame * CFrame.new(lateral, 0, 0)).Position
			if groundHeightAt(point) == nil then
				holes += 1
			end
		end
	end

	if holes > 0 then
		table.insert(
			failures,
			string.format(
				"chunk %s (%s, %.1f degree curve) has %d sample point(s) with no ground under them",
				tostring(chunk:GetAttribute("ChunkIndex")),
				tostring(family),
				chunk:GetAttribute("CurveDegrees"),
				holes
			)
		)
	end
end

-- Seam continuity. Chunks are tilted independently, so a grade or camber
-- change between neighbours steps the surface at their shared edge. A step
-- near the centre line is a wall the player drives into at speed; far out in
-- the runoff a small one is just a bump. This samples across the width and
-- holds the centre to a much tighter bound than the edges.
local MAX_STEP_AT_ROAD = 1.5
local MAX_STEP_AT_EDGE = 6

local worstStep = 0
for position = 1, #ordered - 1 do
	local a, b = ordered[position], ordered[position + 1]
	if
		a:GetAttribute("RoadFamily") == "RaisedHighway"
		or b:GetAttribute("RoadFamily") == "RaisedHighway"
	then
		continue
	end

	local seam = b:GetAttribute("EntryCFrame")
	for lateral = -halfWidth + 2, halfWidth - 2, LATERAL_STEP do
		local before = groundHeightAt((seam * CFrame.new(lateral, 0, 3)).Position)
		local after = groundHeightAt((seam * CFrame.new(lateral, 0, -3)).Position)
		if before and after then
			local step = math.abs(before - after)
			worstStep = math.max(worstStep, step)
			local allowed = if math.abs(lateral) <= ROAD_SURFACE_HALF_WIDTH
				then MAX_STEP_AT_ROAD
				else MAX_STEP_AT_EDGE
			if step > allowed then
				table.insert(
					failures,
					string.format(
						"seam between chunks %s/%s steps %.1f studs at lateral %.0f (limit %.1f)",
						tostring(a:GetAttribute("ChunkIndex")),
						tostring(b:GetAttribute("ChunkIndex")),
						step,
						lateral,
						allowed
					)
				)
			end
		end
	end
end

for _, failure in failures do
	warn("[COVERAGE] " .. failure)
end

expect(#failures == 0, string.format("%d problem(s) found - see warnings above", #failures))
print(
	string.format(
		"[COVERAGE] PASS: %d chunks solid across full width (%d curved), worst seam step %.2f studs",
		#ordered,
		curvedCount,
		worstStep
	)
)
