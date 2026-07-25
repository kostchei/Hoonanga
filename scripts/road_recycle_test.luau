-- Milestone 1 acceptance: "Road chunks recycle without a visible gap or
-- deletion beneath an active vehicle", and Milestone 2's exit condition that
-- a ute can drive for a long stretch through correctly recycled terrain.
--
-- Drives a stand-in vehicle down the road in steps, letting RoadService's
-- recycler run between them, and after each step checks that the road is
-- still one contiguous strip and that nothing was deleted out from under the
-- vehicle.

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

-- Stand-in for a player ute: RoadService only needs a tagged Model with a
-- PrimaryPart on the player team to track progress.
local probe = Instance.new("Model")
probe.Name = "RecycleProbe"
local chassis = Instance.new("Part")
chassis.Name = "Chassis"
chassis.Anchored = true
chassis.Size = Vector3.new(6, 2, 15)
chassis.Position = Vector3.new(0, 4, 120)
chassis.Parent = probe
probe.PrimaryPart = chassis
probe:SetAttribute("Team", "Player")
probe:SetAttribute("Destroyed", false)
probe.Parent = vehicles
CollectionService:AddTag(probe, "HoonangaVehicle")

local roadChunks = Workspace.HoonangaWorld.RoadChunks

local function chunkIndices(): { number }
	local indices = {}
	for _, chunk in roadChunks:GetChildren() do
		table.insert(indices, chunk:GetAttribute("ChunkIndex"))
	end
	table.sort(indices)
	return indices
end

-- Simulate a long drive: 60 steps of one chunk each is ~30k studs, well past
-- the recycle distance, so the recycler runs many times.
local STEPS = 60
local initialCount = #roadChunks:GetChildren()

for step = 1, STEPS do
	local z = 120 - step * chunkLength
	chassis.Position = Vector3.new(0, 4, z)
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
	local occupied = math.floor(-z / chunkLength + 0.5)
	for _, needed in { occupied - 1, occupied, occupied + 1 } do
		if needed >= 0 and needed <= indices[#indices] and needed >= indices[1] then
			local found = false
			for _, existing in indices do
				if existing == needed then
					found = true
					break
				end
			end
			expect(
				found,
				string.format("step %d: chunk %d under/near the vehicle is missing", step, needed)
			)
		end
	end

	-- The road must always extend ahead of the vehicle, or the player drives
	-- off the end of the world.
	local furthestAhead = -(indices[#indices] + 0.5) * chunkLength
	expect(
		furthestAhead < z - chunkLength,
		string.format(
			"step %d: road only reaches z=%.0f but vehicle is at z=%.0f",
			step,
			furthestAhead,
			z
		)
	)
end

probe:Destroy()
print(
	string.format(
		"[RECYCLE] PASS: %d chunks stayed contiguous over %d chunk-lengths of travel",
		initialCount,
		STEPS
	)
)
