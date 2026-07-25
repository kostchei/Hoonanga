--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAMES = {
	"FireWeapon",
	"ReloadWeapon",
	"SelectWeapon",
	"VehicleInput",
	"WeaponFired",
}

local remotes: { [string]: RemoteEvent } = {}

local RemoteService = {}

function RemoteService.Start()
	local existing = ReplicatedStorage:FindFirstChild("HoonangaRemotes")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "HoonangaRemotes"
	folder.Parent = ReplicatedStorage

	for _, name in REMOTE_NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	end
end

function RemoteService.Get(name: string): RemoteEvent
	local remote = remotes[name]
	assert(remote, string.format("Remote %q has not been registered", name))
	return remote
end

return RemoteService
