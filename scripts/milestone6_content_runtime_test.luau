--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local PerformanceConfig = require(ReplicatedStorage.Shared.Config.PerformanceConfig)
local RoadContentConfig = require(ReplicatedStorage.Shared.Config.RoadContentConfig)
local services = ServerScriptService.Server.Services
local RoadService = require(services.RoadService)

local function expect(condition: boolean, message: string)
	if not condition then
		error("[M6_CONTENT] " .. message, 2)
	end
end

local seenForkSets: { [string]: boolean } = {}
local seenKinds: { [string]: boolean } = {}
local physicalHazardVariant = false
for seed = 6601, 6612 do
	RoadService.Reset()
	RoadService.Start(seed)
	local chunks = Workspace.HoonangaWorld.RoadChunks:GetChildren()
	expect(
		#chunks <= PerformanceConfig.Budgets.MaxActiveChunks,
		"active chunk count exceeded budget"
	)
	for _, chunk in chunks do
		local variantKind = chunk:GetAttribute("VariantKind")
		expect(typeof(variantKind) == "string", "chunk has no content variant kind")
		seenKinds[variantKind] = true
		if variantKind == "Hazard" then
			for _, descendant in chunk:GetDescendants() do
				if descendant:GetAttribute("HazardType") ~= nil then
					physicalHazardVariant = true
					break
				end
			end
		end
		local forkSet = chunk:GetAttribute("ForkSet")
		if typeof(forkSet) == "string" then
			seenForkSets[forkSet] = true
		end
	end
end

expect(seenKinds.Normal, "normal chunk variants were not generated")
expect(seenKinds.Hazard, "hazard chunk variants were not generated")
expect(seenKinds.Transition, "transition chunk variants were not generated")
expect(seenKinds.Fork, "fork variants were not generated")
expect(physicalHazardVariant, "hazard variants contained no physical hazard")
for _, forkSet in RoadContentConfig.ForkSets do
	expect(seenForkSets[forkSet], forkSet .. " fork set was not generated")
end

print("[M6_CONTENT] PASS: chunk library and four fork sets generate within budget")
