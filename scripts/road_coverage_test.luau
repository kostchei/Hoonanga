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

for _, failure in failures do
	warn("[COVERAGE] " .. failure)
end

expect(#failures == 0, string.format("%d chunk(s) have holes - see warnings above", #failures))
print("[COVERAGE] PASS: every ground-level chunk is solid across its full width")
