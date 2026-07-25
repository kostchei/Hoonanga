--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_EVENT_NAMES = {
	"FireWeapon",
	"ReloadWeapon",
	"SelectConvoyClass",
	"SelectWeapon",
	"VehicleInput",
	"WeaponFired",
	"SetPlayerReady",
	"SelectGarageLoadout",
	"SelectFork",
	"ClaimUpgrade",
	"RequestSpectateTarget",
	"SessionStateChanged",
	"ProgressionUpdated",
	"ActiveUpgradesUpdated",
	"LeaderboardUpdated",
}

local REMOTE_FUNCTION_NAMES = {
	"GetPlayerData",
	"PurchaseCosmetic",
}

local remotes: { [string]: RemoteEvent } = {}
local remoteFunctions: { [string]: RemoteFunction } = {}

local RemoteService = {}

function RemoteService.Start()
	local existing = ReplicatedStorage:FindFirstChild("HoonangaRemotes")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "HoonangaRemotes"
	folder.Parent = ReplicatedStorage

	for _, name in REMOTE_EVENT_NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	end

	for _, name in REMOTE_FUNCTION_NAMES do
		local fn = Instance.new("RemoteFunction")
		fn.Name = name
		fn.Parent = folder
		remoteFunctions[name] = fn
	end
end

function RemoteService.Get(name: string): RemoteEvent
	local remote = remotes[name]
	assert(remote, string.format("RemoteEvent %q has not been registered", name))
	return remote
end

function RemoteService.GetFunction(name: string): RemoteFunction
	local fn = remoteFunctions[name]
	assert(fn, string.format("RemoteFunction %q has not been registered", name))
	return fn
end

return RemoteService
