-- Milestone 1 acceptance: "Road chunks recycle without a visible gap or
-- deletion beneath an active vehicle", and Milestone 2's exit condition that
-- a ute can drive for a long stretch through correctly recycled terrain.
--
-- Drives a stand-in vehicle down the road in steps, letting RoadService's
-- recycler run between them, and after each step checks that the road is
-- still one contiguous strip and that nothing was deleted out from under the
-- vehicle.
--
-- The probe follows the road's own path rather than marching down world -Z,
-- because the road bends: a probe driven along an axis would leave the road
-- entirely within a few chunks and the recycler would be measuring the
-- progress of something standing in the scenery.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local RoadService = require(ServerScriptService.Server.Services.RoadService)

local function expect(condition, message)
	if not condition then
		error("[RECYCLE] " .. message, 2)
	end
end

RoadService.Start()
task.wait(1)

local chunkLength = WorldConfig.Road.ChunkLength
local vehicles = Workspace.HoonangaWorld:WaitForChild("Vehicles")
local roadChunks = Workspace.HoonangaWorld.RoadChunks

-- Stand-in for a player ute: RoadService only needs a tagged Model with a
-- PrimaryPart on the player team to track progress.
local function makeProbe(name: string, team: string): (Model, BasePart)
	local probe = Instance.new("Model")
	probe.Name = name
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Anchored = true
	chassis.Size = Vector3.new(6, 2, 15)
	chassis.Parent = probe
	probe.PrimaryPart = chassis
	probe:SetAttribute("Team", team)
	probe:SetAttribute("Destroyed", false)
	probe.Parent = vehicles
	CollectionService:AddTag(probe, "HoonangaVehicle")
	return probe, chassis
end

local probe, chassis = makeProbe("RecycleProbe", "Player")

local function chunkByIndex(index: number): Model?
	for _, chunk in roadChunks:GetChildren() do
		if chunk:GetAttribute("ChunkIndex") == index then
			return chunk
		end
	end
	return nil
end

local function chunkIndices(): { number }
	local indices = {}
	for _, chunk in roadChunks:GetChildren() do
		table.insert(indices, chunk:GetAttribute("ChunkIndex"))
	end
	table.sort(indices)
	return indices
end

-- Parks the probe a little way inside a chunk, on the road's centre line, so
-- which chunk it occupies is unambiguous rather than sitting exactly on a
-- shared seam.
local function parkInChunk(part: BasePart, chunk: Model)
	local entry = chunk:GetAttribute("EntryCFrame")
	expect(typeof(entry) == "CFrame", "chunk has no EntryCFrame to park against")
	part.CFrame = entry * CFrame.new(0, 4, -40)
end

parkInChunk(chassis, chunkByIndex(0) :: Model)

-- Simulate a long drive: 60 steps of one chunk each is ~30k studs, well past
-- the recycle distance, so the recycler runs many times.
local STEPS = 60
local initialCount = #roadChunks:GetChildren()

for step = 1, STEPS do
	local target = chunkByIndex(step)
	expect(
		target ~= nil,
		string.format(
			"step %d: chunk %d does not exist - the road did not extend ahead",
			step,
			step
		)
	)
	parkInChunk(chassis, target :: Model)
	-- The recycler ticks on its own loop; give it room to run.
	task.wait(0.6)

	local indices = chunkIndices()
	expect(#indices > 0, string.format("step %d: every chunk was destroyed", step))

	-- Contiguous: the road must be one unbroken strip, not islands.
	for i = 2, #indices do
		expect(
			indices[i] == indices[i - 1] + 1,
			string.format(
				"step %d: gap in the road - chunk %d follows %d",
				step,
				indices[i],
				indices[i - 1]
			)
		)
	end

	-- Stable buffer: the road should neither starve nor grow without bound.
	expect(
		#indices == initialCount,
		string.format(
			"step %d: chunk count drifted to %d (started at %d)",
			step,
			#indices,
			initialCount
		)
	)

	-- Nothing deleted beneath the vehicle: the chunk it is standing on, and
	-- one either side, must still exist.
	for _, needed in { step - 1, step, step + 1 } do
		if needed >= indices[1] and needed <= indices[#indices] then
			expect(
				chunkByIndex(needed) ~= nil,
				string.format("step %d: chunk %d under/near the vehicle is missing", step, needed)
			)
		end
	end

	-- The road must always extend ahead of the vehicle, or the player drives
	-- off the end of the world.
	local furthestChunk = chunkByIndex(indices[#indices]) :: Model
	local roadEnd = furthestChunk:GetAttribute("PathDistance") + chunkLength
	local progress = RoadService.GetProgress(chassis.Position)
	expect(
		roadEnd > progress + chunkLength,
		string.format(
			"step %d: road only reaches %.0f studs but vehicle is at %.0f",
			step,
			roadEnd,
			progress
		)
	)
end

-- Progress has to be measured along the road, not as a straight line from the
-- start: on a road that bends back on itself those two numbers diverge
-- completely, and it is the arc length that decides what gets recycled.
local drivenDistance = RoadService.GetProgress(chassis.Position)
expect(
	drivenDistance > STEPS * chunkLength * 0.9,
	string.format(
		"probe reports only %.0f studs of progress after %d chunks of driving",
		drivenDistance,
		STEPS
	)
)

-- Occupancy (GDD 8.4): the distance rule alone would happily delete a chunk
-- someone is still standing in. A second vehicle left far behind - a stalled
-- companion, or a player who doubled back - must keep its chunk alive.
local straggler, stragglerChassis = makeProbe("StragglerProbe", "Enemy")
stragglerChassis.CFrame = chassis.CFrame

local strandedChunk = RoadService.GetChunkAt(stragglerChassis.Position)
expect(strandedChunk ~= nil, "the straggler is not on the road at all")
local strandedIndex = (strandedChunk :: Model):GetAttribute("ChunkIndex")

-- Drive the player far enough ahead that the distance rule wants the
-- straggler's chunk gone.
for step = 1, 12 do
	local target = chunkByIndex(strandedIndex + step)
	if target then
		parkInChunk(chassis, target)
	end
	task.wait(0.6)
end

local survivor = chunkByIndex(strandedIndex)
expect(
	survivor ~= nil,
	string.format("chunk %d was destroyed while a vehicle was still standing in it", strandedIndex)
)
local occupancyReported = (survivor :: Model):GetAttribute("Occupancy") or 0
expect(
	occupancyReported >= 1,
	string.format(
		"chunk %d reported occupancy %d, expected at least 1",
		strandedIndex,
		occupancyReported
	)
)

straggler:Destroy()
probe:Destroy()
print(
	string.format(
		"[RECYCLE] PASS: %d chunks stayed contiguous over %.0f studs of curved road, and an occupied chunk survived the recycler",
		initialCount,
		drivenDistance
	)
)
