--!strict

return {
	Road = {
		ChunkLength = 512,
		-- Wide enough to turn around in. The drivable track down the middle
		-- is much narrower; the rest is rough runoff that costs grip but
		-- gives room to swing a U-turn and re-engage rather than being
		-- committed to one direction forever.
		ChunkWidth = 230,
		InitialChunkCount = 21,
		ChunksBehind = 8,
		ChunksAhead = 12,
		RecycleDistance = 4096,
	},
	Testing = {
		EnemyEnabled = true,
	},
	Spawn = {
		Player = CFrame.new(-10, 4, 120),
		Enemy = CFrame.new(12, 4, -80),
	},
}
