-- Checks that every ground-level chunk is actually solid all the way across,
-- so the player cannot drive into a hole.
--
-- Chunks are assembled from several overlapping slabs (terrain, road strip,
-- hazard patches, fork lanes), and it is easy to leave a gap between them
-- that is invisible in code review but is a pit at speed. This merges each
-- chunk's surface X-extents and reports any uncovered span.
--
-- RaisedHighway is exempt: its deck is meant to be a narrow elevated strip
-- with open air either side (GDD 9.1), and falling off it is the point.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local halfWidth = WorldConfig.Road.ChunkWidth / 2
-- Roughly the good-ground road strip, where the player actually drives.
local ROAD_SURFACE_HALF_WIDTH = 20
-- Slabs are axis-aligned and butt against each other, so allow a hairline
-- tolerance rather than demanding exact float equality.
local TOLERANCE = 0.05

local failures = {}

for _, chunk in Workspace.HoonangaWorld.RoadChunks:GetChildren() do
	local family = chunk:GetAttribute("RoadFamily")
	if family ~= "RaisedHighway" then
		local spans = {}
		for _, part in chunk:GetDescendants() do
			if part:IsA("BasePart") and part:GetAttribute("SurfaceProfile") then
				table.insert(spans, {
					Min = part.Position.X - part.Size.X / 2,
					Max = part.Position.X + part.Size.X / 2,
				})
			end
		end

		table.sort(spans, function(a, b)
			return a.Min < b.Min
		end)

		-- Walk left to right, tracking how far solid ground reaches. Every
		-- gap is reported, not just the first, so one run enumerates all of
		-- them instead of surfacing them one fix at a time.
		local covered = -halfWidth
		for _, span in spans do
			if span.Min > covered + TOLERANCE then
				table.insert(
					failures,
					string.format(
						"chunk %s (%s) has a %.1f stud hole from x=%.1f to x=%.1f",
						tostring(chunk:GetAttribute("ChunkIndex")),
						tostring(family),
						span.Min - covered,
						covered,
						span.Min
					)
				)
			end
			covered = math.max(covered, span.Max)
		end

		if covered < halfWidth - TOLERANCE then
			table.insert(
				failures,
				string.format(
					"chunk %s (%s) stops short at x=%.1f, expected %.1f",
					tostring(chunk:GetAttribute("ChunkIndex")),
					tostring(family),
					covered,
					halfWidth
				)
			)
		end
	end
end

-- Seam continuity. Chunks are tilted independently, so a grade or camber
-- change between neighbours steps the surface at their shared edge. A step
-- near the centre line is a wall the player drives into at speed; far out in
-- the runoff a small one is just a bump. This samples across the width and
-- holds the centre to a much tighter bound than the edges.
local MAX_STEP_AT_ROAD = 1.5
local MAX_STEP_AT_EDGE = 6

local ordered = {}
for _, chunk in Workspace.HoonangaWorld.RoadChunks:GetChildren() do
	table.insert(ordered, chunk)
end
table.sort(ordered, function(a, b)
	return (a:GetAttribute("ChunkIndex") or 0) < (b:GetAttribute("ChunkIndex") or 0)
end)

local function sampleHeight(chunk: Model, x: number, z: number): number?
	local best = nil
	for _, part in chunk:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("SurfaceProfile") then
			local localPoint = part.CFrame:PointToObjectSpace(Vector3.new(x, 0, z))
			if
				math.abs(localPoint.X) <= part.Size.X / 2
				and math.abs(localPoint.Z) <= part.Size.Z / 2
			then
				local surfaceY = (part.CFrame * CFrame.new(
					localPoint.X,
					part.Size.Y / 2,
					localPoint.Z
				)).Y
				best = if best == nil then surfaceY else math.max(best, surfaceY)
			end
		end
	end
	return best
end

local worstStep = 0
for i = 1, #ordered - 1 do
	local a, b = ordered[i], ordered[i + 1]
	if
		a:GetAttribute("RoadFamily") ~= "RaisedHighway"
		and b:GetAttribute("RoadFamily") ~= "RaisedHighway"
	then
		local seamZ = -((a:GetAttribute("ChunkIndex") + 0.5) * WorldConfig.Road.ChunkLength)
		for x = -halfWidth + 2, halfWidth - 2, 10 do
			local ya = sampleHeight(a, x, seamZ + 1)
			local yb = sampleHeight(b, x, seamZ - 1)
			if ya and yb then
				local step = math.abs(ya - yb)
				worstStep = math.max(worstStep, step)
				local allowed = if math.abs(x) <= ROAD_SURFACE_HALF_WIDTH
					then MAX_STEP_AT_ROAD
					else MAX_STEP_AT_EDGE
				if step > allowed then
					table.insert(
						failures,
						string.format(
							"seam between chunks %s/%s steps %.1f studs at x=%.0f (limit %.1f)",
							tostring(a:GetAttribute("ChunkIndex")),
							tostring(b:GetAttribute("ChunkIndex")),
							step,
							x,
							allowed
						)
					)
				end
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
		"[COVERAGE] PASS: chunks solid across full width, worst seam step %.2f studs",
		worstStep
	)
)
