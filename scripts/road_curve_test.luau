-- Curvature statistics. The coverage test already proves a curved chunk is
-- solid and that headings chain without a kink; this one proves the director
-- is actually producing the mix of bends it is supposed to.
--
-- Both properties under test are statistical, so a single 21-chunk road says
-- nothing useful. The road is regenerated from many seeds and the chunks are
-- pooled, which gives a large enough sample that the acceptance bands below
-- are several standard deviations wide - a real regression trips them, a
-- lucky run does not.

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local RoadService = require(ServerScriptService.Server.Services.RoadService)

local function expect(condition, message)
	if not condition then
		error("[CURVE] " .. message, 2)
	end
end

-- Families whose geometry cannot bend, and so are excluded from the rate:
-- the highway's deck, ramps and rails are built from absolute heights, and
-- the fork is two parallel lanes with a boulder line down the middle.
local STRAIGHT_ONLY_FAMILIES = {
	RaisedHighway = true,
	Fork = true,
}

local SEEDS = 40

local curveCapable = 0
local curved = 0
local kindCounts = { Slight = 0, Medium = 0, Hard = 0 }
local alternatingPairs = 0
local totalPairs = 0

local function classify(degrees: number): string
	local magnitude = math.abs(degrees)
	if magnitude >= 70 then
		return "Hard"
	elseif magnitude >= 20 then
		return "Medium"
	end
	return "Slight"
end

for seed = 1, SEEDS do
	local world = Workspace:FindFirstChild("HoonangaWorld")
	if world then
		world:Destroy()
	end
	RoadService.Reset()
	RoadService.Start(seed * 7919)
	task.wait(0.05)

	local ordered = {}
	for _, chunk in Workspace.HoonangaWorld.RoadChunks:GetChildren() do
		table.insert(ordered, chunk)
	end
	table.sort(ordered, function(a, b)
		return a:GetAttribute("ChunkIndex") < b:GetAttribute("ChunkIndex")
	end)

	local previousSign = nil
	for _, chunk in ordered do
		local family = chunk:GetAttribute("RoadFamily")
		local degrees = chunk:GetAttribute("CurveDegrees")
		expect(typeof(degrees) == "number", "chunk has no CurveDegrees")

		if STRAIGHT_ONLY_FAMILIES[family] then
			expect(
				degrees == 0,
				string.format(
					"%s chunk curved by %.1f degrees, which its geometry cannot do",
					family,
					degrees
				)
			)
			continue
		end

		curveCapable += 1
		if degrees == 0 then
			continue
		end

		curved += 1
		kindCounts[classify(degrees)] += 1

		local sign = if degrees > 0 then 1 else -1
		if previousSign then
			totalPairs += 1
			if sign ~= previousSign then
				alternatingPairs += 1
			end
		end
		previousSign = sign
	end
end

RoadService.Reset()

expect(curveCapable > 400, string.format("sample too small to judge: %d chunks", curveCapable))
expect(
	totalPairs > 60,
	string.format("too few consecutive curves to judge alternation: %d", totalPairs)
)

-- Target is 25% of curve-capable chunks. The band is wide enough that
-- ordinary sampling noise cannot trip it but a changed constant will.
local curveRate = curved / curveCapable
expect(
	curveRate >= 0.18 and curveRate <= 0.33,
	string.format("%.1f%% of curve-capable chunks curved, expected around 25%%", curveRate * 100)
)

-- Every severity has to actually appear, or the road only has one kind of
-- bend and the three-way split is decorative.
for kind, count in kindCounts do
	expect(count > 0, string.format("no %s curves were generated at all", kind))
end
expect(
	kindCounts.Slight > kindCounts.Hard,
	string.format(
		"slight bends (%d) should be the common case, not ninety-degree turns (%d)",
		kindCounts.Slight,
		kindCounts.Hard
	)
)

-- Target is 75% opposite. Without this the same sign keeps coming up and the
-- road coils instead of weaving.
local alternationRate = alternatingPairs / totalPairs
expect(
	alternationRate >= 0.64 and alternationRate <= 0.86,
	string.format(
		"%.1f%% of consecutive curves changed direction, expected around 75%%",
		alternationRate * 100
	)
)

print(
	string.format(
		"[CURVE] PASS: %.1f%% of %d chunks curved (%d slight, %d medium, %d hard), %.1f%% alternated direction",
		curveRate * 100,
		curveCapable,
		kindCounts.Slight,
		kindCounts.Medium,
		kindCounts.Hard,
		alternationRate * 100
	)
)
