-- GDD 8.5: the road director runs off a seed so a run can be reproduced
-- exactly. This is what makes a terrain bug reportable ("seed 12345, chunk
-- 14") rather than a story about something you saw once.
--
-- Generates the road twice from the same seed and once from a different one,
-- comparing the decisions that actually shape a run: family sequence, road
-- elevation, curvature, and fork placement.

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local RoadService = require(ServerScriptService.Server.Services.RoadService)

local function expect(condition, message)
	if not condition then
		error("[SEED] " .. message, 2)
	end
end

-- Start() guards against re-entry, so reach past it to regenerate.
local function generate(seed: number): string
	local world = Workspace:FindFirstChild("HoonangaWorld")
	if world then
		world:Destroy()
	end
	RoadService.Reset()
	RoadService.Start(seed)
	task.wait(0.6)

	local ordered = {}
	for _, chunk in Workspace.HoonangaWorld.RoadChunks:GetChildren() do
		table.insert(ordered, chunk)
	end
	table.sort(ordered, function(a, b)
		return a:GetAttribute("ChunkIndex") < b:GetAttribute("ChunkIndex")
	end)

	local parts = {}
	for _, chunk in ordered do
		table.insert(
			parts,
			string.format(
				"%s@%.2f/%.2f",
				tostring(chunk:GetAttribute("RoadFamily")),
				chunk:GetAttribute("GroundExitY") or 0,
				chunk:GetAttribute("CurveDegrees") or 0
			)
		)
	end
	return table.concat(parts, "|")
end

local first = generate(20260725)
local repeated = generate(20260725)
local different = generate(99999)

expect(
	first == repeated,
	string.format("same seed produced different roads:\n  %s\n  %s", first, repeated)
)
expect(first ~= different, "two different seeds produced an identical road")
expect(RoadService.GetSeed() == 99999, "GetSeed did not report the seed the road was built from")

print("[SEED] PASS: the same seed reproduces the road, a different seed does not")
